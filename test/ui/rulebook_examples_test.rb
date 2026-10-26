# Selected numerical examples and easily confused local variants used by the
# manuals. This is not an exhaustive rules-engine audit or a game simulation.
require_relative "../support/rulebook_authoring"

yahtzee = GameRoomGames::Yahtzee.new
state = yahtzee.send(:initial_state, %w[Alice Bob], yahtzee.default_options)
score = ->(category, dice) { yahtzee.send(:score_category, category, dice, state, "Alice") }
assert(score.call("twos", [2, 2, 4, 4, 6]) == 4, "manual: count only twos")
assert(score.call("fours", [2, 2, 4, 4, 6]) == 8, "manual: count only fours")
assert(score.call("full_house", [6, 6, 6, 4, 4]) == 26, "manual: local full house may exceed 25")
assert(score.call("full_house", [6, 6, 6, 6, 6]) == 40, "manual: Yahtzee uses its special Full house score")
assert(score.call("pair", [2, 2, 4, 4, 6]) == 18, "manual: pair counts all five dice")
assert(score.call("two_pairs", [6, 6, 6, 4, 4]) == 26, "manual: full house also has two different pairs")
assert(score.call("two_pairs", [6, 6, 6, 6, 4]) == 0, "manual: four equal dice alone are not two pairs")
assert(score.call("small_straight", [1, 2, 2, 4, 5]) == 0, "manual: duplicates do not fill a straight's gap")
state[:sheets]["Alice"]["yahtzee"] = 0
state[:dice] = [3, 3, 3, 3, 3]
assert(yahtzee.send(:available_scoring_categories, state, "Alice").include?("large_straight"), "manual: Yahtzee can use a straight even with a zero in Yahtzee")
state[:sheets]["Alice"]["threes"] = 15
assert(yahtzee.send(:available_scoring_categories, state, "Alice").include?("ones"), "manual: upper categories remain available without a forced order")
assert(score.call("large_straight", state[:dice]) == 40, "manual: Yahtzee in Large straight scores 40")
assert(score.call("full_house", [6, 6, 6, 6, 6]) == 40, "manual: Yahtzee in Full house scores 40")
assert(score.call("two_pairs", state[:dice]) == 30, "manual: Yahtzee in Two pairs scores 30")
assert(score.call("sixes", state[:dice]) == 0, "manual: a Yahtzee does not change the upper dice values")

ninety_nine = GameRoomGames::NinetyNine.new
assert(ninety_nine.send(:total_after_card, 25, "0JS", "normal") == 35, "manual: jack adds ten, not zero")
assert(ninety_nine.send(:total_after_card, 60, "0JH", "normal") == 70, "manual: jack can cross 66")
assert(ninety_nine.send(:total_after_card, 60, "02S", "normal") == 30, "manual: two halves an even total above 49")
assert(ninety_nine.send(:total_after_card, 45, "02S", "normal") == 90, "manual: two otherwise doubles")
assert(ninety_nine.send(:total_after_card, 5, "0TS", "minus") == 0, "manual: subtraction does not go below zero")

rummy = GameRoomRummyRules
low = rummy.validate(%w[X00 3S0 4S0])
high = rummy.validate(%w[3S0 4S0 X00])
assert(low[:joker_face] == "2S" && high[:joker_face] == "5S", "manual: selection order sets joker position")
assert(rummy.points(high) == 15, "manual: rounded 3, 4 and joker scores 15")
assert(rummy.additions(rummy.validate(%w[3S0 4S0 5S0]), "X00").empty?, "manual: joker cannot be laid off directly")
pair_with_joker = rummy.validate(%w[3H0 3S0 X00])
extension = rummy.additions(pair_with_joker, "3C0")
assert(extension.all? { |choice| choice[:mode] == :extend }, "manual: third natural suit extends a three-card joker set")
assert(rummy.additions(extension.first[:meld], "3D0").any? { |choice| choice[:mode] == :recover }, "manual: fourth suit can recover the now-fixed joker")
assert(rummy.validate(%w[AS0 2S0 3S0]) && rummy.validate(%w[QS0 KS0 AS0]), "manual: low and high ace runs")
assert(rummy.validate(%w[KS0 AS0 2S0]).nil?, "manual: no king-ace-two wrap")

domino = GameRoomGames::Domino.new
mexican = GameRoomGames::MexicanTrain.new
zero = GameRoomDominoTiles.tile(0, 0)
eight = GameRoomDominoTiles.tile(3, 5)
assert(domino.send(:hand_points, [zero]) == 10, "manual: lone double zero costs ten in Domino")
assert(domino.send(:hand_points, [zero, eight]) == 8, "manual: double zero with another tile costs zero in Domino")
assert(mexican.send(:hand_points, [zero, eight]) == 18, "manual: double zero always costs ten in Mexican Train")

puts "PASS manual examples: Yahtzee scoring, 99 arithmetic, ordered Rummy jokers and recovery, distinct Domino/Mexican Train double-zero scoring"
