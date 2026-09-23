require_relative 'engine'

module GameRoomAudioBall
  class Bot
    HOLD_DELAY = [0.35, 0.25, 0.18, 0.18].freeze
    REACTION_TIME = [0.25, 0.18, 0.12, 0.12].freeze
    ERROR_CHANCE = [0.24, 0.14, 0.06, 0.06].freeze
    attr_reader :side

    def initialize(side, level: 1, rng: Random.new)
      raise ArgumentError, 'side must be 0 or 1' unless side.is_a?(Integer) && (side == 0 || side == 1)
      raise ArgumentError, 'level must be an integer from 1 to 4' unless level.is_a?(Integer) && (1..4).include?(level)
      @side = side
      @selected_lane = nil
      @level = level
      @rng = rng
      @engine = nil
      @turn = nil
    end

    def selected_lane(engine = @engine)
      @selected_lane if engine && @engine.equal?(engine) && @turn == engine.turn &&
        engine.phase == :flying && engine.receiver == @side
    end

    def step(engine, seconds:)
      unless (seconds.is_a?(Integer) || seconds.is_a?(Float)) && seconds.finite? && seconds >= 0
        raise ArgumentError, 'seconds must be finite and nonnegative'
      end
      plan(engine) if !@engine.equal?(engine) || @turn != engine.turn
      @elapsed += seconds
      if engine.phase == :flying && engine.receiver == @side
        return false if @attempted || @elapsed < REACTION_TIME[@level - 1]
        endpoint = @side == 0 ? Engine::WIDTH : 0.0
        return false if (engine.position - endpoint).abs > @distance
        @attempted = true
        @selected_lane = @command
        return engine.press(@side, @selected_lane)
      end
      return false unless engine.holder == @side && @elapsed >= @delay
      case engine.phase
      when :waiting
        engine.press(@side, 'prepare')
      when :prepared
        engine.press(@side, Engine::SHOTS[@rng.rand(Engine::SHOTS.length)])
      else
        false
      end
    end

    private

    def plan(engine)
      @engine = engine
      @turn = engine.turn
      @elapsed = 0.0
      @attempted = false
      @selected_lane = nil
      if engine.phase == :flying && engine.receiver == @side
        @distance = 0.5 + @rng.rand * 1.4
        @command = engine.shot
        if @rng.rand < ERROR_CHANCE[@level - 1]
          alternatives = Engine::SHOTS.reject { |shot| shot == engine.shot }
          @command = alternatives[@rng.rand(alternatives.length)]
        end
      else
        @delay = HOLD_DELAY[@level - 1] + @rng.rand * 0.15
      end
    end
  end
end
