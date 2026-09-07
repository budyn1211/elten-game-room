require_relative "game_participants"

module GameRoomBots
  Decision = Struct.new(:actor, :action, :available_actions, keyword_init: true)

  module_function

  # Older game strategies only accepted the original four keywords. Filtering
  # here keeps them compatible while new strategies can receive the game and a
  # forkable simulation environment.
  def choose(strategy, arguments)
    parameters = strategy.method(:choose).parameters
    accepts_all = parameters.any? { |kind, _name| kind == :keyrest }
    accepted = parameters.each_with_object([]) do |(kind, name), names|
      names << name if [:key, :keyreq].include?(kind)
    end
    keywords = accepts_all ? arguments : arguments.select { |key, _value| accepted.include?(key) }
    strategy.choose(**keywords)
  end

  def random_choice(choices, random_source)
    values = choices.to_a
    return nil if values.empty?
    return values.first if values.length == 1

    roll = random_source.roll(count: 1, sides: values.length)
    values[roll.values.first.to_i - 1]
  end

  class RandomStrategy
    def choose(actions:, observation:, actor:, random_source:, **_extra)
      GameRoomBots.random_choice(actions, random_source)
    end
  end

  class HeuristicStrategy
    def choose(actions:, actor:, random_source:, game: nil, replay: nil, context: nil, **_extra)
      if game == nil || replay == nil
        draw = actions.to_a.find { |action| action["action"].to_s == "draw" }
        return draw if draw != nil

        return GameRoomBots.random_choice(actions, random_source)
      end

      scored = actions.to_a.map do |action|
        [action, game.bot_action_score(replay, actor, action, context: context).to_f]
      end
      return nil if scored.empty?

      best_score = scored.map(&:last).max
      GameRoomBots.random_choice(
        scored.select { |_action, score| score == best_score }.map(&:first),
        random_source
      )
    end
  end

  class MCTSStrategy
    Node = Struct.new(
      :environment,
      :parent,
      :action,
      :children,
      :untried_actions,
      :visits,
      :value,
      keyword_init: true
    )

    def initialize(iterations: 120, max_depth: 80, exploration: Math.sqrt(2.0), fallback: HeuristicStrategy.new)
      @iterations = [iterations.to_i, 1].max
      @max_depth = [max_depth.to_i, 1].max
      @exploration = exploration.to_f
      @fallback = fallback
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, simulation: nil, **_extra)
      if simulation == nil || !game.perfect_information?
        return GameRoomBots.choose(@fallback, {
          actions: actions,
          observation: game.bot_observation(replay, actor),
          actor: actor,
          random_source: random_source,
          game: game,
          replay: replay,
          context: context
        })
      end

      root = node_for(simulation.fork, nil, nil, actions)
      @iterations.times do
        node = root
        depth = 0
        while node.untried_actions.empty? && !node.children.empty? && !node.environment.finished?
          node = select_child(node, actor, game)
          depth += 1
        end

        if !node.environment.finished? && !node.untried_actions.empty?
          action = GameRoomBots.random_choice(node.untried_actions, random_source)
          node.untried_actions.delete_at(node.untried_actions.index(action))
          child_environment = node.environment.fork
          moving_actor = child_environment.active_actor
          result = child_environment.step(action, actor: moving_actor)
          if result == :ok
            child = node_for(child_environment, node, action)
            node.children << child
            node = child
            depth += 1
          end
        end

        rollout = node.environment.fork
        rollout_randomly(rollout, random_source, depth)
        score = game.bot_position_value(rollout.replay, actor).to_f
        while node != nil
          node.visits += 1
          node.value += score
          node = node.parent
        end
      end

      explored = root.children.select { |child| child.visits > 0 }
      return GameRoomBots.choose(@fallback, {
        actions: actions,
        observation: game.bot_observation(replay, actor),
        actor: actor,
        random_source: random_source,
        game: game,
        replay: replay,
        context: context
      }) if explored.empty?

      explored.max_by { |child| [child.visits, child.value / child.visits] }.action
    end

    private

    def node_for(environment, parent, action, actions = nil)
      Node.new(
        environment: environment,
        parent: parent,
        action: action,
        children: [],
        untried_actions: (actions || environment.legal_actions).to_a.dup,
        visits: 0,
        value: 0.0
      )
    end

    def select_child(node, root_actor, game)
      moving_actor = node.environment.active_actor
      allied = game.bot_allied?(node.environment.replay, root_actor, moving_actor)
      logarithm = Math.log([node.visits, 1].max)
      node.children.max_by do |child|
        exploitation = child.value / [child.visits, 1].max
        exploitation *= -1.0 if !allied
        exploitation + @exploration * Math.sqrt(logarithm / [child.visits, 1].max)
      end
    end

    def rollout_randomly(environment, random_source, depth)
      while !environment.finished? && depth < @max_depth
        actions = environment.legal_actions
        break if actions.empty?

        action = GameRoomBots.random_choice(actions, random_source)
        break if environment.step(action, actor: environment.active_actor) != :ok

        depth += 1
      end
    end
  end

  class LearnedStrategy
    attr_reader :policy

    def initialize(policy:, epsilon: 0.05, fallback: HeuristicStrategy.new)
      @policy = policy
      @epsilon = [[epsilon.to_f, 0.0].max, 1.0].min
      @fallback = fallback
      @trajectories = Hash.new { |hash, key| hash[key] = [] }
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, **_extra)
      choices = actions.to_a
      return nil if choices.empty?

      state_key = game.bot_state_key(replay, actor)
      explore = random_source.roll(count: 1, sides: 1_000).values.first <= (@epsilon * 1_000).round
      action = if explore || !@policy.known_state?(state_key)
        GameRoomBots.choose(@fallback, {
          actions: choices,
          observation: game.bot_observation(replay, actor),
          actor: actor,
          random_source: random_source,
          game: game,
          replay: replay,
          context: context
        })
      else
        @policy.best_action(state_key, choices) { |candidate| game.bot_action_key(candidate) }
      end
      @trajectories[actor.to_s] << [state_key, game.bot_action_key(action)] if action != nil
      action
    end

    def finish_episode(actor, reward)
      @trajectories.delete(actor.to_s).to_a.each do |state_key, action_key|
        @policy.update(state_key, action_key, reward.to_f)
      end
    end

    def reset_episode(actor = nil)
      actor == nil ? @trajectories.clear : @trajectories.delete(actor.to_s)
    end
  end

  class Coordinator
    def initialize(strategy: RandomStrategy.new)
      @strategy = strategy
    end

    def pending_bot(game, replay)
      return nil if replay == nil || replay.finished?

      game.active_actors(replay).find { |actor| GameRoomParticipants.bot?(actor) }
    end

    def decide_next(game:, replay:, context:, simulation: nil, strategy: nil)
      return nil if replay == nil || replay.finished?

      game.active_actors(replay).each do |actor|
        next if !GameRoomParticipants.bot?(actor)

        decision = decide(
          game: game,
          replay: replay,
          actor: actor,
          context: context,
          simulation: simulation,
          strategy: strategy
        )
        return decision if decision != nil
      end
      nil
    end

    def decide(game:, replay:, actor:, context:, simulation: nil, strategy: nil)
      return nil if replay == nil || replay.finished?
      return nil if actor == nil || !GameRoomParticipants.bot?(actor)
      return nil if !game.supports_bots?

      actions = game.legal_actions(replay, actor, context: context).to_a
      return nil if actions.empty?

      selected_strategy = strategy || game.bot_strategy || @strategy
      action = GameRoomBots.choose(selected_strategy, {
        actions: actions,
        observation: game.bot_observation(replay, actor),
        actor: actor,
        random_source: context.random_source,
        game: game,
        replay: replay,
        context: context,
        simulation: simulation
      })
      return nil if action == nil

      Decision.new(actor: actor.to_s, action: action, available_actions: actions)
    end
  end
end
