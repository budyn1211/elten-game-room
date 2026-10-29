require_relative '../../support/dealt_card_games'
include GameRoomTest::Assertions

def settle(taken, scopas: nil, options: {}, players: nil)
  table = GameRoomTest::DealtCardTable.new('scopa', count: players || taken.size,
    options: options.merge('score_limit' => 1000))
  state = table.state
  state[:taken] = taken
  state[:scopas] = scopas || taken.to_h { |unit, _| [unit, 0] }
  state[:table], state[:last_capturer] = [], nil
  before = Marshal.load(Marshal.dump([state[:taken], state[:scopas]]))
  history = []
  table.game.send(:score_round, state, {'id' => 100}, table.repository, history)
  assert_equal(before, [state[:taken], state[:scopas]], 'Explanation changed captured cards or scopas')
  assert_equal([:score_breakdown, :score], history.map(&:kind), 'Breakdown must precede round totals exactly once')
  [table, history.first.text]
end

table, text = settle({'Alice' => %w[7D 2C 3C 4C 5C 6C], 'Bob' => %w[7C 2D 3D 4D 5D]},
  scopas: {'Alice' => 2, 'Bob' => 0})
assert_equal("Alice: 1 point for the most cards, 1 point for the seven of diamonds.\n" \
  "Bob: 1 point for the most diamonds.\nMost sevens: tied, no point.", text)
assert_equal({'Alice' => 4, 'Bob' => 1}, table.state[:scores], 'Round totals must retain scopas')
assert(!text.downcase.include?('scopa'), 'Scopas were explained a second time')

_, ties = settle({'Alice' => %w[2C 7C], 'Bob' => %w[2H 7H]})
assert_equal("Most cards: tied, no point.\nMost diamonds: tied, no point.\nMost sevens: tied, no point.", ties)
assert(!ties.include?('seven of diamonds'), 'An undealt seven of diamonds was awarded')

table, text = settle({'Alice' => %w[7D 7C 2D], 'Bob' => [], 'Carol' => []}, options: {'muerto' => true},
  scopas: {'Alice' => 2, 'Bob' => 0, 'Carol' => 0})
assert_equal({'Alice' => 0, 'Bob' => 6, 'Carol' => 6}, table.state[:scores], 'Muerto lost opposing points or scopas')
assert_equal(4, text.lines.size, 'Muerto repeats partners or scopas')
assert(text.lines.all? { |line| line.start_with?('Alice has ') && line.chomp.end_with?('Bob, Carol receive 1 point each.') },
  'Muerto explains the wrong recipients')

_, text = settle({'Alice' => %w[7D 7C 2D], 'Bob' => []}, options: {'muerto' => true})
assert(text.lines.all? { |line| line.include?('Bob receives 1 point.') }, 'One opponent uses a plural recipient')

table = GameRoomTest::DealtCardTable.new('scopa', count: 4, options: {'team_size' => 2, 'score_limit' => 1000})
units = table.state[:units]
table.state[:taken] = {units[0] => %w[7D 7C 2D], units[1] => []}
table.state[:table], table.state[:last_capturer] = [], nil
history = []
table.game.send(:score_round, table.state, {'id' => 100}, table.repository, history)
label = table.game.send(:unit_label, table.state, units[0])
assert_equal(1, history.first.text.lines.size, 'Partners receive duplicated breakdowns')
assert(history.first.text.start_with?("#{label}: "), 'Team members are missing from the summary')
assert_equal(4, table.state[:scores][units[0]], 'Team bonuses were multiplied by team size')

# The presentation refactor must retain the former scoring for every allocation.
random = Random.new(37)
[2, 3, 6].each do |count|
  60.times do
    units = Array.new(count) { |index| "Side#{index}" }
    taken = units.to_h { |unit| [unit, []] }
    GameRoomGames::Scopa::DECK.each { |card| taken[units[random.rand(count)]] << card }
    scopas = units.to_h { |unit| [unit, random.rand(8)] }
    expected = scopas.dup
    [->(cards) { cards.size }, ->(cards) { cards.count { |card| card[1] == 'D' } },
      ->(cards) { cards.count { |card| card[0] == '7' } }].each do |metric|
      counts = taken.transform_values { |cards| metric.call(cards) }
      leaders = units.select { |unit| counts[unit] == counts.values.max }
      expected[leaders.first] += 1 if leaders.size == 1
    end
    taken.each { |unit, cards| expected[unit] += 1 if cards.include?('7D') }
    assert_equal(expected, GameRoomGames::Scopa.round_points(taken, scopas), 'Ordinary scoring changed')
    assert_equal(expected.to_h { |unit, _| [unit, expected.values.sum - expected[unit]] },
      GameRoomGames::Scopa.round_points(taken, scopas, muerto: true), 'Muerto scoring changed')
  end
end

puts 'PASS Scopa breakdown: four awards, ties, absent seven, ordinary/team/Muerto recipients, preserved scopas and 360 scoring comparisons'
