require "thread"
require_relative "network_errors"

# The only wall-clock fallback is for offline tools/tests before a connection.
# Online entry points synchronize on an existing network/background task.
# Reading a clock, moving focus or announcing a notification NEVER sends HTTP.
module GameRoomClock
  CLOCK_LOCK = Mutex.new
  class Clock
    REFRESH_AFTER = 300.0
    RETRY_AFTER = 60.0

    def initialize(fetch: nil, elapsed: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      wall: -> { Time.now.to_f })
      @fetch, @elapsed, @wall = fetch, elapsed, wall
      @lock, @refresh_lock = Mutex.new, Mutex.new
    end

    def now
      @lock.synchronize do
        @anchor ? @anchor[0] + @elapsed.call - @anchor[1] : @wall.call.to_f
      end
    end

    def synchronized?
      @lock.synchronize { @anchor != nil }
    end

    def synchronize
      return now unless @fetch
      @refresh_lock.synchronize do
        if @retry_at && @elapsed.call < @retry_at
          raise @last_error unless synchronized?
          return now
        end
        fresh = @lock.synchronize { @anchor && @elapsed.call - @anchor[1] < REFRESH_AFTER }
        return now if fresh
        begin
          stamp = @fetch.call
          value = stamp.is_a?(Time) || stamp.is_a?(Numeric) ? stamp.to_f : 0
          raise GameRoomNetworkErrors::ClockUnavailable, "Invalid server clock" unless value.finite? && value > 0
          @lock.synchronize { @anchor = [value, @elapsed.call] }
          @retry_at = @last_error = nil
        rescue StandardError => error
          raise if defined?(EltenAPI::Tasks::Cancelled) && error.is_a?(EltenAPI::Tasks::Cancelled)
          raise unless GameRoomNetworkErrors.expected?(error) || error.is_a?(IOError) || error.is_a?(SystemCallError)
          @retry_at, @last_error = @elapsed.call + RETRY_AFTER, error
          # A connection gap must not replace a confirmed clock with the OS clock.
          raise unless synchronized?
        end
      end
      now
    end
  end

  class << self
    def clock
      return @clock if @clock
      CLOCK_LOCK.synchronize { @clock ||= build_clock }
    end

    def build_clock
      Clock.new(fetch: -> {
        # Do not use the host helper's Time.now fallback for invalid replies.
        response = EltenLink::Client.new.api_data("GET", "/api/v1/system/time", nil, timeout: 5)
        value = response.is_a?(Hash) ? response["time"] : nil
        raise GameRoomNetworkErrors::ClockUnavailable, "Invalid server clock" unless value.is_a?(Numeric) && value > 0
        value
      }, wall: -> {
        sample = EltenAPI::NotificationService.server_time if defined?(EltenAPI::NotificationService) && EltenAPI::NotificationService.respond_to?(:server_time)
        sample.to_f > 0 ? sample.to_f : Time.now.to_f
      })
    end
    private :build_clock

    def server_available?
      defined?(EltenLink::System) && EltenLink::System.respond_to?(:server_time) && defined?(EltenLink::Client)
    end

    def synchronize; server_available? ? clock.synchronize : now; end
    def now; clock.now; end
    def synchronized?; clock.synchronized?; end
  end
end
