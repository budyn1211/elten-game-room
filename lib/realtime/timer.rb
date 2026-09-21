module GameRoomRealtime
  # The native FormTimer uses wall time. A match must not jump when the PC
  # clock changes; keep the existing form lifecycle but use a monotonic clock.
  class Timer < FormTimer
    def initialize(clock:, interval: 0.008, &block)
      @clock, @interval, @callback = clock, interval, block
      super(interval, repeat: true, autostart: false)
      start
    end

    def start; @due = @clock.call; end
    def stop; @due = nil; end
    def update
      return unless @due
      now = @clock.call
      return if now < @due
      @due = now + @interval
      @callback.call
    end
  end
end
