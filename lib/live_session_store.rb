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
  MASTER_TRANSFER_TIMEOUT = 20.0

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
    @departed_participants = Hash.new { |hash, key| hash[key] = {} }
    @records = Hash.new { |hash, key| hash[key] = [] }
    @record_keys = Hash.new { |hash, key| hash[key] = {} }
    @stack_cursors = Hash.new(0)
    @discovered = {}
    @pending_invitations = {}
    @resolved_invitations = {}
    @superseded_sessions = Hash.new { |hash, key| hash[key] = [] }
    @migration_failures = {}
    @handled_migrations = {}
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
    attach_session(table_id, session)
    snapshot = room_snapshot(table_id)
    return :closed if snapshot == nil

    if snapshot[:members].length + snapshot[:bots].length > snapshot[:table]["max_players"].to_i
      deactivate_room(table_id)
      return :full
    end
    :joined
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

  def transfer_master(table_or_id, new_owner:, actor:)
    table_id = table_identifier(table_or_id)
    raise ArgumentError, "Invalid room" if table_id == nil
    current = table_for(table_id)
    candidate = new_owner.to_s
    raise ArgumentError, "Only the table owner may transfer it" if current == nil || !same_user?(current["owner"], actor)
    raise ArgumentError, "Select another user" if candidate.empty? || same_user?(candidate, actor)
    raise ArgumentError, "A computer cannot be the table master" if GameRoomParticipants.bot?(candidate)
    raise ArgumentError, "This user is no longer at the table" if !connected_users(table_id).any? { |user| same_user?(user, candidate) }

    source = active_session(table_id)
    raise ArgumentError, "The room is no longer active" if source == nil || !source.owner?

    migration_id = SecureRandom.uuid
    @mutex.synchronize { @migration_failures.delete(migration_id) }
    append_record(table_id, "room_transfer_requested", {
      "migration_id" => migration_id,
      "new_owner" => candidate,
      "source_session_id" => source.id.to_s,
      "members" => connected_users(table_id),
      "requested_at" => Time.now.to_i
    }, actor: actor)

    deadline = monotonic + MASTER_TRANSFER_TIMEOUT
    loop do
      migrated = active_session(table_id)
      metadata = migrated&.metadata.to_h
      if migrated != nil && migrated.id.to_s != source.id.to_s &&
          same_user?(metadata["owner"], candidate) && metadata["migration_id"].to_s == migration_id &&
          migration_ready?(table_id, migration_id)
        release_superseded_session(table_id, source)
        return table_for(table_id)
      end
      failure = @mutex.synchronize { @migration_failures[migration_id] }
      raise RuntimeError, failure if !failure.to_s.empty?
      raise RuntimeError, "The new table master did not confirm the transfer" if monotonic >= deadline

      ensure_current(table_id, force: true) if active_session(table_id).equal?(source)
      sleep 0.05
    end
  end

  def leave_room(table_or_id, user:)
    table_id = table_identifier(table_or_id)
    return false if table_id == nil

    session = active_session(table_id)
    return false if session == nil

    detach_session(table_id, session)
    session.owner? ? session.close : session.leave
    true
  end

  def close_room(table_or_id, actor:)
    table_id = table_identifier(table_or_id)
    return false if table_id == nil || active_session(table_id) == nil

    append_record(table_id, "room_closed", { "closed_at" => Time.now.to_i }, actor: actor)
    close_native_session_if_owner(table_id)
    true
  end

  def cancel_game(session:, actor:, departed: nil)
    table_id = positive_identifier(session["table_id"])
    session_id = positive_identifier(session["__id"] || session["id"])
    raise ArgumentError, "Invalid game" if table_id == nil || session_id == nil

    record = append_record(table_id, "game_cancelled", {
      "session_id" => session_id,
      "departed" => departed.to_s,
      "cancelled_at" => Time.now.to_i
    }, actor: actor)
    record != nil
  end

  def game_cancelled?(session)
    table_id = positive_identifier(session.to_h["table_id"])
    session_id = positive_identifier(session.to_h["__id"] || session.to_h["id"])
    return false if table_id == nil || session_id == nil

    ensure_current(table_id)
    cancelled_game_ids(table_id).key?(session_id)
  end

  def deactivate_room(table_or_id)
    table_id = table_identifier(table_or_id)
    return false if table_id == nil

    session = @mutex.synchronize do
      @native_session_ids.delete_if { |_native_id, id| id == table_id }
      removed = @sessions.delete(table_id)
      @departed_participants.delete(native_session_key(removed)) if removed != nil
      removed
    end
    return false if session == nil

    session.owner? ? session.close : session.leave
    true
  end

  def connected_users(table_or_id)
    table_id = table_identifier(table_or_id)
    session = table_id == nil ? nil : active_session(table_id)
    return [] if session == nil

    departed = departed_participants_for(session)
    unique_users(
      session.participants.to_a.filter_map do |participant|
        next if departed.key?(participant_identifier(participant))

        participant.user.to_s
      end
    )
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
    payload = {
      "session_id" => game_session_id,
      "game" => game.to_s,
      "players" => players.to_a.map(&:to_s),
      "options" => options.to_s,
      "created_at" => Time.now.to_i
    }
    record = append_record(table_id, "game_started", payload, actor: actor)
    game_session_from(record)
  end

  def game_sessions(table_or_id = nil)
    table_id = table_or_id == nil ? nil : table_identifier(table_or_id)
    ids = table_id == nil ? active_table_ids : [table_id]
    ids.compact.flat_map do |id|
      ensure_current(id)
      cancelled = cancelled_game_ids(id)
      records_for(id).filter_map do |record|
        next if record.packet["kind"].to_s != "game_started"

        row = game_session_from(record)
        row["status"] = "cancelled" if row != nil && cancelled.key?(row["__id"].to_i)
        row
      end
    end.sort_by { |row| row["__id"].to_i }
  end

  def game_session(session_id, table: nil)
    wanted = positive_identifier(session_id)
    return nil if wanted == nil

    game_sessions(table).find { |row| row["__id"].to_i == wanted }
  end

  def append_game_action(session:, sequence:, events:, actor:, authority: nil)
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
    data = {
      "session_id" => session_id,
      "sequence" => sequence.to_i,
      "events" => commands
    }
    data["authority"] = authority.to_s if !authority.to_s.empty?
    record = append_record(table_id, "game_action", data, actor: actor)
    expand_game_action(record)
  end

  def game_events(session)
    table_id = positive_identifier(session["table_id"])
    session_id = positive_identifier(session["__id"] || session["id"])
    return [] if table_id == nil || session_id == nil

    ensure_current(table_id)
    records_for(table_id).flat_map do |record|
      next [] if record.packet["kind"].to_s != "game_action"
      next [] if record.packet.dig("data", "session_id").to_i != session_id

      expand_game_action(record)
    end.sort_by { |row| row["__id"].to_i }
  end

  def invite_user(table_id:, user:, metadata:)
    session = active_session(table_identifier(table_id))
    return false if session == nil || !session.owner?

    session.invite(user.to_s, metadata: metadata.to_h.merge("purpose" => "game_invitation"))
    true
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
    attach_session(stored[:table_id], session)
    resolve_invitation(stored[:id])
    true
  rescue StandardError
    restore_invitation(stored) if stored
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

    if existing != nil
      @mutex.synchronize { @superseded_sessions[table_id] << existing if !@superseded_sessions[table_id].include?(existing) }
      reset_record_cache(table_id)
    end

    if session.respond_to?(:on_stack_message)
      session.on_stack_message(with_metadata: true) do |sender, packet, info|
        receive_session_record(
          table_id,
          session,
          sequence: info.sequence,
          message_id: info.id,
          sender: sender.user,
          packet: packet,
          created_at: info.created_at
        )
      end
      session.on_stack_gap do |_gap|
        ensure_current(table_id, force: true)
        emit_change(table_id, :recovery, nil)
      end
    end
    if session.respond_to?(:on_participant_joined)
      session.on_participant_joined do |participant|
        remember_participant_joined(session, participant)
        emit_session_change(table_id, session, :table)
      end
    end
    if session.respond_to?(:on_participant_left)
      session.on_participant_left do |participant, _reason = nil|
        remember_participant_left(session, participant)
        emit_session_change(table_id, session, :table)
      end
    end
    if session.respond_to?(:on_closed)
      session.on_closed do |_reason|
        active_closed = @mutex.synchronize do
          current = @sessions[table_id].equal?(session)
          @sessions.delete(table_id) if @sessions[table_id].equal?(session)
          @native_session_ids.delete(session.id.to_s) if session.respond_to?(:id)
          @departed_participants.delete(native_session_key(session))
          @superseded_sessions[table_id].delete(session)
          current
        end
        emit_change(table_id, :closed, nil) if active_closed
      end
    end
    @mutex.synchronize do
      @sessions[table_id] = session
      @native_session_ids[session.id.to_s] = table_id if session.respond_to?(:id)
    end
    ensure_current(table_id, force: true) if session.respond_to?(:stack_read)
    session
  end

  def detach_session(table_id, session)
    @mutex.synchronize do
      @sessions.delete(table_id) if @sessions[table_id].equal?(session)
      @native_session_ids.delete(session.id.to_s) if session.respond_to?(:id)
      @departed_participants.delete(native_session_key(session))
    end
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
        receive_session_record(
          table_id,
          session,
          sequence: entry["seq"],
          message_id: entry["message_id"],
          sender: sender,
          packet: entry["packet"],
          created_at: entry["created_at"]
        )
      end
      next_cursor = page["cursor"].to_i
      @mutex.synchronize { @stack_cursors[table_id] = [@stack_cursors[table_id].to_i, next_cursor].max }
      break if next_cursor <= cursor || page["has_more"] != true

      cursor = next_cursor
    end
    true
  rescue StandardError => error
    log_warning("stack read", table_id, error)
    raise if force

    false
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
    process_migration_record(table_id, session, record) if record != nil
    record || records_for(table_id).find { |entry| entry.message_id == message_id }
  end

  def receive_session_record(table_id, session, sequence:, message_id:, sender:, packet:, created_at:)
    active = active_session(table_id)
    if !active.equal?(session)
      process_stale_migration_record(table_id, session, sender, packet)
      return nil
    end

    record = ingest_record(
      table_id,
      sequence: sequence,
      message_id: message_id,
      sender: sender,
      packet: packet,
      created_at: created_at
    )
    process_migration_record(table_id, session, record) if record != nil
    record
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
    return nil if packet["version"].to_i != PROTOCOL
    return nil if !valid_record?(table_id, sender, packet)

    sender, packet, created_at = imported_record_values(sender, packet, created_at)

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
      @stack_cursors[table_id] = [@stack_cursors[table_id].to_i, seq].max
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
    when "game_action", "game_cancelled"
      emit_change(table_id, :game, data["session_id"].to_i)
    else
      emit_change(table_id, :table, nil)
    end
    close_native_session_if_owner(table_id) if kind == "room_closed"
  end

  def process_migration_record(table_id, session, record)
    return if record == nil

    data = record.packet["data"].to_h
    case record.packet["kind"].to_s
    when "room_transfer_requested"
      return if !same_user?(data["new_owner"], endpoint.user)

      migration_id = data["migration_id"].to_s
      start = @mutex.synchronize do
        next false if @handled_migrations.key?(migration_id)

        @handled_migrations[migration_id] = true
        true
      end
      migrate_table_as_new_owner(table_id, session, record) if start
    when "room_migration"
      return if migration_failed?(data["migration_id"])

      switch_to_migrated_session(table_id, session, data)
    when "room_migration_failed"
      remember_migration_failure(data)
      restore_superseded_session(table_id, data["source_session_id"])
    end
  rescue StandardError => error
    log_warning("master transfer", table_id, error)
  end

  def process_stale_migration_record(table_id, session, sender, packet)
    return if !packet.is_a?(Hash) || packet["version"].to_i != PROTOCOL

    data = packet["data"].to_h
    migration_id = data["migration_id"].to_s
    active_metadata = active_session(table_id)&.metadata.to_h
    return if migration_id.empty? || active_metadata.to_h["migration_id"].to_s != migration_id
    return if !same_user?(sender, active_metadata["owner"])

    case packet["kind"].to_s
    when "room_migration_complete"
      release_superseded_session(table_id, session)
    when "room_migration_failed"
      remember_migration_failure(data)
      restore_superseded_session(table_id, data["source_session_id"])
    end
  rescue StandardError => error
    log_warning("old master session cleanup", table_id, error)
  end

  def migrate_table_as_new_owner(table_id, source_session, request)
    data = request.packet["data"].to_h
    migration_id = data["migration_id"].to_s
    candidate = data["new_owner"].to_s
    return if migration_id.empty? || !same_user?(candidate, endpoint.user)

    source_table = table_for(table_id)
    source_records = records_for(table_id)
    expected_users = unique_users(data["members"].to_a)
    expected_users << candidate if !expected_users.any? { |user| same_user?(user, candidate) }
    created_at = source_table["created_at"].to_i
    metadata = {
      "kind" => KIND,
      "protocol" => PROTOCOL,
      "table_id" => table_id,
      "owner" => candidate,
      "name" => source_table["name"].to_s,
      "game" => source_table["game"].to_s,
      "game_options" => source_table["game_options"].to_s,
      "created_at" => created_at,
      "migration_id" => migration_id,
      "migrated_from" => source_session.id.to_s
    }
    migrated = endpoint.create(
      metadata: metadata,
      participant_metadata: participant_metadata(table_id),
      capacity: bounded_capacity(source_table["max_players"]),
      visibility: :public,
      discovery_metadata: metadata.dup,
      stack_entry_bytes: STACK_ENTRY_BYTES,
      stack_entries: STACK_ENTRIES,
      pool_count: 1,
      private_messages: true
    )
    attach_session(table_id, migrated)
    source_records.each do |source_record|
      packet = importable_packet(source_record, new_owner: candidate)
      append_import_record(table_id, source_record, packet, migration_id) if packet != nil
    end

    push_control_record(source_session, "room_migration", {
      "migration_id" => migration_id,
      "new_owner" => candidate,
      "source_session_id" => source_session.id.to_s,
      "new_session_id" => migrated.id.to_s,
      "members" => expected_users
    }, actor: candidate)

    wait_for_migrated_members(migrated, expected_users, timeout: MASTER_TRANSFER_TIMEOUT)
    append_record(table_id, "room_migration_ready", {
      "migration_id" => migration_id,
      "source_session_id" => source_session.id.to_s,
      "new_session_id" => migrated.id.to_s
    }, actor: candidate)
    push_control_record(source_session, "room_migration_complete", {
      "migration_id" => migration_id,
      "source_session_id" => source_session.id.to_s,
      "new_session_id" => migrated.id.to_s
    }, actor: candidate)
    release_superseded_session(table_id, source_session)
  rescue StandardError => error
    begin
      push_control_record(source_session, "room_migration_failed", {
        "migration_id" => migration_id.to_s,
        "source_session_id" => source_session&.id.to_s,
        "reason" => error.message.to_s
      }, actor: candidate.to_s)
    rescue StandardError
      nil
    end
    restore_superseded_session(table_id, source_session&.id)
    raise
  end

  def switch_to_migrated_session(table_id, source_session, data)
    migration_id = data["migration_id"].to_s
    target_id = data["new_session_id"].to_s
    candidate = data["new_owner"].to_s
    return if migration_id.empty? || target_id.empty? || candidate.empty?
    return if active_session(table_id)&.id.to_s == target_id

    deadline = monotonic + MASTER_TRANSFER_TIMEOUT
    discovered = nil
    loop do
      discovered = discover_pages.find do |item|
        metadata = item.discovery_metadata.to_h
        item.id.to_s == target_id && supported_metadata?(metadata) &&
          metadata["table_id"].to_i == table_id && metadata["migration_id"].to_s == migration_id &&
          same_user?(metadata["owner"], candidate)
      end
      break if discovered != nil
      raise RuntimeError, "The replacement table session was not found" if monotonic >= deadline

      sleep 0.05
    end
    migrated = if same_user?(endpoint.user, candidate)
      endpoint.sessions.to_a.find { |item| item.id.to_s == target_id }
    else
      discovered.join(participant_metadata: participant_metadata(table_id))
    end
    raise RuntimeError, "The replacement table session could not be joined" if migrated == nil

    attach_session(table_id, migrated)
    @mutex.synchronize { @discovered[table_id] = discovered }
  rescue StandardError => error
    remember_migration_failure(
      "migration_id" => migration_id,
      "source_session_id" => source_session&.id.to_s,
      "reason" => error.message.to_s
    )
    raise
  end

  def importable_packet(record, new_owner:)
    kind = record.packet["kind"].to_s
    return nil if !%w[room_created room_state room_activity game_started game_action game_cancelled].include?(kind)

    packet = JSON.parse(JSON.generate(record.packet))
    if kind == "room_created"
      packet["actor"] = new_owner.to_s
      packet["data"]["owner"] = new_owner.to_s
    end
    packet
  end

  def append_import_record(table_id, source_record, packet, migration_id)
    wrapper = {
      "version" => PROTOCOL,
      "kind" => "room_import",
      "actor" => endpoint.user.to_s,
      "data" => {
        "migration_id" => migration_id.to_s,
        "source_sender" => packet["kind"].to_s == "room_created" ? endpoint.user.to_s : source_record.sender.to_s,
        "source_created_at" => source_record.created_at.to_i,
        "packet" => packet
      }
    }
    session = active_session(table_id)
    message_id = SecureRandom.uuid
    result = session.stack_push(wrapper, message_id: message_id)
    record = ingest_record(
      table_id,
      sequence: extract_push_sequence(result, session),
      message_id: message_id,
      sender: endpoint.user.to_s,
      packet: wrapper,
      created_at: Time.now.to_i
    )
    record
  end

  def imported_record_values(sender, packet, created_at)
    return [sender, packet, created_at] if packet["kind"].to_s != "room_import"

    data = packet["data"].to_h
    [data["source_sender"].to_s, data["packet"].to_h, data["source_created_at"]]
  end

  def push_control_record(session, kind, data, actor:)
    packet = {
      "version" => PROTOCOL,
      "kind" => kind.to_s,
      "actor" => actor.to_s,
      "data" => JSON.parse(JSON.generate(data))
    }
    session.stack_push(packet, message_id: SecureRandom.uuid)
  end

  def wait_for_migrated_members(session, users, timeout:)
    deadline = monotonic + timeout.to_f
    users.each do |user|
      next if session.participants.to_a.any? { |participant| same_user?(participant.user, user) }

      remaining = deadline - monotonic
      raise RuntimeError, "Not every player joined the replacement table session" if remaining <= 0
      if session.respond_to?(:wait_for_participant)
        session.wait_for_participant(user, timeout: remaining)
      else
        sleep 0.01 until session.participants.to_a.any? { |participant| same_user?(participant.user, user) } || monotonic >= deadline
      end
      raise RuntimeError, "Not every player joined the replacement table session" if !session.participants.to_a.any? { |participant| same_user?(participant.user, user) }
    end
    true
  end

  def migration_ready?(table_id, migration_id)
    records_for(table_id).any? do |record|
      record.packet["kind"].to_s == "room_migration_ready" &&
        record.packet.dig("data", "migration_id").to_s == migration_id.to_s
    end
  end

  def remember_migration_failure(data)
    migration_id = data.to_h["migration_id"].to_s
    return if migration_id.empty?

    reason = data.to_h["reason"].to_s
    reason = "The table master transfer failed" if reason.empty?
    @mutex.synchronize { @migration_failures[migration_id] = reason }
  end

  def migration_failed?(migration_id)
    key = migration_id.to_s
    !key.empty? && @mutex.synchronize { @migration_failures.key?(key) }
  end

  def release_superseded_session(table_id, session)
    @mutex.synchronize do
      @superseded_sessions[table_id].delete(session)
      @departed_participants.delete(native_session_key(session)) if session != nil
    end
    return if session == nil || session.closed?

    session.owner? ? session.close : session.leave
  end

  def restore_superseded_session(table_id, source_session_id)
    source = @mutex.synchronize do
      @superseded_sessions[table_id].find { |session| session.id.to_s == source_session_id.to_s }
    end
    return false if source == nil || source.closed?

    current = active_session(table_id)
    @mutex.synchronize do
      @sessions[table_id] = source
      @native_session_ids[source.id.to_s] = table_id
      @superseded_sessions[table_id].delete(source)
    end
    reset_record_cache(table_id)
    ensure_current(table_id, force: true)
    if current != nil && !current.equal?(source) && !current.closed?
      current.owner? ? current.close : current.leave
    end
    true
  end

  def reset_record_cache(table_id)
    @mutex.synchronize do
      @records.delete(table_id)
      @record_keys.delete(table_id)
      @stack_cursors.delete(table_id)
    end
  end

  def emit_change(table_id, kind, value)
    @changed&.call(table_id.to_i, kind.to_sym, value)
  rescue StandardError => error
    log_warning("change callback", table_id, error)
  end

  def emit_session_change(table_id, session, kind, value = nil)
    emit_change(table_id, kind, value) if active_session(table_id).equal?(session)
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
      when "game_cancelled"
        row["status"] = "waiting"
      when "room_closed"
        row["status"] = "closed"
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
        "__authority" => data["authority"].to_s,
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
    kind = packet["kind"].to_s
    actor = packet["actor"].to_s
    data = packet["data"]
    return false if sender.to_s.empty? || actor.empty? || !data.is_a?(Hash)

    owner = owner_for(table_id)
    case kind
    when "room_created"
      same_user?(sender, owner) && same_user?(actor, owner) && same_user?(data["owner"], owner)
    when "room_state"
      same_user?(sender, owner) && same_user?(actor, owner)
    when "room_closed"
      same_user?(sender, owner) && same_user?(actor, owner)
    when "room_activity"
      %w[created joined left bot_added bot_removed chat master_changed game_interrupted].include?(data["activity_kind"].to_s) &&
        same_user?(sender, actor)
    when "game_started"
      players = data["players"].to_a.map(&:to_s)
      same_user?(sender, owner) && same_user?(actor, owner) &&
        players.length.between?(1, MAX_CAPACITY) && same_user?(players.first, owner) &&
        players.none?(&:empty?) && unique_users(players).length == players.length
    when "game_action"
      valid_game_action_record?(table_id, sender, actor, data, owner)
    when "game_cancelled"
      valid_game_cancellation_record?(table_id, sender, actor, data, owner)
    when "room_transfer_requested"
      candidate = data["new_owner"].to_s
      migration_id = data["migration_id"].to_s
      same_user?(sender, owner) && same_user?(actor, owner) && !migration_id.empty? &&
        GameRoomParticipants.human?(candidate) && !same_user?(candidate, owner) &&
        connected_users(table_id).any? { |user| same_user?(user, candidate) }
    when "room_migration", "room_migration_complete", "room_migration_failed"
      valid_migration_control_record?(table_id, sender, actor, data)
    when "room_migration_ready"
      same_user?(sender, owner) && same_user?(actor, owner) &&
        data["migration_id"].to_s == active_session(table_id)&.metadata.to_h["migration_id"].to_s
    when "room_import"
      valid_import_record?(table_id, sender, actor, data, owner)
    else
      false
    end
  end

  def valid_game_cancellation_record?(table_id, sender, actor, data, owner)
    session_id = positive_identifier(data["session_id"])
    return false if session_id == nil || !same_user?(sender, actor)

    game = records_for(table_id).reverse.find do |record|
      record.packet["kind"].to_s == "game_started" &&
        record.packet.dig("data", "session_id").to_i == session_id
    end
    return false if game == nil || cancelled_game_ids(table_id).key?(session_id)

    players = game.packet.dig("data", "players").to_a.map(&:to_s)
    same_user?(actor, owner) || players.any? { |player| same_user?(player, actor) }
  end

  def valid_game_action_record?(table_id, sender, actor, data, owner)
    session_id = positive_identifier(data["session_id"])
    commands = data["events"].to_a
    return false if session_id == nil || commands.empty? || commands.length > 50
    return false if commands.any? do |command|
      !command.is_a?(Hash) || command["action"].to_s.empty? || command["action"].to_s.length > 32 ||
        command["value"].to_s.length > 64 || command["move_id"].to_s.empty?
    end

    game = records_for(table_id).reverse.find do |record|
      record.packet["kind"].to_s == "game_started" &&
        record.packet.dig("data", "session_id").to_i == session_id
    end
    return false if game == nil

    players = game.packet.dig("data", "players").to_a.map(&:to_s)
    authority = data["authority"].to_s
    return false if !authority.empty? && authority != "table_master"
    if authority == "table_master"
      same_user?(sender, owner) && same_user?(actor, owner)
    elsif GameRoomParticipants.bot?(actor)
      same_user?(sender, owner) && players.any? { |player| same_user?(player, actor) }
    else
      same_user?(sender, actor) && players.any? { |player| same_user?(player, actor) }
    end
  end

  def valid_migration_control_record?(table_id, sender, actor, data)
    migration_id = data["migration_id"].to_s
    return false if migration_id.empty? || !same_user?(sender, actor)

    request = records_for(table_id).reverse.find do |record|
      record.packet["kind"].to_s == "room_transfer_requested" &&
        record.packet.dig("data", "migration_id").to_s == migration_id
    end
    request != nil && same_user?(actor, request.packet.dig("data", "new_owner")) &&
      data["source_session_id"].to_s == request.packet.dig("data", "source_session_id").to_s
  end

  def valid_import_record?(table_id, sender, actor, data, owner)
    metadata = active_session(table_id)&.metadata.to_h
    inner = data["packet"]
    same_user?(sender, owner) && same_user?(actor, owner) &&
      !metadata.to_h["migration_id"].to_s.empty? &&
      data["migration_id"].to_s == metadata["migration_id"].to_s &&
      inner.is_a?(Hash) && inner["version"].to_i == PROTOCOL &&
      %w[room_created room_state room_activity game_started game_action game_cancelled].include?(inner["kind"].to_s)
  end

  def owner_for(table_id)
    session = active_session(table_id)
    session_owner = session&.respond_to?(:owner) ? session.owner&.user.to_s : ""
    return session_owner if !session_owner.empty?

    session&.metadata.to_h["owner"].to_s
  end

  def cancelled_game_ids(table_id)
    records_for(table_id).each_with_object({}) do |record, result|
      next if record.packet["kind"].to_s != "game_cancelled"

      id = positive_identifier(record.packet.dig("data", "session_id"))
      result[id] = true if id != nil
    end
  end

  def close_native_session_if_owner(table_id)
    session = active_session(table_id)
    return false if session == nil || !session.owner?

    detach_session(table_id, session)
    session.close
    true
  rescue StandardError => error
    log_warning("room close", table_id, error)
    false
  end

  def active_session(table_id)
    @mutex.synchronize do
      session = @sessions[table_id]
      if session != nil && session.respond_to?(:closed?) && session.closed?
        @sessions.delete(table_id)
        @departed_participants.delete(native_session_key(session))
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

  def native_session_key(session)
    return "" if session == nil

    session.respond_to?(:id) ? session.id.to_s : session.object_id.to_s
  end

  def participant_identifier(participant)
    return "" if participant == nil

    id = participant.respond_to?(:id) ? participant.id.to_s : ""
    return "id:#{id}" if !id.empty?

    user = participant.respond_to?(:user) ? participant.user.to_s.downcase : ""
    user.empty? ? "" : "user:#{user}"
  end

  def departed_participants_for(session)
    @mutex.synchronize { @departed_participants[native_session_key(session)].dup }
  end

  def remember_participant_left(session, participant)
    identifier = participant_identifier(participant)
    return if identifier.empty?

    @mutex.synchronize { @departed_participants[native_session_key(session)][identifier] = true }
  end

  def remember_participant_joined(session, participant)
    identifier = participant_identifier(participant)
    return if identifier.empty?

    @mutex.synchronize { @departed_participants[native_session_key(session)].delete(identifier) }
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
