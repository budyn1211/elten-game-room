require_relative 'channel'

module GameRoomRealtime
  # Optional ordered lane for actions which cannot be replaced by a newer
  # position. Reliable RPC is finite background work, never a wait in a frame.
  class EventChannel < Channel
    LIMIT = 128
    attr_writer :required_members

    def initialize(event_work: nil, event_work_factory: nil, **args)
      super(**args)
      @event_work = Operation.new(clock: @clock, work: event_work, factory: event_work_factory)
      @event_outbox, @event_inbox = [], []
      @deliveries = []
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
        elsif value.is_a?(Array) && value[0] == @event_generation && value[2].respond_to?(:results)
          @deliveries << [value[2], @clock.call, value[3]]
        end
      end
      if @event_work.expired?
        @last_error = 'ReliableSendTimeout'
        trace('reliable_send_timeout')
        reconnect
      end
      @deliveries.delete_if do |delivery, started_at, required_ids|
        statuses = delivery.results.select do |recipient, _status|
          id = recipient.respond_to?(:id) ? recipient.id.to_s : recipient.to_s
          required_ids.include?(id)
        end.values
        failed = statuses.any? { |status| ![:pending, :delivered].include?(status) }
        expired = statuses.include?(:pending) && @clock.call - started_at >= Operation::TIMEOUT
        if failed || expired
          @last_error = failed ? 'ReliableDeliveryFailed' : 'ReliableDeliveryTimeout'
          trace('delivery_failed', error: @last_error)
          reconnect
          break
        end
        !statuses.include?(:pending)
      end
      return if @closed || @event_work.busy? || @event_outbox.empty?
      if @deliveries.length >= LIMIT
        reconnect
        return
      end
      session, generation, data, targets = @event_outbox.shift
      return unless session.equal?(@session) && generation == @event_generation
      required_ids = targets.select do |target|
        @required_members == nil || @required_members.any? { |name| name.to_s.casecmp?(target.user.to_s) }
      end.map { |target| target.id.to_s }
      @event_work.start(:reliable) do
        begin
          delivery = session.send_reliable(data, to: targets)
          [generation, nil, delivery, required_ids]
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
      return if @reconnect_requested || @closed
      invalidate_events
      @event_work.cancel
      super
    end

    def close
      invalidate_events
      @event_work.close
      super
    end

    private

    def reset_connection(now, **options)
      invalidate_events
      @event_work.cancel
      super
    end

    def invalidate_events
      @event_generation += 1
      @event_outbox.clear
      @event_inbox.clear
      @deliveries.clear
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
        if @event_sequences.key?(key) && packet['n'] != @event_sequences[key] + 1
          @last_error = 'ReliableSequenceGap'
          trace('reliable_sequence_gap')
          reconnect
          next
        end
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
