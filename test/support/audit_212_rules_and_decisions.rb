require_relative 'new_games_fixture'
require_relative '../../games/chess'
require_relative '../../games/checkers'
require_relative '../../games/spades'
require_relative '../../games/ludo'
require_relative '../../games/farkle'
require_relative '../../games/ninety_nine'
require_relative '../../lib/game_tree_search'

def audit_replay(state)
  GameRoomGames::Replay.new(state: state, board: state[:board], players: state[:players], current_player: state[:current_player], history: [], accepted_events: [])
end
