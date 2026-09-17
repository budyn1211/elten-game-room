require "securerandom"
require "json"
require_relative "game_room_transport"
require_relative "game_participants"
require_relative "game_room_server_tables"
require_relative "bot_turn_gate"

class GameRepository
  GameSnapshot = Struct.new(:session, :events, keyword_init: true)

  SESSION_LIMIT = 500
  EVENT_LIMIT = 2_000
  EVENT_CACHE_LIMIT = 8
  EVENT_CACHE_FRESHNESS = 0.25
  MAX_EVENTS_PER_ACTION = 50
  MAX_ACTION_LENGTH = 32
  MAX_VALUE_LENGTH = 64
  MAX_PLAYERS = 8
  MAX_PLAYER_LENGTH = 64
  PLAYERS_FORMAT_VERSION = 1
  MAX_PLAYERS_JSON_LENGTH = 1_024

  def initialize(program, transport: nil, server_tables: nil)
    @program = program
    @server_tables = server_tables || GameRoomServerTables.new(program)
    @transport = transport || GameRoomTransport.new(program)
    @event_cache = {}
    @event_cache_mutex = Mutex.new
    @bot_turn_controllers = {}
  end

  def bot_turn_controller(table_id)
    @event_cache_mutex.synchronize do
      @bot_turn_controllers[table_id.to_i] ||= GameRoomBots::TurnController.new
    end
  end

  def restore_session(table:, game:, players:, options:, restore:)
    raise ArgumentError, "Only the founder may restore the game" unless GameRoomParticipants.same?(table["owner"], Session.name)
    @start_session_mutex ||= Mutex.new
    @start_session_mutex.synchronize do
      existing = session_for_table(table, force: true)
      next existing if existing != nil
      @transport.start_game(table: table, game: game, players: players, options: options, actor: Session.name, restore: restore)
    end
  end

  def session_for_table(table, force: false)
    table_id = row_id(table)
    return nil if table_id <= 0

    if native_live_sessions?
      return @transport.game_sessions(table, force: force)
        .sort_by { |row| -row["__stack_sequence"].to_i }
        .find { |row| valid_session_for_table?(row, table, players: players_for(row)) }
    end

    session_rows(table_id: table_id)
      .sort_by { |row| -session_id(row) }
      .each do |row|
        players = persisted_players_for(row)
        return with_players(row, players) if valid_session_for_table?(row, table, players: players)
      end
    nil
  end

  def latest_session_id_for_table(table)
    table_id = row_id(table)
    return 0 if table_id <= 0

    if native_live_sessions?
      latest = @transport.game_sessions(table).max_by { |row| row["__stack_sequence"].to_i }
      return session_id(latest)
    end

    session_rows(table_id: table_id).map { |row| session_id(row) }.max.to_i
  end

  def session_by_id(id, table: nil)
    target_id = id.to_i
    return nil if target_id <= 0

    if native_live_sessions?
      row = @transport.game_session(target_id, table: table)
      return nil if row == nil
      return row if table == nil

      return valid_session_for_table?(row, table, players: players_for(row)) ? row : nil
    end

    table_id = table == nil ? nil : row_id(table)
    row = session_rows(table_id: table_id).find { |candidate| session_id(candidate) == target_id }
    return nil if row == nil

    players = persisted_players_for(row)
    return with_players(row, players) if table == nil

    valid_session_for_table?(row, table, players: players) ? with_players(row, players) : nil
  end

  def start_session(table:, game:, players:, options: "{}", recipients: players, expected_previous_session_id: nil)
    @start_session_mutex ||= Mutex.new
    @start_session_mutex.synchronize do
      start_session_once(
        table: table,
        game: game,
        players: players,
        options: options,
        recipients: recipients,
        expected_previous_session_id: expected_previous_session_id
      )
    end
  end

  def snapshot_for(session, force_events: false)
    return nil if session_id(session) <= 0 || session["table_id"].to_i <= 0

    players = players_for(session)
    return nil if players.empty?

    current = with_players(session, players)
    if native_live_sessions?
      refreshed = @transport.game_session(session_id(current), table: current["table_id"])
      current = with_players(refreshed, players) if refreshed != nil
    end
    events = events_for(current, force: force_events)
    # A terminal boundary can have arrived in the event read just completed.
    if native_live_sessions?
      refreshed = @transport.game_session(session_id(current), table: current["table_id"])
      current = with_players(refreshed, players) if refreshed != nil
    end
    GameSnapshot.new(session: current, events: events)
  end

  def event_revision(session, known_revision: nil, force: false)
    return events_revision(events_for(session, force: force)) if native_live_sessions?

    return events_revision(events_for(session)) if known_revision == nil

    known_count = [known_revision.to_a[0].to_i, 0].max
    row = events_table.select(
      where: event_scope(session),
      order: event_order,
      limit: 1,
      offset: known_count
    ).to_a.first
    row == nil ? known_revision : [known_count + 1, event_id(row)]
  end

  def events_revision(events)
    ids = events.to_a.map { |event| event_id(event) }
    [ids.length, ids.max.to_i]
  end

  # Locally appended events are present in the optimistic cache immediately,
  # but only this prefix has been observed again in an ordered server read.
  def confirmed_event_ids(session)
    # Native entries arrive only through a persisted push acknowledgement,
    # notification or read. An uncertain write is verified by a forced snapshot
    # before observing the gate; do not repeat that read for its identifiers.
    return events_for(session).map { |event| event_id(event) }.select(&:positive?) if native_live_sessions?

    entry = event_cache_entry(session_id(session))
    return [] if entry == nil

    entry[:events]
      .first(entry[:confirmed_count].to_i)
      .map { |event| event_id(event) }
      .select { |id| id > 0 }
  end

  def next_sequence(session, accepted_events)
    accepted_events.to_a.map { |event| event["sequence"].to_i + 1 }.max.to_i
  end

  def consume_recovered_events(session)
    native_live_sessions? ? @transport.consume_recovered_game_events(session) : []
  end

  def append_events(session:, sequence:, events:, recipients: nil, actor: Session.name, controller: false)
    raise ArgumentError, "The game no longer exists" if session_id(session) <= 0 || session["table_id"].to_i <= 0

    players = players_for(session)
    raise ArgumentError, "The game participant list is incomplete" if players.empty?
    event_actor = actor.to_s
    raise ArgumentError, "A game event requires an actor" if event_actor.empty?
    if GameRoomParticipants.bot?(event_actor)
      owner = insertion_user(session, "player_one")
      raise ArgumentError, "Only the table owner may move a computer" if owner.casecmp(Session.name.to_s) != 0
      raise ArgumentError, "The computer is not a player in this game" if !includes_user?(players, event_actor)
    elsif controller
      owner = insertion_user(session, "player_one")
      raise ArgumentError, "Only the table owner may submit an automatic player action" if owner.casecmp(Session.name.to_s) != 0
      raise ArgumentError, "The automatic action actor is not a player in this game" if !includes_user?(players, event_actor)
    else
      raise ArgumentError, "A user may only submit their own move" if event_actor.casecmp(Session.name.to_s) != 0
      raise ArgumentError, "You are not a player in this game" if !includes_user?(players, Session.name)
    end
    current = with_players(session, players)
    commands = events.to_a
    if commands.empty? || commands.length > MAX_EVENTS_PER_ACTION
      raise ArgumentError, "The game action contains an invalid number of events"
    end

    if native_live_sessions?
      commands.each do |command|
        action = command_value(command, "action").to_s
        value = command_value(command, "value").to_s
        raise ArgumentError, "A game event requires an action" if action.empty?
        raise ArgumentError, "The game event action is too long" if action.length > MAX_ACTION_LENGTH
        raise ArgumentError, "The game event value is too long" if value.length > MAX_VALUE_LENGTH
      end
      return @transport.append_game_action(
        session: current,
        sequence: sequence,
        events: commands,
        actor: event_actor,
        controller: controller == true
      )
    end

    timestamp = Time.now.to_i
    inserted = commands.each_with_index.map do |command, offset|
      action = command_value(command, "action").to_s
      value = command_value(command, "value").to_s
      raise ArgumentError, "A game event requires an action" if action.empty?
      raise ArgumentError, "The game event action is too long" if action.length > MAX_ACTION_LENGTH
      raise ArgumentError, "The game event value is too long" if value.length > MAX_VALUE_LENGTH

      events_table.insert(
        "session_id" => session_id(current),
        "table_id" => current["table_id"].to_i,
        "sequence" => sequence.to_i + offset,
        "move_id" => SecureRandom.uuid,
        "actor" => event_actor,
        "action" => action,
        "value" => value,
        "created_at" => timestamp
      )
    end
    append_to_event_cache(current, inserted)
    notify_game_changed(current, GameRoomParticipants.humans(recipients || players), change: "action")
    inserted
  rescue Exception
    # A response can fail after a row was saved (also between play and draw).
    # Never retry from the pre-write cache or assume the entire action failed.
    event_cache_mutex.synchronize { event_cache.delete(session_id(session)) }
    raise
  end

  def players_for(session)
    embedded = session["__players"]
    return unique_users(embedded) if embedded.is_a?(Array)

    persisted_players_for(session)
  end

  def actor_of(event, session = nil)
    author = insertion_user(event, "actor")
    claimed = event["actor"].to_s
    if native_live_sessions? && event["__controller"] == true
      return "" if session == nil
      owner = insertion_user(session, "player_one")
      return "" if !GameRoomParticipants.same?(author, owner)
      return "" if !includes_user?(players_for(session), claimed)
      return claimed
    end
    return author if !GameRoomParticipants.bot?(claimed)
    return "" if session == nil

    players = players_for(session)
    owner = insertion_user(session, "player_one")
    return "" if !includes_user?(players, claimed)
    return "" if author.casecmp(owner) != 0

    claimed
  end

  def session_id(row)
    row_id(row)
  end

  def event_id(row)
    row_id(row)
  end

  private

  def native_live_sessions?
    @transport.respond_to?(:live_store?) && @transport.live_store?
  end

  def start_session_once(table:, game:, players:, options:, recipients:, expected_previous_session_id:)
    current = session_for_table(table)
    if expected_previous_session_id != nil && session_id(current) != expected_previous_session_id.to_i
      return current
    end

    owner = insertion_user(table, "owner")
    raise ArgumentError, "Only the table owner may start a game" if owner.casecmp(Session.name.to_s) != 0

    participants = unique_users(players)
    raise ArgumentError, "A game requires at least one player" if participants.empty?
    raise ArgumentError, "A game supports at most #{MAX_PLAYERS} players" if participants.length > MAX_PLAYERS
    raise ArgumentError, "A game participant name is too long" if participants.any? { |participant| participant.length > MAX_PLAYER_LENGTH }
    if !native_live_sessions? && participants.first.casecmp(owner) != 0
      raise ArgumentError, "The table owner must be the first player"
    end

    if native_live_sessions?
      inserted = @transport.start_game(
        table: table,
        game: game,
        players: participants,
        options: options,
        actor: Session.name
      )
      return inserted
    end

    timestamp = Time.now.to_i
    inserted = sessions_table.insert(
      "table_id" => row_id(table),
      "game" => game.to_s,
      "player_one" => participants[0],
      "player_two" => participants[1].to_s,
      "players_json" => encode_players(participants),
      "status" => "active",
      "options" => options.to_s,
      "created_at" => timestamp,
      "updated_at" => timestamp
    )
    inserted = with_players(inserted, participants)
    replace_event_cache(inserted, [])
    resolved = resolve_started_session(inserted, table)
    if session_id(resolved) == session_id(inserted)
      notify_game_changed(inserted, GameRoomParticipants.humans(recipients), change: "started")
    end
    resolved
  end

  def resolve_started_session(inserted, table)
    latest = session_for_table(table)
    return inserted if latest == nil || session_id(latest) < session_id(inserted)

    latest
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room could not reconcile simultaneous game starts: #{error.class}: #{error.message}")
    inserted
  end

  def command_value(command, key)
    return command.public_send(key) if command.respond_to?(key)
    return nil if !command.respond_to?(:key?)
    return command[key] if command.key?(key)
    return command[key.to_sym] if command.key?(key.to_sym)

    nil
  end

  def session_rows(table_id: nil)
    return @transport.game_sessions(table_id) if native_live_sessions?

    where = table_id == nil ? nil : { "table_id" => table_id.to_i }
    sessions_table
      .select(where: where, order: [["created_at", "desc"]], limit: SESSION_LIMIT)
      .to_a
  end

  def events_for(session, force: false)
    return @transport.game_events(session, force: force) if native_live_sessions?

    id = session_id(session)
    return [] if id <= 0

    entry = event_cache_entry(id)
    if entry != nil && !force && monotonic_time - entry[:checked_at] < EVENT_CACHE_FRESHNESS
      return entry[:events].dup
    end

    # Locally inserted rows are visible optimistically, but they do not extend
    # the contiguous prefix already fetched from the server. Another client may
    # have inserted an earlier row which this repository has not seen yet.
    offset = entry == nil ? 0 : entry[:confirmed_count].to_i
    remaining = EVENT_LIMIT - offset
    return entry[:events].dup if remaining <= 0

    rows = events_table.select(
      where: event_scope(session),
      order: event_order,
      limit: remaining,
      offset: offset
    ).to_a
    merge_event_cache(id, entry, rows, confirmed_count: offset + rows.length)
  end

  def event_order
    # Incremental reads use the cached row count as their offset. Therefore the
    # server order must be append-only: a concurrently inserted row may share a
    # client sequence and timestamp, but its server ID can never move in front
    # of rows that have already been read.
    [["__id", "asc"]]
  end

  def event_scope(session)
    {
      "session_id" => session_id(session),
      "table_id" => session["table_id"].to_i
    }
  end

  def event_cache_entry(id)
    event_cache_mutex.synchronize do
      entry = event_cache[id]
      if entry == nil
        nil
      else
        entry[:touched_at] = monotonic_time
        {
          events: entry[:events].dup,
          confirmed_count: entry[:confirmed_count].to_i,
          checked_at: entry[:checked_at]
        }
      end
    end
  end

  def merge_event_cache(id, entry, rows, confirmed_count: nil)
    combined = (entry == nil ? [] : entry[:events]) + rows.to_a
    combined = combined.each_with_object({}) do |row, unique|
      key = event_id(row)
      unique[key > 0 ? key : [row["sequence"], row["move_id"]]] = row
    end.values.sort_by { |row| event_id(row) }
    previous_confirmed = entry == nil ? 0 : entry[:confirmed_count].to_i
    next_confirmed = confirmed_count == nil ? previous_confirmed : [previous_confirmed, confirmed_count.to_i].max
    event_cache_mutex.synchronize do
      event_cache[id] = {
        events: combined,
        confirmed_count: next_confirmed,
        checked_at: monotonic_time,
        touched_at: monotonic_time
      }
      prune_event_cache
    end
    combined.dup
  end

  def append_to_event_cache(session, rows)
    id = session_id(session)
    entry = event_cache_entry(id)
    return if entry == nil

    merge_event_cache(id, entry, rows)
  end

  def replace_event_cache(session, rows)
    id = session_id(session)
    return if id <= 0

    event_cache_mutex.synchronize do
      now = monotonic_time
      event_cache[id] = {
        events: rows.to_a.sort_by { |row| event_id(row) },
        confirmed_count: rows.length,
        checked_at: now,
        touched_at: now
      }
      prune_event_cache
    end
  end

  def prune_event_cache
    overflow = event_cache.length - EVENT_CACHE_LIMIT
    return if overflow <= 0

    event_cache.sort_by { |_id, entry| entry[:touched_at] }
      .first(overflow)
      .each { |id, _entry| event_cache.delete(id) }
  end

  def event_cache
    @event_cache ||= {}
  end

  def event_cache_mutex
    @event_cache_mutex ||= Mutex.new
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rescue Exception
    Time.now.to_f
  end

  def sessions_table
    @sessions_table ||= @server_tables.fetch("game_sessions")
  end

  def events_table
    @events_table ||= @server_tables.fetch("game_events")
  end

  def persisted_players_for(session)
    encoded = session["players_json"].to_s
    return [] if encoded.empty? || encoded.length > MAX_PLAYERS_JSON_LENGTH

    payload = JSON.parse(encoded)
    return [] if !payload.is_a?(Hash) || payload["version"].to_i != PLAYERS_FORMAT_VERSION

    seats = payload["seats"]
    return [] if !seats.is_a?(Array) || seats.empty? || seats.length > MAX_PLAYERS
    return [] if seats.map { |seat| seat.is_a?(Hash) ? seat["id"] : nil } != (1..seats.length).to_a

    players = seats.map { |seat| seat["controller"].to_s }
    return [] if players.any? { |player| player.empty? || player.length > MAX_PLAYER_LENGTH }

    unique = unique_users(players)
    unique.length == players.length ? unique : []
  rescue JSON::ParserError, TypeError
    []
  end

  def encode_players(players)
    encoded = JSON.generate(
      "version" => PLAYERS_FORMAT_VERSION,
      "seats" => players.each_with_index.map do |player, index|
        { "id" => index + 1, "controller" => player }
      end
    )
    raise ArgumentError, "The game participant list is too large" if encoded.length > MAX_PLAYERS_JSON_LENGTH

    encoded
  end

  def with_players(session, players)
    session.merge("__players" => unique_users(players))
  end

  def notify_game_changed(session, users, change:)
    @transport.game_changed(
      table_id: session["table_id"],
      session_id: session_id(session),
      users: users,
      change: change,
      actor: Session.name
    )
  end

  def row_id(row)
    return 0 if row == nil

    (row["__id"] || row["id"]).to_i
  end

  def insertion_user(row, fallback_key)
    user = row["__insertion_user"].to_s
    user.empty? ? row[fallback_key].to_s : user
  end

  def valid_session_for_table?(session, table, players: persisted_players_for(session))
    owner = insertion_user(table, "owner")
    creator = insertion_user(session, "player_one")
    # LiveSessions authenticates the author independently of the playing seats.
    # The table master may be an observer (including a Taboo moderator).
    valid_first_seat = native_live_sessions? ?
      session["player_one"].to_s.casecmp(players.first.to_s) == 0 :
      session["player_one"].to_s.casecmp(owner) == 0 && players.first.to_s.casecmp(owner) == 0
    session["table_id"].to_i == row_id(table) &&
      session["game"].to_s == table["game"].to_s &&
      creator.casecmp(owner) == 0 &&
      !players.empty? &&
      valid_first_seat
  end

  def unique_users(users)
    result = []
    users.to_a.each do |user|
      value = user.to_s
      next if value.empty? || includes_user?(result, value)

      result << value
    end
    result
  end

  def includes_user?(users, user)
    users.any? { |candidate| candidate.to_s.casecmp(user.to_s) == 0 }
  end
end
