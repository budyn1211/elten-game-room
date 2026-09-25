require 'thread'

# Bounded, short-lived snapshot for bulk candidate discovery. No speculative
# query operators, per-user HTTP loop or background polling. Failed refreshes
# propagate and invalidate the snapshot rather than becoming an empty result.
class GameRoomTableQuerySnapshot
  TTL = 15.0
  MAX_ROWS = 4096

  def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @clock, @mutex = clock, Mutex.new
  end

  def fetch
    @mutex.synchronize do
      return @rows if @rows && @clock.call < @expires
      @rows = nil
      rows = yield
      if rows.length <= MAX_ROWS
        @rows = rows.map { |row| row.transform_values { |value| value.is_a?(String) ? value.dup.freeze : value }.freeze }.freeze
        @expires = @clock.call + TTL
        @rows
      else
        rows
      end
    end
  end

  def invalidate
    @mutex.synchronize { @rows = nil }
  end
end
