require_relative "game_bots"
require_relative "game_tree_search"

module MancalaPlanning
  class Strategy
    def simulation_required?
      true
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, simulation: nil, **extra)
      choices = actions.to_a
      return nil if choices.empty?
      return choices.first if choices.length == 1

      game.strategy_for(game.skill(replay.state)).choose(
        actions: choices, actor: actor, random_source: random_source,
        game: game, replay: replay, context: context, simulation: simulation, **extra
      )
    end
  end
end
