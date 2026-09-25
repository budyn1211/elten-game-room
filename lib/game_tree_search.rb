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
    TranspositionEntry = Struct.new(:value, :bound, :best_action_key, keyword_init: true)

    attr_reader :last_stats

    def simulation_required?
      true
    end

    def initialize(max_depth:, node_limit:, fallback: HeuristicStrategy.new, optimize_transpositions: false)
      @max_depth = [max_depth.to_i, 1].max
      @node_limit = [node_limit.to_i, 1].max
      @fallback = fallback
      @optimize_transpositions = optimize_transpositions == true
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
      transpositions = {}
      move_order = {}
      preferred_root_action_key = nil
      @search_cache_hits = 0
      @search_cutoffs = 0
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
            @optimize_transpositions ? transpositions : {},
            move_order,
            preferred_root_action_key
          )
          if candidate != nil
            best_action = candidate
            preferred_root_action_key = game.bot_action_key(candidate) if @optimize_transpositions
          end
          completed_depth = depth
        rescue SearchBudget::Exhausted
          break
        end
      end
      @last_stats = {
        nodes: budget.nodes,
        cooperative_yields: budget.yields,
        completed_depth: completed_depth,
        node_limit: budget.limit,
        cache_hits: @search_cache_hits,
        cutoffs: @search_cutoffs
      }
      best_action || fallback_choice(choices, actor, random_source, game, replay, context)
    end

    private

    def root_search(
      environment,
      actions,
      root_actor,
      game,
      context,
      depth,
      budget,
      cache,
      move_order,
      preferred_action_key
    )
      base_order = ordered_actions(actions, environment.replay, root_actor, game, context)
      ordered = if @optimize_transpositions
        prefer_action(base_order, preferred_action_key, game)
      else
        base_order
      end
      best_action = nil
      best_value = -Float::INFINITY
      alpha = -Float::INFINITY
      ordered.each do |action|
        branch = search_branch(environment, action, root_actor)
        next if branch == nil

        value = search(
          branch,
          depth - 1,
          alpha,
          Float::INFINITY,
          root_actor,
          game,
          context,
          budget,
          cache,
          move_order
        )
        if best_action == nil || value > best_value
          best_action = action
          best_value = value
        end
        alpha = [alpha, best_value].max
      end
      if @optimize_transpositions && best_action != nil
        move_order[move_ordering_key(environment.replay, root_actor, root_actor, game)] = game.bot_action_key(best_action)
      end
      best_action
    end

    def search(environment, depth, alpha, beta, root_actor, game, context, budget, cache, move_order)
      replay = environment.replay
      if replay.finished?
        budget.visit!
        reward = game.bot_reward(replay, root_actor).to_f
        return reward * 1_000_000.0 + reward * [depth.to_i, 0].max
      end

      moving_actor = environment.active_actor
      # Finish a move at the horizon, without making every capture/promotion
      # throughout the entire tree a free extra ply. This preserves the old
      # depth/cost contract while avoiding evaluation of an unfinished move.
      forced_continuation = continuation?(game, replay)
      depth = 0 if depth < 0 && forced_continuation
      state_ordering_key = nil
      key = if depth <= 0 && !forced_continuation && game.respond_to?(:bot_evaluation_key)
        [[:evaluation, game.bot_evaluation_key(replay, root_actor)], 0]
      else
        state_ordering_key = ordering_key(replay, root_actor, moving_actor, game)
        [state_ordering_key, depth]
      end

      if cache.key?(key)
        cached = cache[key]
        if cached != nil
          @search_cache_hits += 1
          case cached.bound
          when :exact
            return cached.value
          when :lower
            alpha = [alpha, cached.value].max
          when :upper
            beta = [beta, cached.value].min
          end
          if beta <= alpha
            @search_cutoffs += 1
            return cached.value
          end
        end
      end

      budget.visit!
      if depth <= 0 && !forced_continuation
        if game.respond_to?(:bot_tactical_actions)
          return tactical_search(environment, root_actor, game, context, budget, alpha, beta, 2)
        end
        value = game.bot_position_value(replay, root_actor).to_f
        cache[key] = TranspositionEntry.new(value: value, bound: :exact, best_action_key: nil)
        return value
      end

      actions = environment.legal_actions(moving_actor)
      return game.bot_position_value(replay, root_actor).to_f if moving_actor == nil || actions.empty?

      maximizing = game.bot_allied?(replay, root_actor, moving_actor)
      value = maximizing ? -Float::INFINITY : Float::INFINITY
      original_alpha = alpha
      original_beta = beta
      preferred_action_key = nil
      state_move_ordering_key = nil
      if @optimize_transpositions
        state_move_ordering_key = game.respond_to?(:bot_move_order_key) ? move_ordering_key(replay, root_actor, moving_actor, game) : state_ordering_key
        preferred_action_key = move_order[state_move_ordering_key]
        if cache[key] != nil && cache[key].best_action_key != nil
          preferred_action_key = cache[key].best_action_key
        end
      end
      ordered = prefer_action(
        ordered_actions(actions, replay, moving_actor, game, context),
        preferred_action_key,
        game
      )
      best_action_key = nil
      ordered.each do |action|
        branch = search_branch(environment, action, moving_actor)
        next if branch == nil

        child = search(
          branch,
          depth - 1,
          alpha,
          beta,
          root_actor,
          game,
          context,
          budget,
          cache,
          move_order
        )
        if maximizing
          if !value.finite? || child > value
            value = child
            best_action_key = game.bot_action_key(action)
          end
          alpha = [alpha, value].max
        else
          if !value.finite? || child < value
            value = child
            best_action_key = game.bot_action_key(action)
          end
          beta = [beta, value].min
        end
        if beta <= alpha
          @search_cutoffs += 1
          break
        end
      end
      value = game.bot_position_value(replay, root_actor).to_f if !value.finite?
      if @optimize_transpositions && best_action_key != nil
        move_order[state_move_ordering_key] = best_action_key
      end
      bound = if value <= original_alpha
        :upper
      elsif value >= original_beta
        :lower
      else
        :exact
      end
      cache[key] = TranspositionEntry.new(
        value: value,
        bound: bound,
        best_action_key: best_action_key
      )
      value
    end

    def tactical_search(environment, root_actor, game, context, budget, alpha, beta, remaining)
      replay = environment.replay
      return game.bot_reward(replay, root_actor).to_f * 1_000_000 if replay.finished?
      standing = game.bot_position_value(replay, root_actor).to_f
      return standing if remaining <= 0
      tactical = game.bot_tactical_actions(replay)
      actions = tactical[:actions]
      return standing if actions.empty?
      actor = environment.active_actor
      maximizing = game.bot_allied?(replay, root_actor, actor)
      value = tactical[:forced] ? (maximizing ? -Float::INFINITY : Float::INFINITY) : standing
      if !tactical[:forced]
        maximizing ? alpha = [alpha, value].max : beta = [beta, value].min
        return value if beta <= alpha
      end
      ordered_actions(actions, replay, actor, game, context).each do |action|
        budget.visit!
        branch = search_branch(environment, action, actor)
        next unless branch
        child = tactical_search(branch, root_actor, game, context, budget, alpha, beta, remaining - 1)
        value = maximizing ? [value, child].max : [value, child].min
        maximizing ? alpha = [alpha, value].max : beta = [beta, value].min
        break if beta <= alpha
      end
      value.finite? ? value : standing
    end

    def ordered_actions(actions, replay, actor, game, context)
      actions.to_a.sort_by do |action|
        [
          -game.bot_action_score(replay, actor, action, context: context).to_f,
          game.bot_action_key(action)
        ]
      end
    end

    def continuation?(game, replay)
      game.respond_to?(:bot_forced_continuation?) && game.bot_forced_continuation?(replay)
    end

    def prefer_action(actions, preferred_action_key, game)
      return actions if preferred_action_key == nil

      index = actions.index { |action| game.bot_action_key(action) == preferred_action_key }
      return actions if index == nil || index == 0

      preferred = actions[index]
      [preferred] + actions[0...index] + actions[(index + 1)..]
    end

    def ordering_key(replay, root_actor, moving_actor, game)
      [game.bot_search_key(replay, root_actor), moving_actor.to_s.downcase]
    end

    def move_ordering_key(replay, root_actor, moving_actor, game)
      return ordering_key(replay, root_actor, moving_actor, game) unless game.respond_to?(:bot_move_order_key)
      [game.bot_move_order_key(replay, root_actor), moving_actor.to_s.downcase]
    end

    def search_branch(environment, action, actor)
      branch = if environment.respond_to?(:fork_for_search)
        environment.fork_for_search
      else
        environment.fork
      end
      status = if branch.respond_to?(:step_for_search)
        branch.step_for_search(action, actor: actor)
      else
        branch.step(action, actor: actor)
      end
      status == :ok ? branch : nil
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
