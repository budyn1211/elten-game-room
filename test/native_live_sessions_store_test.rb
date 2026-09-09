require "securerandom"

def _(text)
  text
end

def assert(value, message)
  raise message unless value
end

module Session
  def self.name
    (Thread.current[:game_room_test_user] || $game_room_test_user).to_s
  end
end

require_relative "../lib/game_room_transport"
require_relative "../lib/lobby_repository"
require_relative "../lib/game_repository"
require_relative "../lib/table_activity_repository"
require_relative "../lib/invitation_repository"
require_relative "../games/base"

class NativeLiveSessionsBroker
  Participant = Struct.new(:id, :user, keyword_init: true)
  Info = Struct.new(:sequence, :id, :created_at, keyword_init: true)

  Core = Struct.new(
    :id, :metadata, :discovery_metadata, :capacity, :owner, :participants,
    :entries, :views, :closed,
    keyword_init: true
  )

  Page = Struct.new(:items, :next_cursor, keyword_init: true) do
    def to_a
      items
    end
  end

  attr_reader :cores

  def initialize
    @cores = {}
    @endpoints = {}
  end

  def endpoint(user)
    @endpoints[user] ||= Endpoint.new(self, user)
  end

  class Endpoint
    attr_reader :user

    def initialize(broker, user)
      @broker = broker
      @user = user
      @sessions = []
      @invitations = []
      @invitation_callbacks = []
    end

    def create(metadata:, participant_metadata:, capacity:, visibility:, discovery_metadata:, **_options)
      id = SecureRandom.uuid
      core = Core.new(
        id: id,
        metadata: metadata,
        discovery_metadata: discovery_metadata,
        capacity: capacity,
        owner: @user,
        participants: {},
        entries: [],
        views: [],
        closed: false
      )
      @broker.cores[id] = core
      add_view(core)
    end

    def discover_sessions(**_options)
      items = @broker.cores.values.reject(&:closed).map { |core| Discovery.new(self, core) }
      Page.new(items: items, next_cursor: nil)
    end

    def sessions
      @sessions.reject(&:closed?)
    end

    def on_invitation(&block)
      @invitation_callbacks << block
    end

    def next_invitation(timeout: nil)
      @invitations.shift
    end

    def deliver_invitation(invitation)
      @invitations << invitation
      @invitation_callbacks.each { |callback| callback.call(invitation) }
    end

    def add_view(core)
      view = View.new(self, core)
      @sessions << view
      core.views << view
      participant = Participant.new(id: SecureRandom.uuid, user: @user)
      core.participants[@user.downcase] = participant
      core.views.each { |candidate| candidate.participant_joined(participant) unless candidate.equal?(view) }
      view
    end

    def broker
      @broker
    end
  end

  class Discovery
    attr_reader :id, :discovery_metadata, :capacity, :participant_count, :join_reason

    def initialize(endpoint, core)
      @endpoint = endpoint
      @core = core
      @id = core.id
      @discovery_metadata = core.discovery_metadata
      @capacity = core.capacity
      @participant_count = core.participants.length
      @join_reason = @participant_count >= @capacity ? :full : nil
    end

    def can_join?
      @join_reason == nil
    end

    def join(participant_metadata: {})
      raise "full" if !can_join?

      @endpoint.add_view(@core)
    end
  end

  class Invitation
    attr_reader :metadata, :invitation_metadata, :inviter, :expires_at

    def initialize(target, core, inviter, metadata)
      @target = target
      @core = core
      @metadata = core.metadata
      @invitation_metadata = metadata
      @inviter = Participant.new(id: "inviter", user: inviter)
      @expires_at = Time.now.to_i + 600
      @pending = true
    end

    def pending?
      @pending
    end

    def accept(participant_metadata: {})
      @pending = false
      @target.add_view(@core)
    end

    def reject
      @pending = false
      true
    end
  end

  class View
    attr_reader :id, :metadata, :capacity

    def initialize(endpoint, core)
      @endpoint = endpoint
      @core = core
      @id = core.id
      @metadata = core.metadata
      @capacity = core.capacity
      @stack_callbacks = []
      @join_callbacks = []
      @left_callbacks = []
      @closed_callbacks = []
      @closed = false
    end

    def participants
      @core.participants.values
    end

    def participant(id)
      participants.find { |participant| participant.id.to_s == id.to_s }
    end

    def owner
      participants.find { |participant| participant.user.casecmp(@core.owner) == 0 }
    end

    def owner?
      @endpoint.user.casecmp(@core.owner) == 0
    end

    def closed?
      @closed || @core.closed
    end

    def stack_state
      { "last_seq" => @core.entries.length, "count" => @core.entries.length }
    end

    def stack_push(packet, message_id:)
      sequence = @core.entries.length + 1
      created_at = Time.now.to_i
      entry = {
        "seq" => sequence,
        "message_id" => message_id,
        "sender" => { "user" => @endpoint.user },
        "sender_id" => @core.participants.fetch(@endpoint.user.downcase).id,
        "packet" => packet,
        "created_at" => created_at
      }
      @core.entries << entry
      sender = @core.participants.fetch(@endpoint.user.downcase)
      info = Info.new(sequence: sequence, id: message_id, created_at: created_at)
      @core.views.each { |view| view.stack_message(sender, packet, info) }
      { "entry" => { "seq" => sequence }, "stack" => stack_state }
    end

    def stack_read(after:, limit:)
      entries = @core.entries.select { |entry| entry["seq"] > after.to_i }.first(limit)
      cursor = entries.empty? ? after.to_i : entries.last["seq"]
      { "entries" => entries, "cursor" => cursor, "has_more" => @core.entries.any? { |entry| entry["seq"] > cursor } }
    end

    def on_stack_message(with_metadata: false, &block)
      @stack_callbacks << block
    end

    def on_stack_gap(&block); end
    def on_participant_joined(&block); @join_callbacks << block; end
    def on_participant_left(&block); @left_callbacks << block; end
    def on_closed(&block); @closed_callbacks << block; end

    def stack_message(sender, packet, info)
      @stack_callbacks.each { |callback| callback.call(sender, packet, info) }
    end

    def participant_joined(participant)
      @join_callbacks.each { |callback| callback.call(participant) }
    end

    def invite(user, metadata: {})
      target = @endpoint.broker.endpoint(user)
      invitation = Invitation.new(target, @core, @endpoint.user, metadata)
      target.deliver_invitation(invitation)
      true
    end

    def leave
      participant = @core.participants.delete(@endpoint.user.downcase)
      @closed = true
      @core.views.each { |view| view.participant_left(participant) unless view.equal?(self) }
      true
    end

    def participant_left(participant)
      @left_callbacks.each { |callback| callback.call(participant, :left) }
    end

    def close
      @core.closed = true
      @core.views.each do |view|
        view.instance_variable_set(:@closed, true)
        view.instance_variable_get(:@closed_callbacks).each { |callback| callback.call(:closed) }
      end
      true
    end
  end
end

module EltenLink
  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code)
    end
  end

  module Apps
    def self.table(client, _uuid, name)
      assert(%w[game_room_users table_activity].include?(name), "Room or game state requested a legacy table")
      client
    end
  end
end

ProgramDouble = Struct.new(:live_sessions)

class ActivityTableDouble
  attr_reader :calls

  def initialize(denied: false)
    @rows = []
    @calls = []
    @denied = denied
  end

  def record_request(operation)
    @calls << operation
    raise EltenLink::Error.new("apps.tables.stamp_required") if @denied
  end

  def insert(values)
    record_request(:insert)
    row = values.merge("__id" => @rows.length + 1, "__insertion_user" => values["actor"])
    @rows << row
    row
  end

  def select(where: nil, order: nil, limit: nil, **_options)
    record_request(:select)
    rows = @rows.dup
    rows = rows.select { |row| where.all? { |key, value| row[key] == value } } if where
    rows.last(limit || rows.length)
  end
end

[false, true].each do |denied|
  broker = NativeLiveSessionsBroker.new
  users = %w[Alice Bob Carol Dave]
  transports = users.to_h do |user|
    [user, GameRoomTransport.new(ProgramDouble.new(broker.endpoint(user)))]
  end
  activity_table = ActivityTableDouble.new(denied: denied)
  server_program = Struct.new(:server_app_uuid).new("server-uuid")
  server_tables = users.to_h do |user|
    provider = GameRoomServerTables.new(server_program, client: activity_table)
    assert(provider.check_access(username: user) == !denied, "Table access detection disagreed with the server")
    [user, provider]
  end
  activities = users.to_h do |user|
    [user, TableActivityRepository.new(server_tables: server_tables.fetch(user), transport: transports.fetch(user))]
  end
  lobbies = users.to_h do |user|
    [user, LobbyRepository.new(ProgramDouble.new(broker.endpoint(user)), transport: transports.fetch(user), server_tables: server_tables.fetch(user), activity_repository: activities.fetch(user))]
  end
  games = users.to_h do |user|
    [user, GameRepository.new(ProgramDouble.new(broker.endpoint(user)), transport: transports.fetch(user), server_tables: server_tables.fetch(user))]
  end

  users.each { |user| transports.fetch(user).start }
  $game_room_test_user = "Alice"
  created = lobbies.fetch("Alice").create_table(name: "Alice's table", game: "four_in_a_row", owner: "Alice", game_options: "{}")
  assert(created.created?, "native room was not created")
  table = created.table

  $game_room_test_user = "Bob"
  bob_public = lobbies.fetch("Bob").open_tables.first
  assert(bob_public && bob_public["__id"] == table["__id"], "public LiveSession was not discovered")
  assert(transports.fetch("Bob").establish_membership(table_id: table["__id"], owner: "Alice", capacity: 8, user: "Bob", table: bob_public), "Bob could not join")
  bob_join = lobbies.fetch("Bob").join_table(bob_public, "Bob")
  assert(bob_join.status == :joined, "new native membership was not reported as joined")

  $game_room_test_user = "Alice"
  alice_snapshot = lobbies.fetch("Alice").snapshot_for(table)
  assert(alice_snapshot.members.sort == %w[Alice Bob], "room membership did not synchronize")
  stale_core = broker.cores.values.first
  stale_alice_view = stale_core.views.find do |view|
    view.instance_variable_get(:@endpoint).user == "Alice"
  end
  stale_bob = stale_core.participants.fetch("bob")
  stale_alice_view.participant_left(stale_bob)
  assert(
    lobbies.fetch("Alice").snapshot_for(table).members == ["Alice"],
    "a participant left behind by ELTEN remained visible in the room"
  )
  stale_alice_view.participant_joined(stale_bob)
  assert(
    lobbies.fetch("Alice").snapshot_for(table).members.sort == %w[Alice Bob],
    "a participant rejoining with the same identity remained filtered"
  )
  bot_result = lobbies.fetch("Alice").add_bot(table, snapshot: alice_snapshot)
  assert(bot_result.updated? && bot_result.snapshot.participants.length == 3, "bot room state did not synchronize")

  invitations = users.to_h { |user| [user, InvitationRepository.new(transport: transports.fetch(user))] }
  sent = invitations.fetch("Alice").create(table: table, sender: "Alice", recipient: "Carol")
  transports.fetch("Alice").invite_user(
    table_id: table["__id"],
    user: "Carol",
    metadata: { "purpose" => "game_invitation", "invitation_id" => sent.invitation["__id"] }
  )
  $game_room_test_user = "Carol"
  pending = invitations.fetch("Carol").pending_for("Carol", tables: lobbies.fetch("Carol").open_tables)
  assert(pending.length == 1, "native invitation was not exposed")
  assert(transports.fetch("Carol").establish_membership(table_id: table["__id"], owner: "Alice", capacity: 8, user: "Carol", invitation_id: pending.first.id, table: pending.first.table), "native invitation was not accepted")
  carol_join = lobbies.fetch("Carol").join_table(pending.first.table, "Carol")
  assert(carol_join.status == :joined, "accepted invitation was not recorded as a join")

  $game_room_test_user = "Dave"
  dave_public = lobbies.fetch("Dave").open_tables.first
  assert(transports.fetch("Dave").establish_membership(table_id: table["__id"], owner: "Alice", capacity: 8, user: "Dave", table: dave_public), "Dave could not join")
  assert(lobbies.fetch("Dave").join_table(dave_public, "Dave").status == :joined, "fourth client was not recorded")

  $game_room_test_user = "Alice"
  # The UI refactor must retain the existing count-only protocol for every
  # participant, including clients using the original room implementation.
  owner_lobby = lobbies.fetch("Alice")
  2.times { assert(owner_lobby.add_bot(table, snapshot: owner_lobby.snapshot_for(table)).updated?, "could not add a test computer") }
  removed = owner_lobby.remove_bot(table, snapshot: owner_lobby.snapshot_for(table))
  assert(removed.updated?, "count-only computer removal failed")
  users.each do |user|
    snapshot = lobbies.fetch(user).snapshot_for(table)
    assert(snapshot.table["bot_count"] == 2, "#{user} did not receive the smaller bot count")
    assert(snapshot.bots == ["bot:#{table['__id']}:1", "bot:#{table['__id']}:2"], "#{user} lost contiguous computer numbering")
  end
  added = owner_lobby.add_bot(table, snapshot: owner_lobby.snapshot_for(table))
  assert(GameRoomParticipants.bot_number(added.snapshot.bots.last) == 3, "adding after removal changed the existing numbering convention")
  core = broker.cores.values.first
  assert(core.metadata["protocol"] == 2, "UI refactor changed the discovery protocol")
  packets = core.entries.map { |entry| entry.fetch("packet") }
  assert(packets.all? { |packet| packet["version"] == 2 }, "UI refactor changed the stack protocol")
  bot_updates = packets.select { |packet| packet["kind"] == "room_state" && packet["data"].key?("bot_count") }
  assert(bot_updates.all? { |packet| packet["data"].keys.sort == %w[bot_count updated_at] }, "computer management introduced incompatible room fields")

  players = lobbies.fetch("Alice").snapshot_for(table).participants
  session = games.fetch("Alice").start_session(table: table, game: "four_in_a_row", players: players, options: "{}")
  events = [GameRoomGames::EventCommand.new(action: "drop", value: "1")]
  saved = games.fetch("Alice").append_events(session: session, sequence: 1, events: events, actor: "Alice")
  assert(saved.length == 1, "atomic stack action was not stored")

  threads = %w[Bob Carol].map do |user|
    Thread.new do
      Thread.current[:game_room_test_user] = user
      remote_session = games.fetch(user).session_for_table(lobbies.fetch(user).current_table_for(user))
      games.fetch(user).append_events(
        session: remote_session,
        sequence: 2,
        events: [GameRoomGames::EventCommand.new(action: "simultaneous", value: user)],
        actor: user
      )
    end
  end
  threads.each(&:join)

  $game_room_test_user = "Bob"
  bob_session = games.fetch("Bob").session_for_table(bob_public)
  bob_snapshot = games.fetch("Bob").snapshot_for(bob_session)
  assert(bob_snapshot.events.map { |event| event["action"] } == ["drop", "simultaneous", "simultaneous"], "game stack did not preserve concurrent actions")
  assert(bob_snapshot.events.last(2).map { |event| event["actor"] }.sort == %w[Bob Carol], "one concurrent client action was lost")

  $game_room_test_user = "Dave"
  dave_session = games.fetch("Dave").session_for_table(dave_public)
  assert(games.fetch("Dave").snapshot_for(dave_session).events.map { |event| event["__id"] } == bob_snapshot.events.map { |event| event["__id"] }, "four clients did not converge on one stack order")

  chat = activities.fetch("Bob").append(table: bob_public, kind: "chat", message: "Hello", actor: "Bob")
  assert(chat && activities.fetch("Alice").entries_for(table).any? { |entry| entry.kind == "chat" && entry.message == "Hello" }, "chat did not use the shared room stack")

  history_item = Struct.new(:text, :event_id).new("Alice played.", bob_snapshot.events.first["__id"])
  merged_history = activities.fetch("Alice").merged_history_entries(
    game_entries: [history_item],
    game_events: bob_snapshot.events,
    activity_entries: activities.fetch("Alice").entries_for(table),
    game_name: ->(id) { id.to_s }
  )
  assert(
    [:game, :chat, :room].all? { |category| merged_history.any? { |entry| entry.category == category } },
    "separate game, chat and room history categories were lost"
  )

  $game_room_test_user = "Alice"
  assert(lobbies.fetch("Alice").close_table(table), "owner could not close native room")
  $game_room_test_user = "Bob"
  assert(lobbies.fetch("Bob").open_tables.empty?, "closed LiveSession remained discoverable")

  assert(activity_table.calls == Array.new(users.length, :select), "Table requests continued after the four startup denials") if denied

end

puts "Native LiveSessions store tests passed: discovery, membership, invitations, room state, game stack, chat and cleanup, with and without table access"
