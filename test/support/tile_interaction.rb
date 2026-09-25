require_relative "ui"
require_relative "elten_array_shuffle"
require_relative "../../lib/game_surfaces"
require_relative "../../games/domino"
require_relative "../../games/mexican_train"

def assert(value, message); raise message unless value; end
def n_(singular, plural, count); count == 1 ? singular : plural; end
def tile_replay(state)
  GameRoomGames::Replay.new(players: state[:players], current_player: state[:current_player], state: state, history: [])
end
def domino_fixture
  game = GameRoomGames::Domino.new
  state = game.initial_state(%w[Alice Bob], game.normalize_options("tile_set" => "2d6"))
  state.merge!(phase: :playing, round: 1, turn: 1, current_player: "Alice",
    hands: {"Alice" => %w[121 560 330], "Bob" => %w[340]}, chain: [{tile: "120", left: 1, right: 2}])
  [game, state, GameSurfaces.build(game.surface_spec(tile_replay(state), "Alice"))]
end
def train_fixture
  game = GameRoomGames::MexicanTrain.new
  state = game.initial_state(%w[Alice Bob Carol], game.default_options)
  state.merge!(phase: :playing, round: 1, turn: 1, current_player: "Alice", station: 12,
    hands: {"Alice" => %w[6c0 590 550], "Bob" => %w[340], "Carol" => %w[220]},
    trains: {
      "p0" => {owner: "Alice", end: 12, open: false, chain: []},
      "p1" => {owner: "Bob", end: 9, open: false, chain: [{tile: "9c0", left: 12, right: 9}]},
      "p2" => {owner: "Carol", end: 3, open: false, chain: [{tile: "3c0", left: 12, right: 3}]},
      "m" => {owner: nil, end: 12, open: true, chain: []}})
  [game, state, GameSurfaces.build(game.surface_spec(tile_replay(state), "Alice"))]
end
