require_relative "new_games_fixture"
require_relative "elten_array_shuffle"
require_relative "../../games/ninety_nine"
require_relative "../../lib/game_sounds"

class TimedCardCase
  attr_reader :game, :session, :repo, :events, :context, :replay

  def initialize(game, options = {}, players = %w[A B C])
    @game = game
    @session = { "options" => JSON.generate(game.normalize_options({"thinking_time"=>20}.merge(options))) }
    @repo = NewGames116Repository.new(players)
    @events = []
    @context = GameRoomGames::ActionContext.new(now: 100, random_source: NewGames116Random.new)
    @replay = game.replay(session, events, repo)
    act({"kind"=>"command", "action"=>"deal"}, players.first)
  end

  def act(selection, actor = replay.current_player)
    before_count = events.length
    @replay = append_action(game, session, repo, events, replay, actor, selection, context)
    assert(events.length == before_count + 1 && replay.accepted_events == events, "one accepted event per action: #{game.id}")
    assert(events.last["value"].bytesize <= 64, "event exceeds transport limit")
    replay
  end

  def timeout
    context.now = replay.state[:turn_deadline]
    act({"action"=>"turn_timeout"}, replay.players.first)
  end
end
