require_relative '../../support/dealt_card_games'
include GameRoomTest::Assertions
game = GameRoomGames::Scopa.new
assert_equal(['7C'], game.class.capture(%w[3C 4D 7C], '7H'), 'single-card precedence')
assert_equal(%w[4H 3C], game.class.capture(%w[AC 2D 4H 3C 4D], '7H'), 'fewest then table order')
assert_equal(%w[3C 4D], game.class.capture(%w[3C 4D 2H 5S], '7H'), 'earliest equal combination')
assert_equal(['7C'], game.class.capture(%w[3C 4D 7C], '8H', escoba: true), 'escoba target')
assert_equal([], game.class.capture(%w[3C 4D], 'AH'), 'impossible capture')
assert_equal(['AC'], game.class.capture(%w[AC 2C], 'AD'), 'ace value')
points = game.class.round_points({'a'=>[], 'b'=>[], 'c'=>%w[7D 7C 2D]}, {'a'=>0,'b'=>0,'c'=>0}, muerto:true)
assert_equal({'a'=>4,'b'=>4,'c'=>0}, points, 'Muerto must credit each opposing side in full')
assert_equal({'a'=>0,'b'=>0}, game.class.round_points({'a'=>%w[2C 7C], 'b'=>%w[2H 7H]}, {'a'=>0,'b'=>0}), 'majority ties')

(2..6).each do |count|
  [false, true].repeated_permutation(3).each do |escoba, scopone, muerto|
    t = GameRoomTest::DealtCardTable.new('scopa', count:count,
      options:{'escoba'=>escoba, 'scopone'=>scopone, 'muerto'=>muerto, 'score_limit'=>1,'two_point_lead'=>false}, seed:count)
    opening = t.state[:hands].values.flatten + t.state[:table] + t.state[:stock] + t.state[:discarded]
    assert_equal(GameRoomGames::Scopa::DECK.sort, opening.sort, 'opening deck')
    assert(t.state[:table].empty?, 'Scopone did not start empty') if scopone
    t.finish_round
    collected = t.state[:taken].values.flatten + t.state[:table] + t.state[:discarded]
    assert_equal(GameRoomGames::Scopa::DECK.sort, collected.sort, "cards lost with #{count}/#{[escoba,scopone,muerto]}")
    assert(t.events.size == t.replay.accepted_events.size, 'legal event lost')
    assert(t.state[:scores].values.sum > 0, 'no round score')
  end
end

[[4,2],[6,2],[6,3]].each do |count,size|
  t = GameRoomTest::DealtCardTable.new('scopa', count:count, options:{'team_size'=>size})
  t.finish_round
  assert(t.state[:units].size == count/size, 'wrong number of scoring sides')
  t.state[:units].each do |unit|
    members = t.state[:unit_for].keys.select { |player| t.state[:unit_for][player] == unit }
    assert(t.game.participant_scores(t.replay).values_at(*members).uniq.size == 1, 'partners scored separately')
  end
end

# The final played card can earn a scopa; automatic leftovers cannot.
t = GameRoomTest::DealtCardTable.new('scopa')
s = t.state
s[:hands] = {'Alice'=>['7C'], 'Bob'=>[]}
s[:table], s[:stock], s[:current_player] = ['7D'], [], 'Alice'
s[:taken], s[:scopas] = {'Alice'=>[], 'Bob'=>[]}, {'Alice'=>0, 'Bob'=>0}
t.game.send(:play_card, s, 'Alice', '7C', {'id'=>99}, t.repository, [])
assert_equal(1,s[:scopas]['Alice'],'last play scopa missing')
s[:hands] = {'Alice'=>[], 'Bob'=>[]}
s[:table], s[:stock], s[:last_capturer] = ['2D'], [], 'Bob'
s[:scopas] = {'Alice'=>0,'Bob'=>0}
t.game.send(:score_round, s, {'id'=>100}, t.repository, [])
assert(s[:taken]['Bob'].include?('2D') && s[:scopas].values.sum.zero?, 'leftovers wrong owner or counted as scopa')
puts 'PASS Scopa: captures, ties, Muerto, all 8 variant combinations at 2–6 seats, team layouts, leftovers, final scopa'
