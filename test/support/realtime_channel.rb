require_relative '../../lib/realtime/channel'

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
