# Translate the host's already received server time to the founder's game
# epoch. No HTTP, no clock tolerance and no change to saved/wire timestamps.
class GameRoomSessionClock
  def self.from_server(session, time)
    started = session["__server_started_at"].to_i
    epoch = session["created_at"].to_i
    shift = started.positive? && epoch.positive? ? epoch - started : 0
    (time + shift - session["__clock_offset"].to_i).to_i
  end

  def initialize(sample: -> {
    EltenAPI::NotificationService.server_time if defined?(EltenAPI::NotificationService) &&
      EltenAPI::NotificationService.respond_to?(:server_time)
  }, elapsed: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, wall: -> { Time.now.to_f })
    @sample, @elapsed, @wall = sample, elapsed, wall
    @lock = Mutex.new
  end

  def now(session)
    now_f(session).to_i
  end

  # Opt-in precision for time-scored games. Existing games keep integer time.
  def now_f(session)
    @lock.synchronize do
      tick = refresh
      offset = session["__clock_offset"].to_i
      frozen = session["__frozen_at"]
      started = session["__server_started_at"].to_i
      if @server_anchor && started.positive? && session["created_at"].to_i.positive?
        current = frozen || (@server_anchor.first + tick - @server_anchor.last)
        current.to_f + session["created_at"].to_i - started - offset
      else
        # Offline/old repository compatibility, still immune to wall-clock
        # changes while the screen is open. The encoder enforces causal time.
        (frozen || (@local_anchor.first + tick - @local_anchor.last)).to_f - offset
      end
    end
  end

  # A push acknowledgement may contain only its sequence number. Until the
  # native metadata arrives, estimate a clock boundary in server time, never
  # label the founder's local wall time as an authoritative server timestamp.
  def server_now
    @lock.synchronize do
      tick = refresh
      anchor = @server_anchor || @local_anchor
      (anchor.first + tick - anchor.last).to_i
    end
  end

  private

  def refresh
    tick = @elapsed.call.to_f
    sample = @sample.call.to_f
    if sample.positive? && sample != @last_sample
      @server_anchor = [sample, tick]
      @last_sample = sample
    end
    @local_anchor ||= [@wall.call.to_f, tick]
    tick
  end
end
