require_relative '../../support/ui'
require_relative '../../../lib/game_surfaces'
require_relative '../../support/dealt_card_games'
require_relative '../../../lib/game_screen'
require_relative '../../../lib/hidden_submissions'

include GameRoomTest::Assertions
module Session
  class << self; attr_accessor :name; end
end

table = GameRoomTest::DealtCardTable.new('bouillabaisse', seed: 8)
game = table.game
screens = %w[Alice Bob Observer].to_h do |viewer|
  screen = GameScreen.new(program: Object.new, repository: table.repository, game: game,
    session: table.session.merge('__id' => 53), table: {}, table_owner: 'Alice',
    room_snapshot_provider: nil, synchronizer: nil)
  Session.name = viewer
  screen.send(:process_new_events, game.replay(table.session, [], table.repository))
  [viewer, screen]
end

6.times do |index|
  round = index + 1
  replay = table.replay
  reminder = game.game_shortcuts(replay, 'Alice').find { |shortcut| shortcut.key == 'r' && shortcut.modifiers.empty? }
  assert(reminder && reminder.kind == :announcement, "round #{round}: R is missing")
  text = reminder.message
  descriptions = Array(game.describe_event(table.events.last, table.repository, replay, 'Alice'))
  assert(descriptions == [text], "round #{round}: deal announces unrelated rules: #{descriptions.inspect}")
  assert(text.include?("Round #{round} of 6."), "round #{round}: missing round number")
  numbers = {1 => [5], 2 => [10], 3 => [50], 4 => [200], 5 => [5, 10, 50, 200], 6 => [5, 10, 50, 200]}.fetch(round)
  numbers.each { |points| assert(text.match?(/\b#{points}\b/), "round #{round}: missing #{points} point rule") }
  assert(text.include?('subtracted') || text.include?('subtracts'), 'Final round does not explain subtraction') if round == 6
  screens.each do |viewer, screen|
    Session.name = viewer
    $spoken_messages.clear
    screen.send(:process_new_events, replay)
    assert($spoken_messages.count(text) == 1, "#{viewer}: round #{round} rules were not announced once")
    $spoken_messages.clear
    screen.send(:process_new_events, replay)
    assert($spoken_messages.empty?, "#{viewer}: round #{round} announcement repeated without a move")
  end
  table.finish_round
  # Consume intervening play/score messages before the following actual deal.
  screens.each do |viewer, screen|
    Session.name = viewer
    screen.send(:process_new_events, table.replay)
  end
  table.deal if round < 6
end

puts 'PASS Bouillabaisse round speech: six complete rules, R reminder, players/observer, automatic deal and no duplicate refresh speech'
