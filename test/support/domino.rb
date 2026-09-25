require_relative "new_games_fixture"
require_relative "../../games/domino"

def position(game, hands, **values)
  state = game.initial_state(hands.keys, game.normalize_options(values.delete(:options) || {}))
  state.merge!(phase: :playing, round: 1, turn: 1, turn_started: 100, hands: hands, current_player: hands.keys.first)
  state.merge!(values)
  state
end
def move(game, state, action, actor: nil, time: 100, **data)
  history = []
  value = { "action" => action, "round" => state[:round], "turn" => state[:turn], "time" => time }.merge(data.transform_keys(&:to_s))
  result = game.send(:apply, state, value, actor || state[:current_player], 1, history)
  [result, history]
end
def chain(left, right)
  [{ tile: GameRoomDominoTiles.tile(left, right), left: left, right: right }]
end
def replay_of(state)
  GameRoomGames::Replay.new(players: state[:players], state: state, current_player: state[:current_player], history: [], accepted_events: [])
end
