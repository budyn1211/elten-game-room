require_relative 'realtime_event_channel'

class QueuedChannelSession < ChannelSession
  attr_reader :polls, :native_queue
  def initialize(*args)
    super
    @native_queue, @callbacks, @polls = [], [], 0
  end
  def receive(timeout:)
    raise 'receive must never wait/pump the UI' unless timeout == 0
    @polls += 1
    @native_queue.shift
  end
  def arrive(kind, user, data)
    message = ChannelMessage.new(ChannelParticipant.new(99, user), data)
    @native_queue << [kind, message]
    @callbacks << [kind, message]
  end
  def dispatch
    callbacks, @callbacks = @callbacks, []
    callbacks.each { |kind, message| (kind == :reliable ? @event_receiver : @receiver).call(message) }
  end
end
