require_relative "../content/scrabble_tiles"

module GameRoomScrabbleRules
  Result = Struct.new(:error, :board, :words, :score, keyword_init: true)
  # Each character describes a square: 2/3 = letter, D/T = word.
  PREMIUM_ROWS = [
    "T..2...T...2..T", ".D...3...3...D.", "..D...2.2...D..",
    "2..D...2...D..2", "....D.....D....", ".3...3...3...3.",
    "..2...2.2...2..", "T..2...D...2..T", "..2...2.2...2..",
    ".3...3...3...3.", "....D.....D....", "2..D...2...D..2",
    "..D...2.2...D..", ".D...3...3...D.", "T..2...T...2..T"
  ].freeze
  module_function
  def field(index); "#{(65 + index % 15).chr}#{index / 15 + 1}"; end
  def neighbors(index)
    x, y = index % 15, index / 15
    [[x-1,y],[x+1,y],[x,y-1],[x,y+1]].select { |a,b| a.between?(0,14) && b.between?(0,14) }.map { |a,b| b*15+a }
  end
  def premium(index); PREMIUM_ROWS[index / 15][index % 15]; end
  def evaluate(board, rack, tiles, placements, alphabet)
    fail_result = ->(message) { Result.new(error: message, words: [], score: 0) }
    return fail_result.call(:empty_move) unless placements.is_a?(Array) && placements.length.between?(1,7)
    return fail_result.call(:invalid_placement) unless placements.all? { |p| p.is_a?(Array) && p.length == 3 && p[0].is_a?(Integer) && p[1].is_a?(Integer) && p[1].between?(0,224) && p[2].is_a?(String) }
    ids, positions = placements.map(&:first), placements.map { |p| p[1] }
    return fail_result.call(:invalid_placement) unless ids.uniq == ids && positions.uniq == positions && (ids - rack).empty?
    return fail_result.call(:occupied_square) if positions.any? { |pos| board[pos] }
    new_board = board.dup
    placements.each do |tile_id, pos, letter|
      tile = tiles[tile_id]
      return fail_result.call(:invalid_placement) unless tile && alphabet.include?(letter) && (tile[:letter].empty? || letter == tile[:letter])
      new_board[pos] = { id: tile_id, letter: letter, points: tile[:points], blank: tile[:letter].empty? }
    end
    xs, ys = positions.map { |p| p % 15 }.uniq, positions.map { |p| p / 15 }.uniq
    return fail_result.call(:one_line_required) if xs.length > 1 && ys.length > 1
    direction = ys.length == 1 ? 1 : 15
    if positions.length > 1
      positions.min.step(positions.max, direction) { |pos| return fail_result.call(:gap_in_word) unless new_board[pos] }
    end
    if board.compact.empty?
      return fail_result.call(:cover_center) unless positions.include?(112)
    else
      return fail_result.call(:disconnected_word) unless positions.any? { |pos| neighbors(pos).any? { |neighbor| board[neighbor] } }
    end
    words, seen = [], {}
    positions.each do |pos|
      [1,15].each do |step|
        start = pos
        start -= step while previous_in_line?(start, step) && new_board[start-step]
        cells, cursor = [], start
        loop do
          break unless new_board[cursor]
          cells << cursor
          break unless next_in_line?(cursor, step)
          cursor += step
        end
        next if cells.length < 2 || seen[[start,step]]
        seen[[start,step]] = true
        multiplier = 1
        points = cells.sum do |cell|
          value = new_board[cell][:points]
          if positions.include?(cell)
            bonus = premium(cell)
            value *= bonus.to_i if %w[2 3].include?(bonus)
            multiplier *= 2 if bonus == "D"
            multiplier *= 3 if bonus == "T"
          end
          value
        end
        words << { word: cells.map { |cell| new_board[cell][:letter] }.join, start: start, direction: step, score: points * multiplier }
      end
    end
    return fail_result.call(:word_too_short) if words.empty?
    Result.new(board: new_board, words: words, score: words.sum { |word| word[:score] } + (placements.length == 7 ? 50 : 0))
  end
  def previous_in_line?(pos, step); step == 15 ? pos >= 15 : pos % 15 > 0; end
  def next_in_line?(pos, step); step == 15 ? pos < 210 : pos % 15 < 14; end
end
