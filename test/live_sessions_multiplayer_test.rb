require "json"

def _(text)
  text
end

def n_(singular, plural, count)
  count.to_i == 1 ? singular : plural
end

module Session
  @name = "Alice"

  def self.name
    @name
  end

  def self.as(user)
    previous = @name
    @name = user.to_s
    yield
  ensure
    @name = previous
  end
end

require_relative "../lib/game_room_transport"
require_relative "../lib/game_sync"
require_relative "../lib/game_repository"
require_relative "../lib/game_random"
require_relative "../games/ninety_nine"
require_relative "../games/farkle"
require_relative "../games/categories"

def assert(condition, message)
  raise message if !condition
end

class LiveSessionsBroker
  Participant = Struct.new(:id, :user, :metadata, keyword_init: true)

  class Record
    attr_reader :id, :metadata, :capacity, :owner_user, :participants, :views

    def initialize(id:, metadata:, capacity:, owner_user:)
      @id = id
      @metadata = metadata
      @capacity = capacity
      @owner_user = owner_user
      @participants = {}
      @views = {}
    end
  end

  class Endpoint
    attr_reader :user

    def initialize(broker, user)
      @broker = broker
      @user = user
    end

    def create(metadata:, participant_metadata:, capacity:)
      @broker.create(self, metadata, participant_metadata, capacity)
    end

    def on_invitation(&block)
      @invitation_callback = block
    end

    def deliver_invitation(invitation)
      @invitation_callback.call(invitation)
    end
  end

  class SessionView
    def initialize(broker, record, endpoint, participant)
      @broker = broker
      @record = record
      @endpoint = endpoint
      @participant = participant
      @closed = false
    end

    def participants
      @record.participants.values.dup
    end

    def owner?
      @participant.user.casecmp(@record.owner_user) == 0
    end

    def closed?
      @closed
    end

    def invite(user, metadata: {})
      @broker.invite(self, user, metadata)
    end

    def send(packet)
      @broker.send_packet(self, packet)
    end

    def leave
      @broker.leave(self, :left)
    end

    def close
      @broker.close(self)
    end

    def on_message(&block); @message_callback = block; end
    def on_participant_joined(&block); @joined_callback = block; end
    def on_participant_left(&block); @left_callback = block; end
    def on_gap(&block); @gap_callback = block; end
    def on_closed(&block); @closed_callback = block; end

    def emit_message(sender, packet)
      @message_callback&.call(sender, Marshal.load(Marshal.dump(packet)))
    end

    def emit_joined(participant)
      @joined_callback&.call(participant)
    end

    def emit_left(participant, reason)
      @left_callback&.call(participant, reason)
    end

    def emit_gap(from, to)
      @gap_callback&.call(from, to)
    end

    def emit_closed(reason)
      return if @closed

      @closed = true
      @closed_callback&.call(reason)
    end

    def broker_record
      @record
    end

    def broker_participant
      @participant
    end
  end

  class Invitation
    attr_reader :metadata, :invitation_metadata

    def initialize(broker, record, endpoint, invitation_metadata)
      @broker = broker
      @record = record
      @endpoint = endpoint
      @metadata = record.metadata
      @invitation_metadata = invitation_metadata
      @pending = true
    end

    def pending?
      @pending
    end

    def accept(participant_metadata: {})
      raise "invitation already resolved" if !@pending

      @pending = false
      @broker.accept(@record, @endpoint, participant_metadata)
    end

    def reject
      return false if !@pending

      @pending = false
      true
    end
  end

  attr_reader :signal_packets

  def initialize
    @endpoints = {}
    @records = {}
    @next_session_id = 1
    @next_participant_id = 1
    @signal_transports = {}
    @signal_packets = []
  end

  def endpoint(user)
    @endpoints[user.downcase] ||= Endpoint.new(self, user)
  end

  def register_signal_transport(user, transport)
    @signal_transports[user.downcase] = transport
  end

  def signal_backend(sender)
    broker = self
    Class.new do
      define_method(:publish) do |users:, packet:|
        broker.deliver_signal(sender, users, packet)
      end
    end.new
  end

  def deliver_signal(sender, users, packet)
    @signal_packets << [sender, users.dup, packet["type"]]
    users.each_with_object([]) do |user, delivered|
      transport = @signal_transports[user.to_s.downcase]
      next if transport == nil

      transport.receive(sender, Marshal.load(Marshal.dump(packet)))
      delivered << user.to_s
    end
  end

  def create(endpoint, metadata, participant_metadata, capacity)
    id = @next_session_id
    @next_session_id += 1
    record = Record.new(id: id, metadata: metadata, capacity: capacity, owner_user: endpoint.user)
    @records[id] = record
    add_participant(record, endpoint, participant_metadata)
  end

  def invite(view, user, metadata)
    endpoint = @endpoints[user.to_s.downcase]
    return false if endpoint == nil

    endpoint.deliver_invitation(Invitation.new(self, view.broker_record, endpoint, metadata))
    true
  end

  def accept(record, endpoint, participant_metadata)
    existing = record.views[endpoint.user.downcase]
    return existing if existing != nil
    raise "session is full" if record.participants.length >= record.capacity

    participant = Participant.new(
      id: @next_participant_id.to_s,
      user: endpoint.user,
      metadata: participant_metadata
    )
    @next_participant_id += 1
    previous_views = record.views.values.dup
    view = SessionView.new(self, record, endpoint, participant)
    record.participants[endpoint.user.downcase] = participant
    record.views[endpoint.user.downcase] = view
    previous_views.each { |current| current.emit_joined(participant) }
    view
  end

  def send_packet(view, packet)
    sender = view.broker_participant
    view.broker_record.views.each_value do |recipient|
      next if recipient.equal?(view)

      recipient.emit_message(sender, packet)
    end
    true
  end

  def leave(view, reason)
    record = view.broker_record
    participant = view.broker_participant
    record.participants.delete(participant.user.downcase)
    record.views.delete(participant.user.downcase)
    record.views.each_value { |current| current.emit_left(participant, reason) }
    view.emit_closed(reason)
    true
  end

  def close(view)
    record = view.broker_record
    record.views.values.each { |current| current.emit_closed(:closed) }
    @records.delete(record.id)
    true
  end

  def emit_gap(user, from, to)
    @records.each_value do |record|
      view = record.views[user.downcase]
      view&.emit_gap(from, to)
    end
  end

  private

  def add_participant(record, endpoint, metadata)
    accept(record, endpoint, metadata)
  end
end

# A shared, deterministic stand-in for the two server tables used by a game.
# Every virtual client gets its own GameRepository and event cache while all of
# them read and write the same rows, just as four real ELTEN clients would.
class SharedServerTable
  def initialize(reorder_equal_sequences: false)
    @rows = []
    @next_id = 1
    @reorder_equal_sequences = reorder_equal_sequences
  end

  def insert(values)
    row = values.dup.merge(
      "__id" => @next_id,
      "__insertion_user" => Session.name.to_s
    )
    if @reorder_equal_sequences && row.key?("move_id")
      # Preserve the old failure case: with the legacy sequence/time/UUID
      # ordering, a later concurrent insert sorted before an earlier one. The
      # production repository must request the immutable server-ID order and
      # therefore still receive both rows.
      row["created_at"] = 1_000
      row["move_id"] = format(
        "00000000-0000-4000-8000-%012x",
        0xffffffffffff - @next_id
      )
    end
    @next_id += 1
    @rows << row
    row.dup
  end

  def select(where: nil, order: nil, limit: nil, offset: nil)
    rows = @rows.select do |row|
      where == nil || where.all? { |key, value| row[key].to_s == value.to_s }
    end
    rows = ordered(rows, order)
    rows = rows.drop(offset.to_i)
    rows = rows.first(limit.to_i) if limit != nil
    rows.map(&:dup)
  end

  private

  def ordered(rows, order)
    fields = order.to_a
    return rows if fields.empty?

    rows.sort do |left, right|
      comparison = 0
      fields.each do |field, direction|
        comparison = left[field] <=> right[field]
        comparison *= -1 if direction.to_s.casecmp("desc") == 0
        break if comparison != 0
      end
      comparison
    end
  end
end

class SharedServerTables
  def initialize
    @tables = {
      "game_sessions" => SharedServerTable.new,
      "game_events" => SharedServerTable.new(reorder_equal_sequences: true)
    }
  end

  def fetch(name)
    @tables.fetch(name.to_s)
  end
end

class VirtualGameClient
  attr_reader :user, :game, :repository, :synchronizer, :session, :replay

  def initialize(user:, users:, table:, game_class:, transport:, server_tables:)
    @user = user
    @users = users
    @table = table
    @game = game_class.new
    @repository = GameRepository.new(Object.new, transport: transport, server_tables: server_tables)
    @synchronizer = GameRoomSync::Controller.new(
      transport: transport,
      table_id: table["__id"]
    )
  end

  def adopt_started_session(session)
    @session = session
    @synchronizer.update_session(@repository.session_id(session), discard_pending: true)
    refresh(force_events: true)
  end

  def process_pending(expected: nil)
    event = @synchronizer.next_event(idle: true)
    raise "#{user} did not receive #{expected || 'a synchronization event'}" if event == nil
    if expected != nil && event.kind != expected
      raise "#{user} received #{event.kind} instead of #{expected}"
    end

    case event.kind
    when :game_started
      loaded = Session.as(user) do
        @repository.session_by_id(event.session_id, table: @table)
      end
      raise "#{user} could not load the started game" if loaded == nil

      adopt_started_session(loaded)
    when :game_changed, :recovery
      @synchronizer.synchronize { refresh(force_events: true) }
    else
      raise "#{user} received an unexpected #{event.kind} event"
    end
    event
  end

  def discard_pending_change
    event = @synchronizer.next_event(idle: true)
    raise "#{user} had no game change to discard" if event == nil || event.kind != :game_changed

    event
  end

  def submit_selection(selection, context: nil)
    status, plan = @game.action_for(selection, @replay, user, context: context)
    raise "#{user}'s action was rejected with #{status}" if status != :ok

    submit_plan(plan)
  end

  def submit_plan(plan)
    inserted = Session.as(user) do
      @repository.append_events(
        session: @session,
        sequence: @repository.next_sequence(@session, @replay.accepted_events),
        events: plan.events,
        recipients: @users,
        actor: user
      )
    end
    refresh
    inserted
  end

  private

  def refresh(force_events: false)
    snapshot = Session.as(user) do
      @repository.snapshot_for(@session, force_events: force_events)
    end
    raise "#{user} could not refresh the game" if snapshot == nil

    @session = snapshot.session
    @replay = @game.replay(@session, snapshot.events, @repository)
  end
end

def start_virtual_game(broker:, transports:, users:, table_id:, game_class:)
  game = game_class.new
  table = {
    "__id" => table_id,
    "__insertion_user" => users.first,
    "owner" => users.first,
    "game" => game.id
  }
  server_tables = SharedServerTables.new
  signal_count = broker.signal_packets.length
  users.each do |user|
    established = transports.fetch(user).establish_membership(
      table_id: table_id,
      owner: users.first,
      capacity: users.length,
      user: user,
      bootstrap: user != users.first,
      timeout: 0.1
    )
    assert(established, "#{user} could not establish #{game.id} LiveSessions membership")
  end
  assert(
    broker.signal_packets.length == signal_count + users.length - 1,
    "#{game.id} did not use exactly one bootstrap signal per joining client"
  )

  virtual = users.each_with_object({}) do |user, result|
    result[user] = VirtualGameClient.new(
      user: user,
      users: users,
      table: table,
      game_class: game_class,
      transport: transports.fetch(user),
      server_tables: server_tables
    )
  end
  session = Session.as(users.first) do
    virtual.fetch(users.first).repository.start_session(
      table: table,
      game: game.id,
      players: users,
      options: JSON.generate(game.default_options),
      recipients: users
    )
  end
  virtual.fetch(users.first).adopt_started_session(session)
  users.drop(1).each { |user| virtual.fetch(user).process_pending(expected: :game_started) }
  assert_clients_converged(virtual, "#{game.id} start")
  [virtual, signal_count + users.length - 1]
end

def refresh_remote_clients(virtual, actor, expected: :game_changed)
  virtual.each do |user, client|
    next if user.casecmp(actor.to_s) == 0

    client.process_pending(expected: expected)
  end
end

def assert_clients_converged(virtual, stage)
  baseline = virtual.values.first.replay
  expected_ids = baseline.accepted_events.map { |event| event["__id"] }
  actual_ids = virtual.transform_values do |client|
    client.replay&.accepted_events.to_a.map { |event| event["__id"] }
  end
  assert(
    actual_ids.values.all? { |ids| ids == expected_ids },
    "clients have different event streams after #{stage}: #{actual_ids.inspect}"
  )
  virtual.each_value do |client|
    assert(client.replay != nil, "#{client.user} has no replay after #{stage}")
    assert(client.replay.state == baseline.state, "#{client.user} has a different game state after #{stage}")
  end
end

broker = LiveSessionsBroker.new
users = %w[Alice Bob Carol Dave]
clients = {}
live_backends = {}

users.each do |user|
  transport = nil
  live = GameRoomTransport::LiveSessionBackend.new(
    nil,
    receiver: ->(sender, packet) { transport.receive(sender, packet) },
    membership_receiver: ->(table_id, changed_user, change) {
      transport.send(:session_membership_changed, table_id, changed_user, change)
    },
    gap_receiver: ->(table_id, from, to) { transport.send(:session_gap, table_id, from, to) },
    endpoint_provider: -> { broker.endpoint(user) }
  )
  signal_backend = broker.signal_backend(user)
  bootstrap = Object.new
  bootstrap.define_singleton_method(:request) do |owner:, packet:|
    signal_backend.publish(users: [owner], packet: packet)
    true
  end
  hybrid = GameRoomTransport::HybridBackend.new(bootstrap: bootstrap, live: live)
  transport = GameRoomTransport.new(nil, backend: hybrid)
  broker.register_signal_transport(user, transport)
  clients[user] = transport
  live_backends[user] = live
end

clients.each_value(&:start)
users.each do |user|
  established = clients[user].establish_membership(
    table_id: 7,
    owner: "Alice",
    capacity: 4,
    user: user,
    bootstrap: user != "Alice",
    timeout: 0.1
  )
  assert(established, "#{user} did not establish initial LiveSessions membership")
end

users.each do |user|
  assert(
    live_backends[user].connected_users(7).sort == users.sort,
    "#{user} did not join the four-client LiveSession"
  )
end
assert(broker.signal_packets.length == 3, "public joins used more than one bootstrap signal per participant")

clients["Alice"].game_changed(
  table_id: 7,
  session_id: 19,
  users: users,
  change: "action",
  actor: "Alice"
)
%w[Bob Carol Dave].each do |user|
  assert(clients[user].consume_game_change(19).is_a?(Numeric), "#{user} missed a LiveSessions game action")
end
assert(broker.signal_packets.length == 3, "a normal game action fell back to Signals")

clients["Bob"].game_changed(
  table_id: 7,
  session_id: 20,
  users: users,
  change: "started",
  actor: "Bob"
)
%w[Alice Carol Dave].each do |user|
  assert(clients[user].consume_game_start(7) == 20, "#{user} did not enter the newly started game")
end

# Ninety-Nine: all four clients must enter the atomically created game, then
# reconstruct the same deal and the same atomic play + automatic draw move.
ninety_clients, ninety_signal_count = start_virtual_game(
  broker: broker,
  transports: clients,
  users: users,
  table_id: 101,
  game_class: GameRoomGames::NinetyNine
)
ninety_owner = ninety_clients.fetch("Alice")
ninety_context = GameRoomGames::ActionContext.new(
  session_id: ninety_owner.repository.session_id(ninety_owner.session),
  table_id: 101,
  random_source: GameRoomRandom::SeededSource.new(101),
  now: 1_000
)
ninety_owner.submit_selection(
  { "kind" => "command", "action" => "deal" },
  context: ninety_context
)
refresh_remote_clients(ninety_clients, "Alice")
assert_clients_converged(ninety_clients, "Ninety-Nine deal")

ninety_actor = ninety_owner.replay.current_player
ninety_player = ninety_clients.fetch(ninety_actor)
ninety_selection = ninety_player.game.legal_actions(ninety_player.replay, ninety_actor).first
ninety_player.submit_selection(ninety_selection)
refresh_remote_clients(ninety_clients, ninety_actor)
assert_clients_converged(ninety_clients, "Ninety-Nine play and automatic draw")
assert(
  ninety_owner.replay.accepted_events.map { |event| event["action"] } == %w[deal play_draw],
  "Ninety-Nine did not synchronize the complete play and automatic draw"
)
assert(
  broker.signal_packets.length == ninety_signal_count,
  "Ninety-Nine actions unexpectedly fell back to Signals"
)

# Farkle: three rapid server writes intentionally collapse into one pending
# notification. One refresh must load all of them. Dave additionally misses
# that refresh and recovers through the LiveSessions gap callback.
farkle_clients, farkle_signal_count = start_virtual_game(
  broker: broker,
  transports: clients,
  users: users,
  table_id: 102,
  game_class: GameRoomGames::Farkle
)
farkle_owner = farkle_clients.fetch("Alice")
farkle_context = GameRoomGames::ActionContext.new(
  session_id: farkle_owner.repository.session_id(farkle_owner.session),
  table_id: 102,
  random_source: GameRoomRandom::SequenceSource.new([1, 2, 3, 4, 5, 6]),
  now: 1_000
)
farkle_owner.submit_selection(
  { "kind" => "dice", "action" => "roll" },
  context: farkle_context
)
keep_all = farkle_owner.game.legal_actions(farkle_owner.replay, "Alice").find do |action|
  action["action"] == "keep" && action["indices"].to_s.split(",").length == 6
end
assert(keep_all != nil, "Farkle did not offer the complete straight")
farkle_owner.submit_selection(keep_all)
bank = farkle_owner.game.legal_actions(farkle_owner.replay, "Alice").find do |action|
  action["action"] == "bank"
end
assert(bank != nil, "Farkle did not offer banking after the complete straight")
farkle_owner.submit_selection(bank)

%w[Bob Carol].each { |user| farkle_clients.fetch(user).process_pending(expected: :game_changed) }
farkle_clients.fetch("Dave").discard_pending_change
broker.emit_gap("Dave", 1, 3)
farkle_clients.fetch("Dave").process_pending(expected: :recovery)
assert_clients_converged(farkle_clients, "Farkle notification coalescing and gap recovery")
assert(
  farkle_owner.replay.accepted_events.map { |event| event["action"] } == %w[roll keep bank],
  "Farkle lost one of the rapid actions"
)
assert(farkle_owner.replay.current_player == "Bob", "Farkle did not pass the turn after banking")
assert(
  broker.signal_packets.length == farkle_signal_count,
  "Farkle actions unexpectedly fell back to Signals"
)

# Countries and Cities: submissions are deliberately made concurrently from
# two clients that have not yet seen each other's write. This is the important
# four-player case: both clients legitimately choose the same next sequence,
# and every cache must still converge without leaving and reopening the game.
categories_clients, categories_signal_count = start_virtual_game(
  broker: broker,
  transports: clients,
  users: users,
  table_id: 103,
  game_class: GameRoomGames::Categories
)
categories_owner = categories_clients.fetch("Alice")
categories_context = GameRoomGames::ActionContext.new(
  session_id: categories_owner.repository.session_id(categories_owner.session),
  table_id: 103,
  random_source: GameRoomRandom::SequenceSource.new([1]),
  now: 1_000
)
categories_owner.submit_selection(
  { "kind" => "automatic", "action" => "start_round" },
  context: categories_context
)
refresh_remote_clients(categories_clients, "Alice")
assert_clients_converged(categories_clients, "Countries and Cities round start")

submissions = HiddenSubmissions::Vault.new(HiddenSubmissions::MemoryStorage.new)
%w[Bob Carol].each do |actor|
  client = categories_clients.fetch(actor)
  answers = client.replay.state[:round_categories].each_with_object({}) do |category, result|
    result[category] = "#{actor}-#{category}"
  end
  context = GameRoomGames::ActionContext.new(
    session_id: client.repository.session_id(client.session),
    table_id: 103,
    hidden_submissions: submissions,
    now: 1_010
  )
  client.submit_selection(
    { "kind" => "answer_sheet", "action" => "submit", "answers" => answers },
    context: context
  )
end

categories_clients.each_value { |client| client.process_pending(expected: :game_changed) }
assert_clients_converged(categories_clients, "concurrent Countries and Cities submissions")
assert(
  categories_owner.replay.state[:commitments].length == 2,
  "Countries and Cities lost a concurrent answer submission"
)
assert(
  broker.signal_packets.length == categories_signal_count,
  "Countries and Cities actions unexpectedly fell back to Signals"
)

broker.emit_gap("Dave", 8, 10)
assert(clients["Dave"].consume_recovery(7), "a missing LiveSessions range did not request full reconciliation")

clients["Dave"].deactivate_table(table_id: 7)
%w[Alice Bob Carol].each do |user|
  assert(clients[user].consume_table_change(7), "#{user} did not observe a participant leaving")
end

# A missing recipient is reported, but does not cause forced re-invitation or
# replay of an old notification. Normal membership bootstrap remains separate.
missing_delivery = clients["Alice"].game_changed(
  table_id: 7,
  session_id: 77,
  users: ["Alice", "Dave"],
  change: "action",
  actor: "Alice"
)
assert(missing_delivery.status == :no_recipient, "a missing participant was reported as notified")
assert(!clients["Alice"].consume_recovery(7), "a missing game recipient requested forced recovery")
assert(
  clients["Dave"].establish_membership(
    table_id: 7,
    owner: "Alice",
    capacity: 4,
    user: "Dave",
    bootstrap: true,
    timeout: 0.1
  ),
  "Dave did not re-establish LiveSessions membership"
)
assert(
  clients["Dave"].consume_game_change(77) == nil,
  "an obsolete game notification was resent after normal membership recovery"
)

puts "Four-client LiveSessions transport test passed"
