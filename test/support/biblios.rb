require_relative "new_games_fixture"

def church_card(game, kind)
  (1..24).map { |index| "k#{index}" }.find { |card| game.church_kind(card) == kind }
end

def blank_state(game, players, options = {})
  game.send(:initial_state, players, game.normalize_options(options))
end

def bluff_board(game, penalty: "bluff", passed: [], gold: %w[o1], high: 1)
  state = game.send(:initial_state, %w[Alice Bob Carol], game.normalize_options("penalty" => penalty))
  state[:phase] = :auction
  state[:dice]["m"] = 6
  state[:card] = "mH"
  state[:current_player] = "Alice"
  state[:hands]["Alice"] = gold
  state[:hands]["Bob"] = %w[mA]
  state[:hands]["Carol"] = []
  state[:passed] = passed
  state[:high] = high
  state
end

def bid_value(game, state, amount)
  game.bot_action_score(replay_of(state), "Alice", { "action" => "bid", "amount" => amount })
end

def replay_of(state)
  GameRoomGames::Replay.new(
    players: state[:players], current_player: state[:current_player],
    winner: state[:winner], draw: state[:tie], state: state,
    accepted_events: [], history: []
  )
end

def play_biblios(game, players, options = {})
  repository = NewGames116Repository.new(players)
  session = { "options" => JSON.generate(game.normalize_options(options)) }
  events = []
  replay = game.replay(session, events, repository)
  context = context_for
  random = NewGames116Random.new
  strategy = game.bot_strategy
  guard = 0
  while !replay.finished?
    guard += 1
    raise "Biblios did not finish" if guard > 20_000

    state = replay.state
    if state[:phase] == :setup
      replay = append_action(game, session, repository, events, replay, players.first,
        game.automatic_action(replay, players.first), context)
      next
    end
    actor = replay.current_player
    raise "no actor in #{state[:phase]}" if actor == nil

    assert(state[:public].length <= players.length - 1, "the public space overflowed")
    assert(state[:hands].values.flatten.none? { |card| game.church?(card) }, "a Church card stayed in a hand")
    actions = game.legal_actions(replay, actor)
    raise "no legal actions for #{actor} in #{state[:phase]}" if actions.empty?

    choice = strategy.choose(actions: actions, actor: actor, random_source: random, game: game, replay: replay)
    replay = append_action(game, session, repository, events, replay, actor, choice, context)
  end
  [replay, events, session, repository]
end
