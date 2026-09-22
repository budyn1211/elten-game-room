require_relative 'engine'

module GameRoomPong
  # Active original network model: each human owns their paddle, returns and
  # misses. BE starts a new incoming flight at the far baseline, not a predicted
  # current Y. Original P/BD/BX keep the same X axis on both machines.
  class PeerEngine < Engine
    def initialize(side:, authority:, **args)
      super(**args)
      @side, @authority = side, authority
    end

    def strike(side, **args)
      return false unless side == @side
      serving = @ball['dy'].zero?
      return false unless super
      transition(serving ? 'serve' : 'hit', side)
      true
    end

    # AH is processed by the channel owner, not by both RNGs independently.
    def roll_effects(_side); end

    def host_effects(side)
      return unless @authority && @arcade && !@goal
      renewal = @rng.rand < 0.07
      invisible = @rng.rand < 0.07
      data = {'action' => 'effects', 'side' => side, 'turn' => @turn,
        'renew' => renewal, 'invisible' => invisible}
      apply_effects(data)
      data
    end

    def apply_effects(data)
      return false unless data['turn'] <= @turn && !@goal
      side = data['side']
      if data['renew']
        @shields[side] = 625
        cue('shield_on', side)
      end
      if data['turn'] == @turn && data['invisible']
        @invisible = true
        cue('invisible', side)
      end
      true
    end

    def apply_return(data)
      return false unless data['turn'] == @turn + 1 && !@goal
      side = data['side']
      return false unless @turn.zero? ? side == @server && data['action'] == 'serve' :
        incoming?(side) && %w[hit shield_hit].include?(data['action'])
      @turn = data['turn']
      @ball.merge!(data['ball'])
      @ball['x'] = @ball['x'].clamp(MIN_X, MAX_X)
      @ball['y'] = @rotation.team(side).zero? ? 0.0 : DEPTH
      @ball['dy'] = @rotation.team(side).zero? ? 1 : -1
      @previous_inbound = Array.new(@paddles.length)
      @invisible = false unless data['action'] == 'shield_hit'
      cue(data['action'], side)
      true
    end

    def apply_miss(data)
      return false unless data['turn'] == @turn + 1 && !@goal && incoming?(data['side'])
      Engine.instance_method(:miss).bind(self).call(data['side'])
      true
    end

    def wall_sound(x, y)
      append_cue('wall', nil, x, y)
    end

    def serve_timeout(confirmed: false)
      # A direct serve can cross the owner's authoritative deadline in transit.
      # The owner's confirmed timeout wins that race, but cannot override an
      # already exchanged return or be applied twice.
      late_serve = confirmed && @turn == 1 &&
        @ball['dy'] == (@rotation.team(@server).zero? ? 1 : -1)
      return false unless !@goal && ((@turn.zero? && @ball['dy'].zero?) || late_serve)
      @turn = 0
      @transition = nil
      Engine.instance_method(:miss).bind(self).call(@server)
      true
    end

    def take_transition
      value, @transition = @transition, nil
      value
    end

    private

    def controls_side?(side); side == @side; end

    def miss(side)
      super
      transition('goal', side)
    end

    def shield_return(side)
      super
      transition('shield_hit', side)
    end

    def transition(action, side)
      # Original BD/BS/BQ/BX messages encode thousandths, truncating rather
      # than rounding. Local physics keeps its full precision.
      transmitted = @ball.transform_values { |v| v.is_a?(Float) ? (v * 1000).to_i / 1000.0 : v }
      @transition = {'action' => action, 'side' => side, 'turn' => @turn, 'ball' => transmitted}
    end

    def cue(kind, side)
      return if kind == 'wall' && !@authority
      super
    end

    def append_cue(kind, side, x, y)
      @event_seq += 1
      @events << [@event_seq, kind, side, x, y]
      @events.shift while @events.length > 8
    end
  end
end
