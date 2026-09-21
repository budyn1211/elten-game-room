require_relative 'channel'

module GameRoomRealtime
  # Optional ordered lane for actions which cannot be replaced by a newer
  # position. Reliable RPC is finite background work, never a wait in a frame.
  class EventChannel < Channel
    LIMIT = 128

    def initialize(event_work: nil, **args)
      super(**args)
      @event_work = event_work || GameRoomBackground::Work.new
      @event_outbox, @event_inbox = [], []
      @event_generation = 0
    end

    def enable_events; @event_protocol = 'pong-local-1'; end

    def tick
      super
      if (result = @event_work.take)
        value, error = result
        if value.is_a?(Array) && value[0] == @event_generation && value[1] && !@closed
          @last_error = value[1]
          reconnect
        elsif error && !@closed
          @last_error = error.class.to_s
          reconnect
        end
      end
      return if @closed || @event_work.busy? || @event_outbox.empty?
      session, generation, data, targets = @event_outbox.shift
      return unless session.equal?(@session) && generation == @event_generation
      @event_work.start do
        begin
          session.send_reliable(data, to: targets)
          [generation, nil]
        rescue StandardError => error
          # Keep the generation even on failure: an old send must not tear
          # down a replacement channel which already works.
          [generation, error.class.to_s]
        end
      end
    end

    def send_event(data)
      return false unless @event_protocol && connected? && data.is_a?(String) && data.bytesize <= Protocol::MAX_BYTES
      targets = @session.participants.select do |p|
        p.id != @session.self_id && authorized?(p.user) && (host? || p.user.casecmp?(@owner))
      end
      return true if targets.empty?
      if @event_outbox.length >= LIMIT
        reconnect
        return false
      end
      @event_outbox << [@session, @event_generation, data.dup.freeze, targets]
      true
    end

    def take_events
      result, @event_inbox = @event_inbox, []
      result
    end

    def reconnect
      invalidate_events
      super
    end

    def close
      invalidate_events
      @event_work.close
      super
    end

    private

    def invalidate_events
      @event_generation += 1
      @event_outbox.clear
      @event_inbox.clear
    end

    def metadata
      data = super
      data['events'] = @event_protocol if @event_protocol
      data
    end

    def attach(session)
      super
      invalidate_events
      @event_sequences = {}
      return unless @event_protocol
      session.on_reliable do |message|
        next if @closed || !@session.equal?(session)
        sender = message.sender.user.to_s
        next unless authorized?(sender) && (host? || sender.casecmp?(@owner))
        packet = Protocol.decode(message.data, match: @match, epoch: @epoch)
        next unless packet && packet['k'] == 'event'
        key = sender.downcase
        next if packet['n'] <= @event_sequences.fetch(key, -1)
        if @event_inbox.length >= LIMIT
          reconnect
          next
        end
        @event_sequences[key] = packet['n']
        @event_inbox << [key, packet]
        @last_packet_at = @clock.call
      end
    end
  end
end
