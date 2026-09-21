require_relative '../lib/realtime/channel'

def assert(value, message); raise message unless value; end

# Deterministic finite workers. The endpoint/session fake intentionally exposes
# only the verified public API; no pump, transport internals or live accounts.
class ChannelWork
  attr_reader :operation
  def busy?; @operation || @result; end
  def start(&block); return false if busy? || @closed; @operation = block; true; end
  def finish
    operation, @operation = @operation, nil
    value = operation.call
    @result = [value, nil] unless @closed
  rescue StandardError => error
    @result = [nil, error] unless @closed
  end
  def take; result, @result = @result, nil; result; end
  def close; @closed = true; @result = nil; end
end
ChannelParticipant = Struct.new(:id, :user)
ChannelMessage = Struct.new(:sender, :data)
class ChannelSession
  attr_reader :id, :participants, :self_id, :sent, :invites
  attr_accessor :state, :leave_error
  def initialize(id, viewer, names)
    @id, @state, @self_id = id, :open, names.index(viewer)
    @participants = names.each_with_index.map { |user, i| ChannelParticipant.new(i, user) }
    @sent, @invites = [], []
  end
  def send_unreliable(data, to:); @sent << [data, to.map(&:user)]; end
  def invite(user); @invites << user; end
  def on_unreliable(&block); @receiver = block; end
  def on_owner_changed(&block); @owner_changed = block; end
  def deliver(user, data); @receiver.call(ChannelMessage.new(ChannelParticipant.new(99, user), data)); end
  def transfer; @owner_changed.call(ChannelParticipant.new(7, 'Mallory')); end
  def close; @state = :closed; end
  def leave; raise 'departure failure' if @leave_error; close; end
end
class ChannelEndpoint
  attr_reader :creates, :closes
  attr_accessor :create_hook
  def initialize(viewer)
    @viewer, @creates, @closes = viewer, [], 0
  end
  def closed?; @closes > 0; end
  def close; @closes += 1; @created&.close; end
  def create_session(**args)
    @creates << args
    @create_hook&.call
    @created = ChannelSession.new('native-session', @viewer, [@viewer])
  end
  def on_invitation(&block); @invitation_handler = block; end
  def next_invitation(timeout:); raise 'blocking invitation poll' unless timeout == 0; (@queue ||= []).shift; end
  def enqueue(invitation); (@queue ||= []) << invitation; end
  def deliver(invitation); @invitation_handler.call(invitation); end
end
class ChannelProgram
  attr_reader :endpoints, :released
  attr_accessor :creation_hook
  def initialize(viewer); @viewer, @endpoints, @released = viewer, [], []; end
  def communication
    @creation_hook&.call
    @endpoints << ChannelEndpoint.new(@viewer)
    @endpoints.last
  end
  def release(endpoint); @released << endpoint; end
end
class ChannelInvitation
  attr_reader :sender, :session_metadata, :status, :accepts
  def initialize(session, sender: 'Alice', metadata: {'gr_realtime' => 1, 'match' => 'match'})
    @session, @sender = session, ChannelParticipant.new(0, sender)
    @session_metadata, @status, @accepts = metadata, :pending, 0
  end
  def accept; @accepts += 1; @status = :accepted; @session; end
end

now = 0.0
work, program = ChannelWork.new, ChannelProgram.new('Alice')
members = %w[Alice Bob Watcher bot:local]
channel = GameRoomRealtime::Channel.new(program: program, match: 'match', owner: 'Alice', viewer: 'Alice',
  clock: -> { now }, members: -> { members }, work: work)
channel.tick
assert(work.operation && program.endpoints.empty?, 'endpoint setup blocked caller')
work.finish
endpoint = program.endpoints.first
channel.tick
work.finish
channel.tick
assert(channel.connected?, 'session not attached')
assert(endpoint.creates == [{metadata: {'gr_realtime' => 1, 'match' => 'match'}, capacity: 32, public: false, encryption: 192}], 'wrong native create contract')
session = channel.instance_variable_get(:@session)
assert(work.operation && session.invites.empty?, 'invitation sent on UI thread')
work.finish
channel.tick
work.finish
assert(session.invites == %w[Bob Watcher], 'invites missing/duplicated or bot invited')
session.participants << ChannelParticipant.new(1, 'Bob') << ChannelParticipant.new(2, 'Watcher') << ChannelParticipant.new(3, 'Mallory')
payload = ->(seq, epoch = channel.epoch, kind = 'input') {
  GameRoomRealtime::Protocol.encode(match: 'match', epoch: epoch, sequence: seq, kind: kind, body: {'move' => 1})
}
session.deliver('Mallory', payload.call(3))
session.deliver('Bob', payload.call(4, 'old'))
session.deliver('Bob', payload.call(4, channel.epoch, 'state'))
assert(channel.take_packets.empty?, 'foreign sender/epoch/kind accepted')
100.times { |i| session.deliver('Bob', payload.call(i)) }
session.deliver('Watcher', payload.call(8))
packets = channel.take_packets
assert(packets.keys.sort == %w[bob watcher] && packets['bob']['n'] == 99, 'inbox not bounded latest-per-member')
session.deliver('Bob', payload.call(90))
assert(channel.take_packets.empty?, 'old sequence accepted after draining queue')
channel.send('state')
assert(session.sent.last == ['state', %w[Bob Watcher]], 'sent to uninvited or local participant')
assert(!channel.send('x' * 1201), 'oversized packet sent')
members.delete('Watcher')
session.deliver('Watcher', payload.call(999))
assert(channel.take_packets.empty?, 'removed member still authorized')
session.transfer
channel.tick
assert(endpoint.closed? && !channel.connected? && channel.epoch.nil?, 'owner transfer adopted rather than reset')
channel.close
assert(endpoint.closes == 1 && program.released == [endpoint], 'endpoint double close/leaked ownership')

# A native connection failure closes its endpoint without Channel#reconnect.
# Its registry entry must be released before a new endpoint replaces it.
now = 0.0
work, program = ChannelWork.new, ChannelProgram.new('Alice')
channel = GameRoomRealtime::Channel.new(program: program, match: 'match', owner: 'Alice', viewer: 'Alice',
  clock: -> { now }, members: -> { ['Alice'] }, work: work)
channel.tick; work.finish; channel.tick; work.finish; channel.tick
failed_endpoint = program.endpoints.first
failed_endpoint.close
now = 10.0
channel.tick
assert(program.released == [failed_endpoint] && channel.epoch.nil?, 'native closed endpoint retained in registry')
work.finish; channel.tick; work.finish; channel.tick
assert(channel.connected? && program.endpoints.length == 2, 'native failure did not reopen')
channel.close
assert(program.released == program.endpoints && failed_endpoint.closes == 1, 'native endpoint cleanup repeated or missing')

# A guest accepts only the matching table owner, replaces a stale session even
# if leaving the old one fails, and sends inputs only to the authority.
now = 0.0
work, program = ChannelWork.new, ChannelProgram.new('Bob')
guest = GameRoomRealtime::Channel.new(program: program, match: 'match', owner: 'Alice', viewer: 'Bob',
  clock: -> { now }, members: -> { %w[Alice Bob Watcher] }, work: work)
guest.tick; work.finish; guest.tick
endpoint = program.endpoints.first
session = ChannelSession.new('first', 'Bob', %w[Alice Bob Watcher])
bad = ChannelInvitation.new(session, sender: 'Watcher')
endpoint.deliver(bad); guest.tick
assert(!work.operation && bad.accepts.zero?, 'forged invitation accepted')
bad = ChannelInvitation.new(session, metadata: {'gr_realtime' => 1, 'match' => 'different-table'})
endpoint.deliver(bad); guest.tick
assert(!work.operation && bad.accepts.zero?, 'other-table invitation accepted')
good = ChannelInvitation.new(session)
endpoint.enqueue(good); guest.tick; work.finish; guest.tick
assert(guest.connected? && good.accepts == 1, 'valid private invitation ignored')
guest.send('input')
assert(session.sent.last == ['input', ['Alice']], 'guest sent to observer')
state = GameRoomRealtime::Protocol.encode(match: 'match', epoch: guest.epoch, sequence: 1, kind: 'state', body: {})
session.deliver('Alice', state)
replacement = ChannelSession.new('second', 'Bob', %w[Alice Bob])
invite = ChannelInvitation.new(replacement)
endpoint.deliver(invite); guest.tick
assert(invite.accepts.zero? && !work.operation, 'healthy session replaced by duplicate invitation')
now = 3.0
session.deliver('Alice', state) # replay must not keep a dead stream healthy.
session.leave_error = true
endpoint.deliver(invite); guest.tick; work.finish; guest.tick
assert(guest.connected? && guest.epoch == Digest::SHA256.hexdigest('second')[0, 16], 'replacement lost due to old leave failure')
session.deliver('Alice', state)
assert(guest.take_packets.empty?, 'old session callback fed replacement')
guest.close
assert(program.released == [endpoint] && endpoint.closes == 1, 'guest leaked endpoint')

# Close before/during/after finite creation: no orphan endpoints, including a
# queued result not yet consumed by the form. Never kill the worker thread.
3.times do |when_close|
  work, program = ChannelWork.new, ChannelProgram.new('Alice')
  resource = GameRoomRealtime::Channel.new(program: program, match: 'race', owner: 'Alice', viewer: 'Alice',
    clock: -> { 0.0 }, members: -> { ['Alice'] }, work: work)
  program.creation_hook = -> { resource.close } if when_close == 1
  resource.tick
  resource.close if when_close.zero?
  work.finish
  resource.close if when_close == 2
  resource.tick
  endpoint = program.endpoints.first
  assert(endpoint.closed? && endpoint.closes == 1 && program.released == [endpoint], "creation race leaked endpoint #{when_close}")
end
puts 'PASS realtime Channel: async setup/invites, authenticated private routing, bounded inbox, stale replacement, cleanup races'
