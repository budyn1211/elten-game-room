require_relative "../../lib/game_bots"

# Training-only strategy; requiring the game runtime does not load it.
# Preserve its namespace for existing training scripts.
module GameRoomBots
  class LearnedStrategy
    include ReplayOnlyStrategy

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
end
