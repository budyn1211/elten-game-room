module GameRoomRealtime
  # Local durations only. No payloads, user names, wall clocks, extra network
  # probes or per-frame disk writes. Endpoint latency is a cached UDP relay RTT,
  # not peer-action latency and not the HTTP/LiveSessions confirmation time.
  class Metrics
    INTERVAL = 10.0
    KEYS = %i[tick_gap queue_wait send_rpc receive_wait].freeze

    def initialize(clock:)
      @clock = clock
      @next_report = clock.call + INTERVAL
      @maxima = {}
    end

    def observe(key, seconds)
      return unless KEYS.include?(key) && seconds.is_a?(Numeric) && seconds.finite? && seconds >= 0
      @maxima[key] = [@maxima.fetch(key, 0.0), seconds].max
    end

    def tick(endpoint:, role:, generation:)
      now = @clock.call
      observe(:tick_gap, now - @last_tick) if @last_tick
      @last_tick = now
      return unless now >= @next_report
      @next_report = now + INTERVAL
      values, @maxima = @maxima, {}
      return unless defined?(Log) && Log.respond_to?(:debug) && endpoint && !endpoint.closed?
      fast = endpoint.respond_to?(:fast_path?) && endpoint.fast_path?
      latency = endpoint.latency if fast && endpoint.respond_to?(:latency)
      rtt = latency.is_a?(Numeric) && latency.finite? && latency >= 0 ? (latency * 1000).round : 'unavailable'
      fields = KEYS.map { |key| "#{key}_max_ms=#{values.key?(key) ? (values[key] * 1000).round : 'unavailable'}" }
      Log.debug("Game Room Communications metrics role=#{role} generation=#{generation} relay_udp_rtt_ms=#{rtt} position_path=#{fast ? 'udp' : 'tcp_or_unknown'} #{fields.join(' ')}")
    end
  end
end
