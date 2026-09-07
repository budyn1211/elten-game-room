require "set"
require_relative "live_sessions_multiplayer_test"

# This test deliberately uses the production transport, synchronizer and game
# repository. Only the LiveSessions service and app tables are deterministic
# in-memory stand-ins, allowing network faults to be reproduced by seed.

class FaultInjectedLiveSessionsBroker < LiveSessionsBroker
  Delivery = Struct.new(:due_at, :tie_breaker, :recipient, :sender, :packet, keyword_init: true)

  attr_reader :now_ms, :statistics

  def initialize(seed:)
    super()
    @random = Random.new(seed)
    @now_ms = 0
    @queue = []
    @blocked_users = Set.new
    @drop_next = Hash.new(0)
    @dropped_users = Set.new
    @drop_rate = 0.0
    @duplicate_rate = 0.0
    @recipient_delay = Hash.new(0)
    @minimum_delay = 0
    @maximum_delay = 0
    @fail_next_send = nil
    @statistics = Hash.new(0)
  end

  def configure_network(
    minimum_delay: 0,
    maximum_delay: 0,
    drop_rate: 0.0,
    duplicate_rate: 0.0,
    recipient_delay: {}
  )
    @minimum_delay = [minimum_delay.to_i, 0].max
    @maximum_delay = [maximum_delay.to_i, @minimum_delay].max
    @drop_rate = [[drop_rate.to_f, 0.0].max, 1.0].min
    @duplicate_rate = [[duplicate_rate.to_f, 0.0].max, 1.0].min
    @recipient_delay = Hash.new(0)
    recipient_delay.each { |user, delay| @recipient_delay[user.to_s.downcase] = [delay.to_i, 0].max }
    self
  end

  def block_user(user)
    @blocked_users << user.to_s.downcase
  end

  def unblock_user(user)
    @blocked_users.delete(user.to_s.downcase)
  end

  def drop_next_for(user, count: 1)
    @drop_next[user.to_s.downcase] += [count.to_i, 0].max
  end

  def fail_next_send!(message = "simulated LiveSessions send failure")
    @fail_next_send = RuntimeError.new(message)
  end

  def consume_dropped_users
    users = @dropped_users.to_a
    @dropped_users.clear
    users
  end

  def queued?
    !@queue.empty?
  end

  def drain
    deliveries = @queue.sort_by { |delivery| [delivery.due_at, delivery.tie_breaker] }
    @queue = []
    deliveries.each do |delivery|
      @now_ms = [@now_ms, delivery.due_at].max
      delivery.recipient.emit_message(delivery.sender, deep_copy(delivery.packet))
      @statistics[:delivered] += 1
    end
    deliveries.length
  end

  def close_table(table_id)
    record = records.find { |candidate| candidate.metadata["table_id"].to_i == table_id.to_i }
    return false if record == nil

    owner_view = record.views[record.owner_user.to_s.downcase]
    return false if owner_view == nil

    close(owner_view)
  end

  def connected_users_for(table_id)
    record = records.find { |candidate| candidate.metadata["table_id"].to_i == table_id.to_i }
    return [] if record == nil

    record.participants.values.map { |participant| participant.user.to_s }.sort
  end

  def send_packet(view, packet)
    if @fail_next_send != nil
      error = @fail_next_send
      @fail_next_send = nil
      @statistics[:failed_sends] += 1
      raise error
    end

    sender = view.broker_participant
    view.broker_record.views.each_value do |recipient|
      next if recipient.equal?(view)

      user = recipient.broker_participant.user.to_s.downcase
      @statistics[:attempted] += 1
      if drop_delivery?(user)
        @dropped_users << user
        @statistics[:dropped] += 1
        next
      end

      schedule_delivery(recipient, sender, packet, user)
      if @random.rand < @duplicate_rate
        schedule_delivery(recipient, sender, packet, user, duplicate: true)
        @statistics[:duplicates] += 1
      end
    end
    true
  end

  private

  def records
    instance_variable_get(:@records).values
  end

  def drop_delivery?(user)
    return true if @blocked_users.include?(user)
    if @drop_next[user] > 0
      @drop_next[user] -= 1
      return true
    end

    @random.rand < @drop_rate
  end

  def schedule_delivery(recipient, sender, packet, user, duplicate: false)
    jitter = @maximum_delay == @minimum_delay ? @minimum_delay : @random.rand(@minimum_delay..@maximum_delay)
    delay = jitter + @recipient_delay[user]
    # A duplicate gets independent jitter, which also exercises reordering.
    delay += @random.rand(0..20) if duplicate
    @statistics[:maximum_delay_ms] = [@statistics[:maximum_delay_ms], delay].max
    @statistics[:scheduled] += 1
    @queue << Delivery.new(
      due_at: @now_ms + delay,
      tie_breaker: @random.rand,
      recipient: recipient,
      sender: sender,
      packet: deep_copy(packet)
    )
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end
end

class FaultAwareSharedServerTable < SharedServerTable
  attr_reader :successful_inserts

  def initialize(**options)
    super(**options)
    @successful_inserts = 0
    @next_failure = nil
  end

  def fail_next_insert!(phase:, message:)
    @next_failure = [phase.to_sym, message.to_s]
  end

  def insert(values)
    failure = @next_failure
    @next_failure = nil
    raise RuntimeError, failure[1] if failure != nil && failure[0] == :before

    row = super(values)
    @successful_inserts += 1
    raise RuntimeError, failure[1] if failure != nil && failure[0] == :after

    row
  end
end

class FaultAwareSharedServerTables
  attr_reader :sessions, :events

  def initialize
    @sessions = FaultAwareSharedServerTable.new
    @events = FaultAwareSharedServerTable.new(reorder_equal_sequences: true)
  end

  def fetch(name)
    return @sessions if name.to_s == "game_sessions"
    return @events if name.to_s == "game_events"

    raise KeyError, "unknown server table #{name}"
  end
end


class NetworkProbeGame < GameRoomGames::Base
  def id
    "network_probe"
  end

  def name
    "Network probe"
  end

  def minimum_players
    2
  end

  def maximum_players
    4
  end

  def rule_sections
    []
  end

  def replay(session, events, repository)
    players = repository.players_for(session)
    accepted = events.to_a.select do |event|
      event["action"].to_s == "tick" && !repository.actor_of(event, session).to_s.empty?
    end
    timeline = accepted.map do |event|
      [
        repository.event_id(event),
        repository.actor_of(event, session),
        event["value"].to_s,
        event["sequence"].to_i
      ]
    end
    GameRoomGames::Replay.new(
      board: nil,
      players: players,
      current_player: nil,
      winner: nil,
      draw: false,
      accepted_events: accepted,
      history: [],
      state: { "timeline" => timeline }
    )
  end

  def surface_spec(_replay, _viewer)
    nil
  end

  def action_for(selection, _replay, _actor, context: nil)
    value = selection.respond_to?(:key?) ? (selection["value"] || selection[:value]) : selection
    [:ok, GameRoomGames::ActionPlan.single(action: "tick", value: value.to_s)]
  end
end

class RecoveringVirtualGameClient < VirtualGameClient
  def initialize(user:, users:, table:, game_class:, transport:, server_tables:)
    super
    @synchronizer = GameRoomSync::Controller.new(
      transport: transport,
      table_id: table["__id"],
      reconnect: -> {
        transport.activate_table(
          table_id: table["__id"],
          owner: table["owner"],
          capacity: users.length,
          user: user
        )
      }
    )
  end

  def submit_tick(value)
    submit_plan(GameRoomGames::ActionPlan.single(action: "tick", value: value.to_s))
  end

  def process_all_pending(limit: 100)
    kinds = []
    while (event = @synchronizer.next_event(idle: true)) != nil
      kinds << event.kind
      raise "#{user} entered a synchronization loop" if kinds.length > limit

      case event.kind
      when :game_started
        loaded = Session.as(user) do
          @repository.session_by_id(event.session_id, table: @table)
        end
        raise "#{user} could not load the started game" if loaded == nil

        adopt_started_session(loaded)
      when :game_changed
        @synchronizer.synchronize { send(:refresh, force_events: true) }
      when :recovery
        @synchronizer.synchronize do
          if @session == nil
            latest_id = Session.as(user) { @repository.latest_session_id_for_table(@table) }
            loaded = Session.as(user) { @repository.session_by_id(latest_id, table: @table) }
            raise "#{user} could not recover the current game" if loaded == nil

            adopt_started_session(loaded)
          else
            send(:refresh, force_events: true)
          end
        end
      when :table_changed
        # Membership is represented by LiveSessions itself. The game-state
        # assertion below deliberately concerns only durable game records.
      else
        raise "#{user} received an unexpected #{event.kind} event"
      end
    end
    kinds
  end

  def request_recovery!
    @synchronizer.request_recovery!
  end

  def force_authoritative_refresh
    @synchronizer.synchronize { send(:refresh, force_events: true) }
  end
end

def build_fault_injected_transports(broker, users)
  transports = {}
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
    transport = GameRoomTransport.new(
      nil,
      backend: GameRoomTransport::HybridBackend.new(bootstrap: bootstrap, live: live)
    )
    broker.register_signal_transport(user, transport)
    transports[user] = transport
    live_backends[user] = live
  end
  transports.each_value(&:start)
  [transports, live_backends]
end

def start_resilience_game(broker:, users:, table_id:, drop_start_for: nil)
  transports, live_backends = build_fault_injected_transports(broker, users)
  users.each do |user|
    established = transports.fetch(user).establish_membership(
      table_id: table_id,
      owner: users.first,
      capacity: users.length,
      user: user,
      bootstrap: user != users.first,
      timeout: 0.1
    )
    assert(established, "#{user} did not establish LiveSessions membership")
  end
  assert(
    broker.connected_users_for(table_id) == users.sort,
    "the four virtual clients did not join the LiveSession"
  )

  table = {
    "__id" => table_id,
    "__insertion_user" => users.first,
    "owner" => users.first,
    "game" => "network_probe"
  }
  server_tables = FaultAwareSharedServerTables.new
  clients = users.each_with_object({}) do |user, result|
    result[user] = RecoveringVirtualGameClient.new(
      user: user,
      users: users,
      table: table,
      game_class: NetworkProbeGame,
      transport: transports.fetch(user),
      server_tables: server_tables
    )
  end

  owner = clients.fetch(users.first)
  broker.drop_next_for(drop_start_for) if drop_start_for != nil
  session = Session.as(users.first) do
    owner.repository.start_session(
      table: table,
      game: "network_probe",
      players: users,
      options: "{}",
      recipients: users
    )
  end
  owner.adopt_started_session(session)
  broker.drain
  broker.consume_dropped_users.each { |user| broker.emit_gap(user, 0, 1) }
  users.drop(1).each do |user|
    kinds = clients.fetch(user).process_all_pending
    assert(
      kinds.include?(:game_started) || kinds.include?(:recovery),
      "#{user} neither received nor recovered the game start"
    )
    assert(clients.fetch(user).session != nil, "#{user} has no game after start recovery")
  end
  clients.each_value(&:process_all_pending)
  assert_clients_converged(clients, "resilience test start")
  [clients, transports, live_backends, server_tables]
end

def settle_fault_injected_clients(broker, clients, recover_drops: true)
  broker.drain
  if recover_drops
    broker.consume_dropped_users.each { |user| broker.emit_gap(user, 1, 2) }
  end
  clients.each_value(&:process_all_pending)
  clients.each_value(&:process_all_pending)
end

def assert_event_stream_integrity(clients, expected_count, stage)
  assert_clients_converged(clients, stage)
  ids = clients.values.first.replay.accepted_events.map { |event| event["__id"].to_i }
  assert(ids.length == expected_count, "#{stage}: expected #{expected_count} events, got #{ids.length}")
  assert(ids.uniq.length == ids.length, "#{stage}: duplicate durable events were reconstructed")
  assert(ids == ids.sort, "#{stage}: server event order is not append-only")
end

users = %w[Alice Bob Carol Dave]
seed = Integer(ARGV[0] || ENV.fetch("GAME_ROOM_RESILIENCE_SEED", "20260907"), 10)
batches = Integer(ARGV[1] || ENV.fetch("GAME_ROOM_RESILIENCE_BATCHES", "400"), 10)
raise ArgumentError, "the resilience test requires at least one batch" if batches <= 0
random = Random.new(seed)
broker = FaultInjectedLiveSessionsBroker.new(seed: seed)
clients, transports, live_backends, server_tables = start_resilience_game(
  broker: broker,
  users: users,
  table_id: 901,
  drop_start_for: "Dave"
)
initial_signal_count = broker.signal_packets.length
broker.configure_network(
  minimum_delay: 0,
  maximum_delay: 8_000,
  drop_rate: 0.035,
  duplicate_rate: 0.12,
  recipient_delay: { "Alice" => 0, "Bob" => 40, "Carol" => 250, "Dave" => 1_200 }
)

# Four hundred default batches produce roughly one thousand writes. Actors in one batch
# all decide from their previous local snapshot, reproducing concurrent equal
# sequence numbers while deliveries are delayed, duplicated, reordered or lost.
event_count = 0
batches.times do |batch|
  actor_count = random.rand(1..4)
  actors = users.sample(actor_count, random: random)
  actors.each_with_index do |actor, index|
    clients.fetch(actor).submit_tick("#{batch}:#{index}")
    event_count += 1
  end
  settle_fault_injected_clients(broker, clients)
  assert_event_stream_integrity(clients, event_count, "random batch #{batch + 1}")
end
assert(
  broker.signal_packets.length == initial_signal_count,
  "ordinary game traffic used a Signal after LiveSessions membership was established"
)

# A silently lost callback is intentionally not disguised as a successful
# recovery. It remains invisible until the LiveSessions API emits on_gap or
# on_closed; after that callback, the durable event must be recovered.
broker.configure_network(maximum_delay: 500)
broker.block_user("Dave")
clients.fetch("Alice").submit_tick("silent-stall")
event_count += 1
broker.drain
clients.reject { |user, _client| user == "Dave" }.each_value(&:process_all_pending)
assert(
  clients.fetch("Dave").replay.accepted_events.length == event_count - 1,
  "a deliberately silent loss unexpectedly looked like an API-reported gap"
)
broker.unblock_user("Dave")
broker.consume_dropped_users
broker.emit_gap("Dave", 10, 11)
clients.fetch("Dave").process_all_pending
assert_event_stream_integrity(clients, event_count, "reported gap after a silent loss")

# Queue a very late old-session notification, close the LiveSession, then
# explicitly rejoin all clients. A close callback may recover durable state,
# but it must not start its own membership retry loop. The later stale packet
# may cause one harmless read, but it must not duplicate or lose a move.
broker.configure_network(minimum_delay: 10_000, maximum_delay: 10_000)
clients.fetch("Alice").submit_tick("late-old-session-packet")
event_count += 1
assert(broker.queued?, "the late old-session packet was not queued")
assert(broker.close_table(901), "the active LiveSession could not be closed")
clients.each_value(&:process_all_pending)
clients.each_value(&:process_all_pending)
assert(
  broker.connected_users_for(901) == [users.first],
  "a close callback rejoined non-owner clients without an explicit membership request"
)
users.each do |user|
  established = transports.fetch(user).establish_membership(
    table_id: 901,
    owner: users.first,
    capacity: users.length,
    user: user,
    bootstrap: user != users.first,
    timeout: 0.1
  )
  assert(established, "#{user} did not explicitly rejoin after a LiveSessions close")
end
assert(
  broker.connected_users_for(901) == users.sort,
  "not every client rejoined after an explicit membership request"
)
broker.drain
clients.each_value(&:process_all_pending)
assert_event_stream_integrity(clients, event_count, "explicit close and stale callback")
assert(
  broker.signal_packets.length == initial_signal_count + users.length - 1,
  "explicit session recreation did not use exactly one membership bootstrap per non-owner"
)

# A transport send can fail after the game event was persisted. A later valid
# notification must reveal both durable events without repeating the first one.
broker.configure_network(maximum_delay: 1_000)
broker.fail_next_send!
clients.fetch("Alice").submit_tick("publish-failed-after-write")
event_count += 1
clients.fetch("Bob").submit_tick("next-successful-notification")
event_count += 1
settle_fault_injected_clients(broker, clients)
broker.emit_gap("Bob", 20, 21)
clients.fetch("Bob").process_all_pending
assert_event_stream_integrity(clients, event_count, "failed publish followed by a valid notification")

# Model an app-table response disappearing after the row was accepted. No
# automatic retry is performed. Explicit reconciliation must reveal exactly
# one new event on all clients.
server_tables.events.fail_next_insert!(
  phase: :after,
  message: "simulated response loss after durable insert"
)
begin
  clients.fetch("Carol").submit_tick("response-lost-after-write")
  raise "the simulated post-write failure was not raised"
rescue RuntimeError => error
  raise if error.message != "simulated response loss after durable insert"
end
event_count += 1
clients.each_value(&:request_recovery!)
clients.each_value(&:process_all_pending)
assert_event_stream_integrity(clients, event_count, "response loss after durable insert")

# A rate limit before the insert must leave the durable stream unchanged.
server_tables.events.fail_next_insert!(phase: :before, message: "HTTP 429: Too many requests")
begin
  clients.fetch("Dave").submit_tick("must-not-exist")
  raise "the simulated rate limit was not raised"
rescue RuntimeError => error
  raise if !error.message.include?("429")
end
clients.each_value(&:request_recovery!)
clients.each_value(&:process_all_pending)
assert_event_stream_integrity(clients, event_count, "rate limit before durable insert")

assert(
  live_backends.values.all? { |backend| backend.connected_users(901).sort == users.sort },
  "the clients disagree about final LiveSessions membership"
)

puts "Four-client LiveSessions resilience test passed"
puts "seed=#{seed} batches=#{batches} events=#{event_count} " \
  "scheduled=#{broker.statistics[:scheduled]} delivered=#{broker.statistics[:delivered]} " \
  "dropped=#{broker.statistics[:dropped]} duplicates=#{broker.statistics[:duplicates]} " \
  "failed_sends=#{broker.statistics[:failed_sends]} " \
  "max_delay_ms=#{broker.statistics[:maximum_delay_ms]} signals=#{broker.signal_packets.length}"
