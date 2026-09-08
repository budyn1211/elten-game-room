module GameRoomSync
  ERROR_BACKOFF = 30.0
  RATE_LIMIT_BACKOFF = 60.0

  Event = Struct.new(:kind, :session_id, :received_at, keyword_init: true)

  class Controller
    attr_reader :table_id, :session_id, :next_reconcile_at

    def initialize(
      transport:,
      table_id:,
      session_id: 0,
      reconnect: nil,
      clock: nil,
      error_backoff: ERROR_BACKOFF,
      rate_limit_backoff: RATE_LIMIT_BACKOFF
    )
      @transport = transport
      @table_id = positive_identifier(table_id)
      raise ArgumentError, "a synchronizer requires a positive table id" if @table_id <= 0

      @session_id = positive_identifier(session_id)
      @error_backoff = positive_duration(error_backoff, "error_backoff")
      @rate_limit_backoff = positive_duration(rate_limit_backoff, "rate_limit_backoff")
      @reconnect = reconnect
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      synchronized!
    end

    def update_session(session_id, discard_pending: false)
      @session_id = positive_identifier(session_id)
      @transport.consume_game_change(@session_id) if discard_pending && @session_id > 0
      self
    end

    def next_event(idle:, allow_recovery: true)
      # Form#resume performs one last host input update before the old form is
      # discarded.  Do not consume a wake-up while a key is active, otherwise
      # a character queued by that final update can be spoken but never reach
      # the replacement edit field.
      return nil if !idle

      if @transport.respond_to?(:consume_recovery) && @transport.consume_recovery(@table_id)
        return Event.new(kind: :recovery, session_id: @session_id) if allow_recovery

        request_recovery!
      end

      started_session_id = @transport.consume_game_start(@table_id)
      if started_session_id != nil && started_session_id.to_i > 0 && started_session_id.to_i != @session_id
        return Event.new(kind: :game_started, session_id: started_session_id.to_i)
      end

      if @session_id > 0
        received_at = @transport.consume_game_change(@session_id)
        if received_at != nil && received_at != false
          return Event.new(kind: :game_changed, session_id: @session_id, received_at: received_at)
        end
      end

      if @transport.consume_table_change(@table_id)
        return Event.new(kind: :table_changed, session_id: @session_id)
      end

      return nil if !@recovery_pending || !allow_recovery || now < @next_reconcile_at

      @recovery_pending = false
      @next_reconcile_at = Float::INFINITY
      Event.new(kind: :recovery, session_id: @session_id)
    end

    def synchronize
      @reconnect&.call
      result = yield
      synchronized!
      result
    rescue StandardError => error
      failed!(error)
      raise
    end

    def synchronized!
      @recovery_pending = false
      @next_reconcile_at = Float::INFINITY
      self
    end

    def failed!(error)
      delay = rate_limited?(error) ? @rate_limit_backoff : @error_backoff
      @recovery_pending = true
      @next_reconcile_at = now + delay
      self
    end

    def request_recovery!(delay: 0)
      @recovery_pending = true
      @next_reconcile_at = now + [delay.to_f, 0.0].max
      self
    end

    private

    def now
      @clock.call.to_f
    end

    def positive_identifier(value)
      [value.to_i, 0].max
    end

    def positive_duration(value, name)
      duration = Float(value)
      raise ArgumentError, "#{name} must be finite and greater than zero" if !duration.finite? || duration <= 0

      duration
    rescue TypeError, ArgumentError
      raise ArgumentError, "#{name} must be finite and greater than zero"
    end

    def rate_limited?(error)
      error.message.to_s.match?(/(?:too many requests|rate.?limit|\b429\b)/i)
    end
  end
end
