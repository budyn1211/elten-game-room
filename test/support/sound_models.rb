require_relative '../../games/base'
require_relative '../../games/board_game'
require_relative '../../games/battleship'
require_relative '../../games/mancala'
require_relative '../../games/biblios'
require_relative '../../games/taboo'
require_relative '../../games/scrabble'
require_relative '../../games/spades'
require_relative '../../games/tysiac'
require_relative '../../games/three_five_eight'
require_relative '../../games/ninety_nine'
require_relative '../../games/farkle'
require_relative '../../games/cat_head_tail'
require_relative '../../games/uno'
require_relative '../../games/makao'
require_relative '../../games/poker'
require_relative '../../games/yahtzee'
require_relative '../../games/monopoly'
require_relative '../../games/four_in_a_row'
require_relative '../../games/tic_tac_toe'
require_relative '../../games/chess'
require_relative '../../games/checkers'
require_relative '../../games/reversi'
require_relative '../../games/ludo'
require_relative '../../games/quiz_party'
require_relative '../../games/rummy'
require_relative '../../games/domino'
require_relative '../../games/mexican_train'

module GameRoomSoundModels
  module_function

  def game(id)
    GameRoomGames.constants.filter_map do |name|
      type = GameRoomGames.const_get(name)
      type.new if type.is_a?(Class) && type < GameRoomGames::Base &&
        type.instance_method(:id).owner != GameRoomGames::Base
    end.find { |game| game.id.to_s == id.to_s } || raise("Unknown sound test game: #{id}")
  end
end
