# encoding: UTF-8
require "json"
require_relative "game_bots"

module BibliosPlanning
  class Strategy
    def initialize(fallback: GameRoomBots::HeuristicStrategy.new)
      @fallback = fallback
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, **_extra)
      choices = actions.to_a
      return nil if choices.empty?
      return choices.first if choices.length == 1

      packets = choices.select { |action| action["kind"].to_s == "card_packet" }
      return packets.max_by { |action| game.bot_action_score(replay, actor, action, context: context) } if !packets.empty?

      @fallback.choose(
        actions: choices, actor: actor, random_source: random_source,
        game: game, replay: replay, context: context
      )
    end

  end
end
