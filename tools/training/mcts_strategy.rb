require_relative '../../lib/game_bots'

module GameRoomBots
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

end
