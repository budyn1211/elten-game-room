require_relative 'realtime_channel'
require_relative 'pong_client'

# Actual EventChannel/PeerEngine, with only native I/O and finite-worker timing
# replaced. One-way delivery and RPC response delays are independent. No live
# server, profiles, UI injection, or swallowed/dropped reliable packets.
class PongRelayFixture
  attr_reader :h, :sessions, :workers, :transmissions
  attr_accessor :one_way, :rpc_delay

  class Work
    def initialize(rig); @rig = rig; end
    def busy?; @result != nil; end
    def start
      return false if @closed || busy?
      @result = [yield, nil]
      @due = @rig.h.now + @rig.rpc_delay
      true
    rescue StandardError => error
      @result, @due = [nil, error], @rig.h.now + @rig.rpc_delay
      true
    end
    def take
      return unless @result && @rig.h.now >= @due
      result, @result = @result, nil
      result unless @closed
    end
    def close; @closed = true; end
  end

  class Session < ChannelSession
    attr_reader :rig, :viewer
    def initialize(rig, viewer, names)
      super('scheduled-four-humans', viewer, names)
      @rig, @viewer = rig, viewer
    end
    def on_reliable(&block); @event_receiver = block; end
    def send_reliable(data, to:)
      delivery = Struct.new(:results).new(to.to_h { |p| [p, :pending] })
      rig.transmit(self, data, to, delivery)
      delivery
    end
    def send_unreliable(data, to:); rig.transmit(self, data, to, nil); end
    def deliver_message(sender, data, reliable)
      callback = reliable ? @event_receiver : @receiver
      callback.call(ChannelMessage.new(sender, data)) if callback
    end
  end

  def initialize(players: %w[Alice Bob Carol Dave], teams: [0, 0, 1, 1], one_way: 0.04, rpc_delay: 0.12, options: {})
    @h = PongHarness.new(players: players, viewers: (['Alice'] + players.reject { |name| GameRoomParticipants.bot?(name) }).uniq,
      options: {'team_size' => players.length == 4 ? 2 : 1, 'team_seats' => teams}.merge(options))
    @one_way, @rpc_delay = one_way, rpc_delay
    @pending, @transmissions, @workers, @reliable_due = [], [], [], {}
    names = h.clients.keys
    @sessions = names.to_h { |name| [name, Session.new(self, name, names)] }
    h.clients.each do |name, client|
      h.network[name.downcase].close
      factory = -> { Work.new(self).tap { |worker| @workers << worker } }
      channel = GameRoomRealtime::EventChannel.new(program: ChannelProgram.new(name),
        match: client.instance_variable_get(:@match), owner: 'Alice', viewer: name,
        clock: -> { h.now }, members: -> { names }, work_factory: factory, event_work_factory: factory)
      client.instance_variable_set(:@channel, channel)
      client.before_wait(h.replay, name)
      channel.instance_variable_set(:@endpoint, ChannelEndpoint.new(name))
      channel.__send__(:attach, sessions.fetch(name))
      h.network[name.downcase] = channel
    end
  end

  def transmit(session, data, targets, delivery)
    packet = JSON.parse(data)
    @transmissions << {at: h.now, sender: session.viewer, targets: targets.map(&:user), packet: packet} if delivery
    targets.each do |target|
      delay = one_way.respond_to?(:call) ? one_way.call(session.viewer, target.user, packet) : one_way
      if delay == :drop
        raise 'fixture cannot silently drop a reliable action' if delivery
        next
      end
      due = h.now + delay
      if delivery
        key = [session.viewer, target.user]
        due = [due, @reliable_due.fetch(key, 0.0) + 0.000001].max
        @reliable_due[key] = due
      end
      @pending << [due, session, target, data, delivery]
    end
  end

  def advance(count, names: h.clients.keys)
    count.times do
      h.now += 0.008
      ready, @pending = @pending.partition { |row| row[0] <= h.now }
      ready.sort_by(&:first).each do |_at, sender, recipient, data, delivery|
        target = sessions.fetch(recipient.user)
        target.deliver_message(ChannelParticipant.new(sender.self_id, sender.viewer), data, delivery != nil)
        delivery.results[recipient] = :delivered if delivery
      end
      names.each { |name| h.clients[name].frame }
    end
  end

  def ready
    advance(1000)
    assert(h.clients.values.none?(&:paused), 'scheduled clients failed to become ready')
  end

  def close; h.close; end
end
