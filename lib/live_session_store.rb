require "json"
require "securerandom"
require "thread"
require_relative "game_participants"

# The authoritative, ephemeral state of one Game Room table lives in one
# discoverable LiveSession.  Every mutation is appended to the session stack;
# repositories only project that ordered log into their familiar row-shaped
# values.  App tables are deliberately not involved in room or game state.
class GameRoomLiveSessionStore
  KIND = "elten_game_room_table".freeze
  PROTOCOL = 2
  MAX_CAPACITY = 8
  STACK_ENTRIES = 4_096
  STACK_ENTRY_BYTES = 16_384
  STACK_PAGE_SIZE = 128
  EVENT_ID_MULTIPLIER = 100
  DISCOVERY_LIMIT = 100
  INVITATION_TTL = 10 * 60

  Record = Struct.new(
    :table_id,
    :sequence,
    :message_id,
    :sender,
    :packet,
    :created_at,
    keyword_init: true
  )

  def initialize(program, changed: nil, endpoint_provider: nil)
    @program = program
    @changed = changed
    @endpoint_provider = endpoint_provider || -> { @program.live_sessions }
    @endpoint = nil
    @invitation_endpoint = nil
    @sessions = {}
    @native_session_ids = {}
    @records = Hash.new { |hash, key| hash[key] = [] }
    @record_keys = Hash.new { |hash, key| hash[key] = {} }
    @stack_cursors = Hash.new(0)
    @received_sequences = Hash.new { |hash, key| hash[key] = {} }
    @discovered = {}
    @pending_invitations = {}
    @resolved_invitations = {}
    @mutex = Mutex.new
  end

  def start
    current = endpoint
    current.sessions.to_a.each { |session| attach_supported_session(session) } if current.respond_to?(:sessions)
    true
  end

  def create_room(name:, game:, owner:, game_options:, capacity: MAX_CAPACITY)
    start
    table_id = unused_identifier
    maximum = bounded_capacity(capacity)
    metadata = {
      "kind" => KIND,
      "protocol" => PROTOCOL,
      "table_id" => table_id,
      "owner" => owner.to_s,
      "name" => name.to_s,
      "game" => game.to_s,
      "game_options" => game_options.to_s,
      "created_at" => Time.now.to_i
    }
    discovery = metadata.dup
    session = endpoint.create(
      metadata: metadata,
      participant_metadata: participant_metadata(table_id),
      capacity: maximum,
      visibility: :public,
      discovery_metadata: discovery,
      stack_entry_bytes: STACK_ENTRY_BYTES,
      stack_entries: STACK_ENTRIES,
      pool_count: 1,
      private_messages: true
    )
    attach_session(table_id, session)
    append_record(table_id, "room_created", {
      "name" => name.to_s,
      "game" => game.to_s,
      "owner" => owner.to_s,
      "status" => "waiting",
      "max_players" => maximum,
      "bot_count" => 0,
      "game_options" => game_options.to_s,
      "created_at" => metadata["created_at"]
    }, actor: owner)
    table_for(table_id)
  rescue StandardError
    begin
      session&.close
    rescue StandardError
      nil
    end
    raise
  end

  def discover_rooms(game: nil)
    start
    found = {}
    discover_pages.each do |item|
      metadata = item.discovery_metadata.to_h
      next if !supported_metadata?(metadata)

      table_id = positive_identifier(metadata["table_id"])
      next if table_id == nil

      @mutex.synchronize { @discovered[table_id] = item }
      row = table_from_discovered(item, metadata)
      row = table_for(table_id, fallback: row) if active_session(table_id) != nil
      next if row == nil || (game != nil && row["game"].to_s != game.to_s)

      found[table_id] = row
    end
    active_table_ids.each do |table_id|
      row = table_for(table_id)
      next if row == nil || (game != nil && row["game"].to_s != game.to_s)

      found[table_id] = row
    end
    found.values.select { |row| %w[waiting playing].include?(row["status"].to_s) }
      .sort_by { |row| [row["status"].to_s == "waiting" ? 0 : 1, -row["updated_at"].to_i, -row["__id"].to_i] }
  end

  def current_room(user)
    start
    username = user.to_s
    active_table_ids.filter_map do |table_id|
      next if !connected_users(table_id).any? { |candidate| same_user?(candidate, username) }

      table_for(table_id)
    end.max_by { |row| [row["created_at"].to_i, row["__id"].to_i] }
  end

  def room_snapshot(table_or_id)
    table_id = table_identifier(table_or_id)
    return nil if table_id == nil

    ensure_current(table_id)
    session = active_session(table_id)
    return nil if session == nil

    table = table_for(table_id)
    return nil if table == nil || !%w[waiting playing].include?(table["status"].to_s)

    members = connected_users(table_id)
    owner = table["owner"].to_s
    members.sort_by! { |member| same_user?(member, owner) ? 0 : 1 }
    {
      table: table,
      members: unique_users(members),
      bots: GameRoomParticipants.bots_for(table_id, table["bot_count"].to_i)
    }
  end

  def join_room(table, user)
    table_id = table_identifier(table)
    return :closed if table_id == nil
    return :already_here if active_session(table_id) != nil && connected_users(table_id).any? { |name| same_user?(name, user) }

    discovered = table.is_a?(Hash) ? table["__discovered_session"] : nil
    discovered ||= @mutex.synchronize { @discovered[table_id] }
    discovered ||= discover_item(table_id)
    return :closed if discovered == nil
    return :full if discovered.respond_to?(:can_join?) && !discovered.can_join? && discovered.join_reason.to_s == "full"

    session = discovered.join(participant_metadata: participant_metadata(table_id))
    admit_joined_session(table_id, session)
  end

  def update_room(table_or_id, changes, actor:)
    table_id = table_identifier(table_or_id)
    raise ArgumentError, "Invalid room" if table_id == nil

    allowed = %w[status bot_count game_options updated_at]
    values = changes.to_h.each_with_object({}) do |(key, value), result|
      name = key.to_s
      result[name] = value if allowed.include?(name)
    end
    values["updated_at"] = Time.now.to_i
    append_record(table_id, "room_state", values, actor: actor)
    table_for(table_id)
  end

  def deactivate_room(table_or_id)
    table_id = table_identifier(table_or_id)
    return false if table_id == nil

    session = @mutex.synchronize do
      @native_session_ids.delete_if { |_native_id, id| id == table_id }
      @sessions.delete(table_id)
    end
    return false if session == nil

    session.owner? ? session.close : session.leave
    true
  end

  def connected_users(table_or_id)
    table_id = table_identifier(table_or_id)
    session = table_id == nil ? nil : active_session(table_id)
    return [] if session == nil

    unique_users(session.participants.to_a.map { |participant| participant.user.to_s })
  rescue StandardError
    []
  end

  def append_activity(table:, kind:, actor:, message: "")
    table_id = table_identifier(table)
    raise ArgumentError, "Invalid activity room" if table_id == nil

    record = append_record(table_id, "room_activity", {
      "activity_kind" => kind.to_s,
      "message" => message.to_s,
      "owner" => table["owner"].to_s,
      "game" => table["game"].to_s
    }, actor: actor)
    activity_record(record)
  end

  def activity_records(table_or_id)
    table_id = table_identifier(table_or_id)
    return [] if table_id == nil

    ensure_current(table_id)
    records_for(table_id)
      .select { |record| record.packet["kind"].to_s == "room_activity" }
      .map { |record| activity_record(record) }
  end

  def start_game(table:, game:, players:, options:, actor:)
    table_id = table_identifier(table)
    raise ArgumentError, "Invalid room" if table_id == nil

    game_session_id = unused_game_identifier(table_id)
    # Keep one complete room-state record before the new game. The immutable
    # room identity remains in native session metadata. No current-game replay
    # is truncated, and chat already received by this client stays local.
    state = table_for(table_id)
    checkpoint = append_record(table_id, "room_state", state.slice(
      "status", "bot_count", "game_options", "updated_at"
    ), actor: actor)
    payload = {
      "session_id" => game_session_id,
      "game" => game.to_s,
      "players" => players.to_a.map(&:to_s),
      "options" => options.to_s,
      "created_at" => Time.now.to_i
    }
    record = append_record(table_id, "game_started", payload, actor: actor)
    trim_previous_games(table_id, checkpoint.sequence - 1) if record != nil && checkpoint != nil
    game_session_from(record)
  end

  def game_sessions(table_or_id = nil, force: false)
    table_id = table_or_id == nil ? nil : table_identifier(table_or_id)
    ids = table_id == nil ? active_table_ids : [table_id]
    ids.compact.flat_map do |id|
      ensure_current(id, force: force)
      records_for(id).filter_map do |record|
        game_session_from(record) if record.packet["kind"].to_s == "game_started"
      end
    end.sort_by { |row| row["__id"].to_i }
  end

  def game_session(session_id, table: nil)
    wanted = positive_identifier(session_id)
    return nil if wanted == nil

    game_sessions(table).find { |row| row["__id"].to_i == wanted }
  end

  def append_game_action(session:, sequence:, events:, actor:)
    table_id = positive_identifier(session["table_id"])
    session_id = positive_identifier(session["__id"] || session["id"])
    raise ArgumentError, "Invalid game" if table_id == nil || session_id == nil

    commands = events.to_a.map do |event|
      {
        "action" => command_value(event, "action").to_s,
        "value" => command_value(event, "value").to_s,
        "move_id" => SecureRandom.uuid
      }
    end
    record = append_record(table_id, "game_action", {
      "session_id" => session_id,
      "sequence" => sequence.to_i,
      "events" => commands
    }, actor: actor)
    expand_game_action(record)
  end

  def game_events(session, force: false)
    table_id = positive_identifier(session["table_id"])
    session_id = positive_identifier(session["__id"] || session["id"])
    return [] if table_id == nil || session_id == nil

    ensure_current(table_id, force: force)
    records_for(table_id).flat_map do |record|
      next [] if record.packet["kind"].to_s != "game_action"
      next [] if record.packet.dig("data", "session_id").to_i != session_id

      expand_game_action(record)
    end.sort_by { |row| row["__id"].to_i }
  end

  def invite_user(table_id:, user:, metadata:)
    session = active_session(table_identifier(table_id))
    return false if session == nil

    # The current API accepts a participant identity for invitations, not just
    # the room owner's identity. Let it validate the actual membership.
    result = session.invite(user.to_s, metadata: metadata.to_h.merge("purpose" => "game_invitation"))
    result != false
  end

  def pending_invitations
    prune_invitations
    recipient = endpoint.user.to_s
    @mutex.synchronize do
      @pending_invitations.values.map do |stored|
        invitation = stored[:invitation]
        metadata = invitation.invitation_metadata.to_h
        inviter = invitation.respond_to?(:inviter) ? invitation.inviter.user.to_s : metadata["sender"].to_s
        {
          "__id" => stored[:id],
          "table_id" => stored[:table_id],
          "sender" => inviter,
          "recipient" => recipient,
          "status" => "pending",
          "created_at" => stored[:created_at],
          "expires_at" => invitation.respond_to?(:expires_at) ? invitation.expires_at.to_i : stored[:created_at] + INVITATION_TTL,
          "__native_invitation" => invitation
        }
      end
    end
  end

  def accept_invitation(table_id:, invitation_id:, participant_metadata: {})
    stored = take_invitation(table_id, invitation_id)
    return false if stored == nil

    session = stored[:invitation].accept(participant_metadata: participant_metadata(table_id).merge(participant_metadata.to_h))
    status = admit_joined_session(stored[:table_id], session)
    resolve_invitation(stored[:id])
    status == :joined
  rescue StandardError
    restore_invitation(stored) if stored && stored[:invitation].pending?
    raise
  end

  def reject_invitation(table_id:, invitation_id:)
    stored = take_invitation(table_id, invitation_id)
    return false if stored == nil

    stored[:invitation].reject
    resolve_invitation(stored[:id])
    true
  rescue StandardError
    restore_invitation(stored) if stored
    raise
  end

  def wait_for_room(table_id, timeout: 10.0)
    wanted = table_identifier(table_id)
    return false if wanted == nil

    deadline = monotonic + [timeout.to_f, 0.0].max
    loop do
      return true if active_session(wanted) != nil
      return false if monotonic >= deadline

      sleep 0.01
    end
  end

  private

  def trim_previous_games(table_id, through)
    return if through <= 0

    session = active_session(table_id)
    return if session == nil || !session.owner?

    session.stack_trim(through: through)
  rescue StandardError => error
    # The game is already committed. A failed/uncertain trim must not make the
    # caller retry starting it, or remove any additional records speculatively.
    log_warning("previous game cleanup", table_id, error)
  end

  # Discovery and invitation acceptance must apply the same human + bot limit.
  # The native capacity alone only counts connected humans.
  def admit_joined_session(table_id, session)
    attach_session(table_id, session)
    snapshot = room_snapshot(table_id)
    status = if snapshot == nil
      :closed
    elsif snapshot[:members].length + snapshot[:bots].length > snapshot[:table]["max_players"].to_i
      :full
    else
      :joined
    end
    deactivate_room(table_id) if status != :joined
    status
  rescue StandardError
    begin
      deactivate_room(table_id)
      session.leave if !session.closed?
    rescue StandardError => error
      log_warning("rejected membership cleanup", table_id, error)
    end
    raise
  end

  def endpoint
    current = @endpoint_provider.call
    changed = @mutex.synchronize do
      different = !@endpoint.equal?(current)
      @endpoint = current
      different
    end
    register_invitation_callback(current) if changed
    current
  end

  def register_invitation_callback(current)
    register = @mutex.synchronize do
      next false if @invitation_endpoint.equal?(current)

      @invitation_endpoint = current
      true
    end
    return if !register

    current.on_invitation { |invitation| receive_invitation(invitation) }
    return if !current.respond_to?(:next_invitation)

    loop do
      invitation = current.next_invitation(timeout: 0)
      break if invitation == nil

      receive_invitation(invitation)
    end
  end

  def receive_invitation(invitation)
    return if invitation.respond_to?(:pending?) && !invitation.pending?

    metadata = invitation.metadata.to_h
    return if !supported_metadata?(metadata)

    invitation_metadata = invitation.invitation_metadata.to_h
    return if invitation_metadata["purpose"].to_s != "game_invitation"

    table_id = positive_identifier(metadata["table_id"])
    invitation_id = positive_identifier(invitation_metadata["invitation_id"])
    return if table_id == nil || invitation_id == nil

    @mutex.synchronize do
      return if @resolved_invitations.key?(invitation_id)

      @pending_invitations[invitation_id] = {
        id: invitation_id,
        table_id: table_id,
        invitation: invitation,
        created_at: Time.now.to_i
      }
    end
    emit_change(table_id, :invitation, invitation_id)
  rescue StandardError => error
    log_warning("incoming invitation", nil, error)
  end

  def take_invitation(table_id, invitation_id)
    id = positive_identifier(invitation_id)
    room_id = table_identifier(table_id)
    return nil if id == nil || room_id == nil

    @mutex.synchronize do
      stored = @pending_invitations[id]
      next nil if stored == nil || stored[:table_id] != room_id

      @pending_invitations.delete(id)
    end
  end

  def restore_invitation(stored)
    @mutex.synchronize { @pending_invitations[stored[:id]] = stored }
  end

  def resolve_invitation(id)
    @mutex.synchronize do
      @pending_invitations.delete(id.to_i)
      @resolved_invitations[id.to_i] = Time.now.to_i + INVITATION_TTL
    end
  end

  def prune_invitations
    now = Time.now.to_i
    @mutex.synchronize do
      @pending_invitations.delete_if do |_id, stored|
        invitation = stored[:invitation]
        (invitation.respond_to?(:pending?) && !invitation.pending?) ||
          (invitation.respond_to?(:expires_at) && invitation.expires_at.to_i.positive? && invitation.expires_at.to_i <= now)
      end
      @resolved_invitations.delete_if { |_id, expires_at| expires_at <= now }
    end
  end

  def discover_pages
    return [] if !endpoint.respond_to?(:discover_sessions)

    result = []
    cursor = nil
    loop do
      page = endpoint.discover_sessions(
        sources: [:created, :invited, :public],
        limit: DISCOVERY_LIMIT,
        cursor: cursor
      )
      result.concat(page.to_a)
      cursor = page.respond_to?(:next_cursor) ? page.next_cursor : nil
      break if cursor.to_s.empty?
    end
    result
  end

  def discover_item(table_id)
    discover_pages.find do |item|
      metadata = item.discovery_metadata.to_h
      supported_metadata?(metadata) && metadata["table_id"].to_i == table_id.to_i
    end
  end

  def attach_supported_session(session)
    metadata = session.metadata.to_h
    return nil if !supported_metadata?(metadata)

    table_id = positive_identifier(metadata["table_id"])
    table_id == nil ? nil : attach_session(table_id, session)
  end

  def attach_session(table_id, session)
    existing = @mutex.synchronize { @sessions[table_id] }
    return existing if existing.equal?(session)

    if session.respond_to?(:on_stack_message)
      session.on_stack_message(with_metadata: true) do |sender, packet, info|
        ingest_record(
          table_id,
          sequence: info.sequence,
          message_id: info.id,
          sender: sender.user,
          packet: packet,
          created_at: info.created_at
        )
      end
      session.on_stack_gap do |_gap|
        # Wake the normal synchronizer; do not run a blocking read inside a
        # native callback. A read failure must retain the recovery wake-up.
        emit_change(table_id, :recovery, nil)
      end
    end
    session.on_participant_joined { |_participant| emit_change(table_id, :table, nil) } if session.respond_to?(:on_participant_joined)
    session.on_participant_left { |_participant, _reason = nil| emit_change(table_id, :table, nil) } if session.respond_to?(:on_participant_left)
    if session.respond_to?(:on_closed)
      session.on_closed do |_reason|
        @mutex.synchronize do
          @sessions.delete(table_id) if @sessions[table_id].equal?(session)
          @native_session_ids.delete(session.id.to_s) if session.respond_to?(:id)
        end
        emit_change(table_id, :closed, nil)
      end
    end
    @mutex.synchronize do
      @sessions[table_id] = session
      @native_session_ids[session.id.to_s] = table_id if session.respond_to?(:id)
    end
    ensure_current(table_id, force: true) if session.respond_to?(:stack_read)
    session
  end

  def ensure_current(table_id, force: false)
    session = active_session(table_id)
    return false if session == nil || !session.respond_to?(:stack_read)

    last_sequence = session.respond_to?(:stack_state) ? session.stack_state["last_seq"].to_i : 0
    cursor = @mutex.synchronize { @stack_cursors[table_id].to_i }
    return true if !force && last_sequence <= cursor

    loop do
      page = session.stack_read(after: cursor, limit: STACK_PAGE_SIZE)
      Array(page["entries"]).each do |entry|
        sender = if entry["sender"].is_a?(Hash)
          entry["sender"]["user"].to_s
        elsif session.respond_to?(:participant)
          session.participant(entry["sender_id"])&.user.to_s
        else
          ""
        end
        ingest_record(
          table_id,
          sequence: entry["seq"],
          message_id: entry["message_id"],
          sender: sender,
          packet: entry["packet"],
          created_at: entry["created_at"]
        )
      end
      next_cursor = page["cursor"].to_i
      @mutex.synchronize do
        @stack_cursors[table_id] = [@stack_cursors[table_id].to_i, next_cursor].max
        @received_sequences[table_id].delete_if { |seq, _| seq <= @stack_cursors[table_id] }
      end
      break if next_cursor <= cursor || page["has_more"] != true

      cursor = next_cursor
    end
    true
  rescue StandardError => error
    log_warning("stack read", table_id, error)
    # Do not present a partial local prefix as a successful server snapshot.
    # The UI's network boundary handles the error and its synchronizer retries.
    raise
  end

  def append_record(table_id, kind, data, actor:)
    session = active_session(table_id)
    raise ArgumentError, "The room is no longer active" if session == nil

    message_id = SecureRandom.uuid
    packet = {
      "version" => PROTOCOL,
      "kind" => kind.to_s,
      "actor" => actor.to_s,
      "data" => JSON.parse(JSON.generate(data))
    }
    result = session.stack_push(packet, message_id: message_id)
    sequence = extract_push_sequence(result, session)
    record = ingest_record(
      table_id,
      sequence: sequence,
      message_id: message_id,
      sender: endpoint.user.to_s,
      packet: packet,
      created_at: Time.now.to_i
    )
    record || records_for(table_id).find { |entry| entry.message_id == message_id }
  end

  def extract_push_sequence(result, session)
    candidates = [
      result.is_a?(Hash) ? result["seq"] : nil,
      result.is_a?(Hash) ? result.dig("entry", "seq") : nil,
      result.is_a?(Hash) ? result.dig("stack", "last_seq") : nil,
      session.respond_to?(:stack_state) ? session.stack_state["last_seq"] : nil
    ]
    sequence = candidates.map(&:to_i).find { |value| value.positive? }
    raise "LiveSessions did not return the stored stack position" if sequence == nil

    sequence
  end

  def ingest_record(table_id, sequence:, message_id:, sender:, packet:, created_at:)
    seq = sequence.to_i
    identity = message_id.to_s
    return nil if seq <= 0 || identity.empty? || !packet.is_a?(Hash)
    if packet["version"] != PROTOCOL || !valid_record?(table_id, sender, packet)
      # Do not print packet contents (they may contain private game data).
      Log.warning("ELTEN Game Room discarded invalid stack entry for table #{table_id}, sequence #{seq}") if defined?(Log)
      return nil
    end

    record = Record.new(
      table_id: table_id,
      sequence: seq,
      message_id: identity,
      sender: sender.to_s,
      packet: JSON.parse(JSON.generate(packet)),
      created_at: normalize_time(created_at)
    )
    inserted = @mutex.synchronize do
      key = [seq, identity]
      next false if @record_keys[table_id].key?(key)

      @record_keys[table_id][key] = true
      @records[table_id] << record
      @records[table_id].sort_by!(&:sequence)
      # A local push acknowledgement can overtake messages not delivered yet.
      # Only a contiguous prefix is safe as the cursor of subsequent reads.
      cursor = @stack_cursors[table_id]
      @received_sequences[table_id][seq] = true if seq > cursor
      cursor += 1 while @received_sequences[table_id].delete(cursor + 1)
      @stack_cursors[table_id] = cursor
      true
    end
    emit_record_change(table_id, record) if inserted
    inserted ? record : nil
  rescue JSON::GeneratorError, JSON::ParserError
    nil
  end

  def emit_record_change(table_id, record)
    kind = record.packet["kind"].to_s
    data = record.packet["data"].to_h
    case kind
    when "game_started"
      emit_change(table_id, :game_started, data["session_id"].to_i)
    when "game_action"
      emit_change(table_id, :game, data["session_id"].to_i)
    else
      emit_change(table_id, :table, nil)
    end
  end

  def emit_change(table_id, kind, value)
    @changed&.call(table_id.to_i, kind.to_sym, value)
  rescue StandardError => error
    log_warning("change callback", table_id, error)
  end

  def records_for(table_id)
    @mutex.synchronize { @records[table_id].dup }
  end

  def table_for(table_id, fallback: nil)
    session = active_session(table_id)
    metadata = session&.metadata.to_h
    base = fallback || table_from_metadata(metadata || {}, table_id)
    return nil if base == nil

    row = base.dup
    records_for(table_id).each do |record|
      case record.packet["kind"].to_s
      when "room_created"
        data = record.packet["data"].to_h
        row.merge!(data)
      when "room_state"
        row.merge!(record.packet["data"].to_h)
      end
      row["updated_at"] = [row["updated_at"].to_i, record.created_at.to_i].max
    end
    row["__id"] = table_id
    row["id"] = table_id
    row["__insertion_user"] = row["owner"].to_s
    row["max_players"] = bounded_capacity(row["max_players"] || session&.capacity)
    row["bot_count"] = [[row["bot_count"].to_i, 0].max, row["max_players"]].min
    row["player_count"] = connected_users(table_id).length + row["bot_count"].to_i
    row["status"] = "waiting" if row["status"].to_s.empty?
    row["created_at"] = metadata["created_at"].to_i if row["created_at"].to_i <= 0 && metadata
    row["updated_at"] = row["created_at"].to_i if row["updated_at"].to_i <= 0
    row["__live_session_id"] = session.id.to_s if session&.respond_to?(:id)
    row
  end

  def table_from_metadata(metadata, table_id)
    return nil if !supported_metadata?(metadata)

    {
      "__id" => table_id,
      "id" => table_id,
      "__insertion_user" => metadata["owner"].to_s,
      "name" => metadata["name"].to_s,
      "game" => metadata["game"].to_s,
      "owner" => metadata["owner"].to_s,
      "status" => "waiting",
      "max_players" => MAX_CAPACITY,
      "bot_count" => 0,
      "game_options" => metadata["game_options"].to_s,
      "player_count" => 1,
      "created_at" => metadata["created_at"].to_i,
      "updated_at" => metadata["created_at"].to_i
    }
  end

  def table_from_discovered(item, metadata)
    table_id = positive_identifier(metadata["table_id"])
    return nil if table_id == nil

    row = table_from_metadata(metadata, table_id)
    row["max_players"] = bounded_capacity(item.capacity)
    row["player_count"] = item.participant_count.to_i
    row["__live_session_id"] = item.id.to_s
    row["__discovered_session"] = item
    row
  end

  def game_session_from(record)
    return nil if record == nil || record.packet["kind"].to_s != "game_started"

    data = record.packet["data"].to_h
    players = data["players"].to_a.map(&:to_s)
    id = positive_identifier(data["session_id"])
    return nil if id == nil || players.empty?

    {
      "__id" => id,
      "id" => id,
      "__insertion_user" => record.sender.to_s,
      "table_id" => table_id_for_record(record),
      "game" => data["game"].to_s,
      "player_one" => players[0].to_s,
      "player_two" => players[1].to_s,
      "players_json" => JSON.generate(
        "version" => 1,
        "seats" => players.each_with_index.map { |player, index| { "id" => index + 1, "controller" => player } }
      ),
      "__players" => players,
      "status" => "active",
      "options" => data["options"].to_s,
      "created_at" => data["created_at"].to_i,
      "updated_at" => data["created_at"].to_i,
      "__stack_sequence" => record.sequence.to_i
    }
  end

  def activity_record(record)
    return nil if record == nil || record.packet["kind"].to_s != "room_activity"

    data = record.packet["data"].to_h
    {
      "__id" => record.sequence.to_i * EVENT_ID_MULTIPLIER,
      "id" => record.sequence.to_i * EVENT_ID_MULTIPLIER,
      "table_id" => record.table_id.to_i,
      "kind" => data["activity_kind"].to_s,
      "actor" => record.packet["actor"].to_s,
      "table_owner" => data["owner"].to_s,
      "game" => data["game"].to_s,
      "message" => data["message"].to_s,
      "created_at" => record.created_at.to_i,
      "__insertion_user" => record.sender.to_s
    }
  end

  def table_id_for_record(record)
    record.table_id.to_i
  end

  def expand_game_action(record)
    data = record.packet["data"].to_h
    table_id = table_id_for_record(record)
    actor = record.packet["actor"].to_s
    Array(data["events"]).each_with_index.map do |command, offset|
      {
        "__id" => record.sequence.to_i * EVENT_ID_MULTIPLIER + offset,
        "id" => record.sequence.to_i * EVENT_ID_MULTIPLIER + offset,
        "__insertion_user" => record.sender.to_s,
        "session_id" => data["session_id"].to_i,
        "table_id" => table_id,
        "sequence" => data["sequence"].to_i + offset,
        "move_id" => command["move_id"].to_s,
        "actor" => actor,
        "action" => command["action"].to_s,
        "value" => command["value"].to_s,
        "created_at" => record.created_at.to_i
      }
    end
  end

  def command_value(command, key)
    return command.public_send(key) if command.respond_to?(key)
    return nil if !command.respond_to?(:key?)
    return command[key] if command.key?(key)
    return command[key.to_sym] if command.key?(key.to_sym)

    nil
  end

  def valid_record?(table_id, sender, packet)
    kind = packet["kind"]
    actor = packet["actor"]
    data = packet["data"]
    return false if sender.to_s.empty? || !kind.is_a?(String) || !nonempty_text?(actor) || !data.is_a?(Hash)

    owner = owner_for(table_id)
    case kind
    when "room_created"
      return false if !same_user?(sender, owner) || !same_user?(actor, owner)

      same_user?(data["owner"], owner) && nonempty_text?(data["owner"]) &&
        nonempty_text?(data["name"]) && nonempty_text?(data["game"]) &&
        room_fields_valid?(data) && integer_between?(data["max_players"], 2, MAX_CAPACITY)
    when "room_state"
      return false if !same_user?(sender, owner) || !same_user?(actor, owner)

      (data.keys - %w[status bot_count game_options updated_at]).empty? && room_fields_valid?(data)
    when "room_activity"
      same_user?(sender, actor) &&
        %w[created joined left bot_added bot_removed chat].include?(data["activity_kind"]) &&
        %w[message owner game].all? { |key| data[key].is_a?(String) }
    when "game_started"
      return false if !same_user?(sender, owner) || !same_user?(actor, owner)

      players = data["players"]
      players.is_a?(Array) && players.all? { |player| nonempty_text?(player) } &&
        players.length.between?(1, MAX_CAPACITY) && same_user?(players.first, owner) &&
        unique_users(players).length == players.length && positive_integer?(data["session_id"]) &&
        nonempty_text?(data["game"]) && json_object_text?(data["options"]) &&
        positive_integer?(data["created_at"])
    when "game_action"
      valid_game_action_record?(table_id, sender, actor, data, owner)
    else
      false
    end
  end

  def valid_game_action_record?(table_id, sender, actor, data, owner)
    return false if GameRoomParticipants.bot?(actor) ? !same_user?(sender, owner) : !same_user?(sender, actor)

    session_id = data["session_id"]
    commands = data["events"]
    return false if !positive_integer?(session_id) || !data["sequence"].is_a?(Integer) || data["sequence"] < 0
    return false if !commands.is_a?(Array) || commands.empty? || commands.length > 50
    return false if commands.any? do |command|
      !command.is_a?(Hash) || !nonempty_text?(command["action"]) || command["action"].length > 32 ||
        !command["value"].is_a?(String) || command["value"].length > 64 || !nonempty_text?(command["move_id"])
    end

    game = records_for(table_id).reverse.find do |record|
      record.packet["kind"].to_s == "game_started" &&
        record.packet.dig("data", "session_id").to_i == session_id
    end
    return false if game == nil

    players = game.packet.dig("data", "players").to_a.map(&:to_s)
    if GameRoomParticipants.bot?(actor)
      same_user?(sender, owner) && players.any? { |player| same_user?(player, actor) }
    else
      same_user?(sender, actor) && players.any? { |player| same_user?(player, actor) }
    end
  end

  def nonempty_text?(value)
    value.is_a?(String) && !value.empty?
  end

  def positive_integer?(value)
    value.is_a?(Integer) && value.positive?
  end

  def integer_between?(value, minimum, maximum)
    value.is_a?(Integer) && value.between?(minimum, maximum)
  end

  def json_object_text?(value)
    value.is_a?(String) && JSON.parse(value).is_a?(Hash)
  rescue JSON::ParserError
    false
  end

  def room_fields_valid?(data)
    return false if data.key?("status") && !%w[waiting playing closed].include?(data["status"])
    return false if data.key?("bot_count") && !integer_between?(data["bot_count"], 0, MAX_CAPACITY)
    return false if data.key?("game_options") && !json_object_text?(data["game_options"])

    %w[created_at updated_at].all? { |key| !data.key?(key) || positive_integer?(data[key]) }
  end

  def owner_for(table_id)
    session = active_session(table_id)
    session_owner = session&.respond_to?(:owner) ? session.owner&.user.to_s : ""
    return session_owner if !session_owner.empty?

    session&.metadata.to_h["owner"].to_s
  end

  def active_session(table_id)
    @mutex.synchronize do
      session = @sessions[table_id]
      if session != nil && session.respond_to?(:closed?) && session.closed?
        @sessions.delete(table_id)
        session = nil
      end
      session
    end
  end

  def active_table_ids
    @mutex.synchronize { @sessions.keys.dup }
  end

  def supported_metadata?(metadata)
    metadata.is_a?(Hash) &&
      metadata["kind"].to_s == KIND &&
      metadata["protocol"].to_i == PROTOCOL &&
      positive_identifier(metadata["table_id"]) != nil
  end

  def participant_metadata(table_id)
    { "table_id" => table_id.to_i, "client" => "elten_game_room" }
  end

  def table_identifier(value)
    raw = if value.is_a?(Hash)
      value["__id"] || value["id"] || value["table_id"]
    else
      value
    end
    positive_identifier(raw)
  end

  def positive_identifier(value)
    number = Integer(value.to_s, 10)
    number if number.positive?
  rescue ArgumentError, TypeError
    nil
  end

  def unused_identifier
    loop do
      id = SecureRandom.random_number(2_000_000_000) + 1
      return id if !active_table_ids.include?(id)
    end
  end

  def unused_game_identifier(table_id)
    used = game_sessions(table_id).map { |row| row["__id"].to_i }
    loop do
      id = SecureRandom.random_number(2_000_000_000) + 1
      return id if !used.include?(id)
    end
  end

  def bounded_capacity(value)
    [[value.to_i, 2].max, MAX_CAPACITY].min
  end

  def normalize_time(value)
    return value.to_i if value.respond_to?(:to_i) && value.to_i.positive?

    Time.now.to_i
  end

  def unique_users(users)
    users.to_a.each_with_object([]) do |user, result|
      value = user.to_s
      next if value.empty? || result.any? { |candidate| same_user?(candidate, value) }

      result << value
    end
  end

  def same_user?(first, second)
    !first.to_s.empty? && first.to_s.casecmp(second.to_s) == 0
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rescue Exception
    Time.now.to_f
  end

  def log_warning(stage, table_id, error)
    return if !defined?(Log)

    suffix = table_id == nil ? "" : " for table #{table_id}"
    Log.warning("ELTEN Game Room LiveSessions #{stage} failed#{suffix}: #{error.class}: #{error.message}")
  end
end
