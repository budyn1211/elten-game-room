module GameRoomBots
  # A deterministic work limit keeps searches responsive and reproducible.
  # Yielding periodically also leaves audio and other Ruby tasks time to run.
  class SearchBudget
    class Exhausted < StandardError; end

    attr_reader :nodes, :limit, :yields

    COOPERATIVE_YIELD_INTERVAL = 0.005

    def initialize(limit:, yield_interval: COOPERATIVE_YIELD_INTERVAL)
      @limit = [limit.to_i, 1].max
      @yield_interval = [yield_interval.to_f, 0.0].max
      @nodes = 0
      @yields = 0
      @next_yield_at = monotonic_time + @yield_interval
    end

    def visit!
      raise Exhausted if @nodes >= @limit

      @nodes += 1
      cooperate!
    end

    def cooperate!
      now = monotonic_time
      return if @yield_interval > 0.0 && now < @next_yield_at

      Thread.pass
      @yields += 1
      @next_yield_at = monotonic_time + @yield_interval
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rescue Exception
      Time.now.to_f
    end
  end

  # Iterative alpha-beta search for deterministic perfect-information games.
  # It uses the production simulation instead of copying any game's rules.
  class AlphaBetaStrategy
    attr_reader :last_stats

    def initialize(max_depth:, node_limit:, fallback: HeuristicStrategy.new)
      @max_depth = [max_depth.to_i, 1].max
      @node_limit = [node_limit.to_i, 1].max
      @fallback = fallback
      @last_stats = {}
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, simulation: nil, **_extra)
      if simulation == nil || !game.perfect_information?
        return fallback_choice(actions, actor, random_source, game, replay, context)
      end

      choices = actions.to_a
      return nil if choices.empty?
      return choices.first if choices.length == 1

      budget = SearchBudget.new(limit: @node_limit)
      best_action = nil
      completed_depth = 0
      (1..@max_depth).each do |depth|
        begin
          candidate = root_search(
            simulation,
            choices,
            actor,
            game,
            context,
            depth,
            budget,
            {}
          )
          best_action = candidate if candidate != nil
          completed_depth = depth
        rescue SearchBudget::Exhausted
          break
        end
      end
      @last_stats = {
        nodes: budget.nodes,
        cooperative_yields: budget.yields,
        completed_depth: completed_depth,
        node_limit: budget.limit
      }
      best_action || fallback_choice(choices, actor, random_source, game, replay, context)
    end

    private

    def root_search(environment, actions, root_actor, game, context, depth, budget, cache)
      ordered = ordered_actions(actions, environment.replay, root_actor, game, context)
      best_action = nil
      best_value = -Float::INFINITY
      alpha = -Float::INFINITY
      ordered.each do |action|
        branch = environment.fork
        next if branch.step(action, actor: root_actor) != :ok

        value = search(branch, depth - 1, alpha, Float::INFINITY, root_actor, game, context, budget, cache)
        if best_action == nil || value > best_value
          best_action = action
          best_value = value
        end
        alpha = [alpha, best_value].max
      end
      best_action
    end

    def search(environment, depth, alpha, beta, root_actor, game, context, budget, cache)
      budget.visit!
      replay = environment.replay
      if replay.finished?
        reward = game.bot_reward(replay, root_actor).to_f
        return reward * 1_000_000.0 + reward * depth.to_i
      end
      return game.bot_position_value(replay, root_actor).to_f if depth <= 0

      moving_actor = environment.active_actor
      actions = environment.legal_actions(moving_actor)
      return game.bot_position_value(replay, root_actor).to_f if moving_actor == nil || actions.empty?

      key = [game.bot_search_key(replay, root_actor), moving_actor.to_s.downcase, depth]
      cached = cache[key]
      return cached if cached != nil

      maximizing = game.bot_allied?(replay, root_actor, moving_actor)
      value = maximizing ? -Float::INFINITY : Float::INFINITY
      cutoff = false
      ordered_actions(actions, replay, moving_actor, game, context).each do |action|
        branch = environment.fork
        next if branch.step(action, actor: moving_actor) != :ok

        child = search(branch, depth - 1, alpha, beta, root_actor, game, context, budget, cache)
        if maximizing
          value = [value, child].max
          alpha = [alpha, value].max
        else
          value = [value, child].min
          beta = [beta, value].min
        end
        if beta <= alpha
          cutoff = true
          break
        end
      end
      value = game.bot_position_value(replay, root_actor).to_f if !value.finite?
      cache[key] = value if !cutoff
      value
    end

    def ordered_actions(actions, replay, actor, game, context)
      actions.to_a.sort_by do |action|
        [
          -game.bot_action_score(replay, actor, action, context: context).to_f,
          game.bot_action_key(action)
        ]
      end
    end

    def fallback_choice(actions, actor, random_source, game, replay, context)
      GameRoomBots.choose(@fallback, {
        actions: actions,
        observation: game.bot_observation(replay, actor),
        actor: actor,
        random_source: random_source,
        game: game,
        replay: replay,
        context: context
      })
    end
  end
end
