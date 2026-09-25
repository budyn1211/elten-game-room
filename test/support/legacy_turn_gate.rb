require_relative '../../lib/bot_turn_gate'

# Historical fixed pacing, retained only for the build-137 regression.
module GameRoomBots
  class TurnGate
    def initialize(interval: 1.0, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @interval = interval
      @clock = clock
      @mutex = Mutex.new
      @lease = nil
      @ready_at = 0.0
    end

    def ready?
      @mutex.synchronize { @lease == nil && @clock.call >= @ready_at }
    end

    def acquire
      @mutex.synchronize do
        return nil if @lease != nil || @clock.call < @ready_at

        @lease = Object.new
      end
    end

    def release(lease, attempted: false)
      @mutex.synchronize do
        return if lease == nil || !@lease.equal?(lease)

        @ready_at = @clock.call + @interval if attempted
        @lease = nil
      end
    end
  end
end
