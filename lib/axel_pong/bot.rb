require_relative 'engine'

module GameRoomPong
  class Bot
    # Reaction, minimum reaction, step, speed scale/caps, lateral, error, offset, hitbox.
    LEVELS = [
      [540, 360, 0.52, 0.06, 1.02, 1.03, 0.35, 0.34, 3.2, 3.3],
      [460, 320, 0.66, 0.10, 1.04, 1.05, 0.45, 0.30, 2.8, 3.6],
      [330, 220, 0.95, 0.50, 1.40, 1.30, 0.70, 0.20, 1.8, 4.5],
      [320, 210, 1.00, 0.50, 1.40, 1.30, 0.85, 0.15, 1.8, 4.5],
      [320, 210, 1.00, 0.50, 1.40, 1.30, 1.00, 0.15, 1.8, 4.5],
      [320, 210, 1.00, 0.50, 1.40, 1.30, 1.00, 0.15, 1.8, 4.5]
    ].map(&:freeze).freeze

    def initialize(side, level:, rng: Random.new)
      @side, @rng = side, rng
      @reaction, @minimum, @step, @speed_scale, @step_cap, @react_cap,
        @lateral, @error, @offset, @hitbox = LEVELS.fetch(level - 1)
      @level = level
      @last_reaction = 0
      @target = 15.0
      @serve_plan = nil
      @ready = nil
      @opening = false
      @last_opening_move = 0
    end

    def step(engine)
      engine.register_bot(@side, self)
    end

    def served(engine, opening:)
      @opening = opening
      @last_reaction = @last_opening_move = engine.now_ms
      @target = engine.paddles[@side]
      @serve_plan = @ready = @serve_started = nil
    end

    def prepare(engine)
      return if engine.goal
      prepare_serve(engine) if engine.ball['dy'].zero? && engine.server == @side
    end

    def track(engine)
      return if engine.goal
      return unless engine.incoming?(@side)
      # No access to invisible position for tracking; a blind contact can still hit.
      unless engine.invisible
        ratio = (engine.ball['speed'] / engine.base_speed).clamp(1.0, 3.0)
        delay = [@minimum, (@reaction / [ratio, @react_cap].min).to_i].max
        if engine.now_ms - @last_reaction >= delay
          @target = (engine.ball['x'] + (@rng.rand * 2 - 1) * @offset).clamp(1.0, 29.0)
          @last_reaction = engine.now_ms
        end
        step = @step * [1 + @speed_scale * (ratio - 1), @step_cap].min
        delta = @target - engine.paddles[@side]
        return if delta.abs <= 0.05
        return if @opening && engine.now_ms - @last_opening_move < 48
        @last_opening_move = engine.now_ms if @opening
        return if @rng.rand < @error
        step = [1.0, step].min if @opening
        # Tracking takes a full step, unlike the exact landing on serve targets.
        engine.move_to(@side, engine.paddles[@side] + (delta.positive? ? step : -step))
      end
    end

    def contact(engine)
      @opening = false
      return false unless (engine.ball['x'] - engine.paddles[@side]).abs <= @hitbox
      engine.strike(@side, bot: true, lateral_scale: @lateral)
    end

    private

    def prepare_serve(engine)
      unless @serve_plan
        @serve_started = engine.now_ms
        @serve_delay = (@level == 1 ? 800 : 750) + @rng.rand(401)
        first = choose_target(engine.paddles[@side], 4)
        second = first <= 15 ? 17 + @rng.rand * 10 : 3 + @rng.rand * 10
        @serve_plan = [first, second, choose_target(second, 3)]
      end
      target = @serve_plan.first
      move_toward(engine, target, (@step * 0.75).clamp(0.25, 0.85))
      return if (target - engine.paddles[@side]).abs > 0.05
      if @serve_plan.length > 1
        @serve_plan.shift
        return
      end
      @ready ||= [@serve_started + @serve_delay, engine.now_ms + 140 + @rng.rand(181)].max
      return if engine.now_ms < @ready
      engine.strike(@side, aim: (engine.now_ms / 200).even? ? -1 : 1, bot: true)
    end

    def choose_target(previous, gap)
      8.times do
        value = 3 + @rng.rand * 24
        return value if (value - previous).abs >= gap
      end
      previous < 15 ? 27.0 : 3.0
    end

    def move_toward(engine, target, step)
      delta = target - engine.paddles[@side]
      return engine.move_to(@side, target, silent: true) if delta.abs <= 0.05
      engine.move_to(@side, engine.paddles[@side] + delta.clamp(-step, step))
    end
  end
end
