require 'json'

module GameRoomRealtime
  # Replaceable snapshots/inputs and the optional reliable event lane. Neither
  # is a durable game log: LiveSessions remains the authority for saved scores.
  module Protocol
    VERSION = 1
    MAX_BYTES = 1100 # Below Communications' 1200 byte unreliable payload limit.
    MAX_SEQUENCE = 2**53 - 1
    module_function

    def encode(match:, epoch:, sequence:, kind:, body:, ack: 0)
      value = { 'v' => VERSION, 'm' => match, 'e' => epoch, 'n' => sequence,
        'k' => kind, 'a' => ack, 'd' => body }
      data = JSON.generate(value)
      raise ArgumentError, 'realtime packet too large' if data.bytesize > MAX_BYTES
      data
    end

    def decode(data, match:, epoch:)
      return nil unless data.is_a?(String) && data.bytesize <= MAX_BYTES
      value = JSON.parse(data, max_nesting: 10, create_additions: false)
      return nil unless value.is_a?(Hash) && value['v'] == VERSION && value['m'] == match && value['e'] == epoch
      return nil unless %w[state input event].include?(value['k']) && value['d'].is_a?(Hash)
      return nil unless [value['n'], value['a']].all? { |n| n.is_a?(Integer) && n.between?(0, MAX_SEQUENCE) }
      value
    rescue JSON::ParserError, EncodingError
      nil
    end
  end

  class PeerState
    attr_reader :sequence, :ack, :received_at, :ack_updated_at, :body

    def initialize
      @sequence, @ack = -1, 0
      @received_at = nil
      @body = nil
    end

    def receive(packet, now:, last_sent:)
      return false unless packet['n'] > @sequence && packet['a'] <= last_sent
      @sequence = packet['n']
      @ack_updated_at = now if packet['a'] > @ack
      @ack = [@ack, packet['a']].max
      @received_at, @body = now, packet['d']
      true
    end

    def fresh?(now, timeout: 0.6)
      @received_at != nil && now - @received_at <= timeout && now >= @received_at
    end

    def ack_fresh?(now, timeout: 0.6)
      @ack_updated_at != nil && now - @ack_updated_at <= timeout && now >= @ack_updated_at
    end
  end
end
