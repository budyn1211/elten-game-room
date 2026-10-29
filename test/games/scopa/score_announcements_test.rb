require_relative '../../support/ui'
require_relative '../../../lib/game_surfaces'
require_relative '../../support/dealt_card_games'
require_relative '../../../lib/game_screen'
require_relative '../../../lib/hidden_submissions'
include GameRoomTest::Assertions

module Session
  class << self; attr_accessor :name; end
end

table = GameRoomTest::DealtCardTable.new('scopa', seed: 8)
screens = %w[Alice Bob Observer].to_h do |viewer|
  screen = GameScreen.new(program: Object.new, repository: table.repository, game: table.game,
    session: table.session.merge('__id' => 54), table: {}, table_owner: 'Alice', room_snapshot_provider: nil, synchronizer: nil)
  Session.name = viewer
  screen.send(:process_new_events, table.replay)
  [viewer, screen]
end
table.finish_round
breakdown = table.replay.history.find { |entry| entry.kind == :score_breakdown }.text
totals = table.replay.history.find { |entry| entry.kind == :score }.text
screens.each do |viewer, screen|
  Session.name = viewer
  $spoken_messages.clear
  screen.send(:process_new_events, table.replay)
  assert_equal(1, $spoken_messages.count(breakdown), "#{viewer}: breakdown was not spoken exactly once")
  assert_equal(1, $spoken_messages.count(totals), "#{viewer}: totals were not spoken exactly once")
  assert($spoken_messages.index(breakdown) < $spoken_messages.index(totals), 'Totals precede their explanation')
  $spoken_messages.clear
  screen.send(:process_new_events, table.replay)
  assert($spoken_messages.empty?, 'Refreshing repeats the score explanation')
end
puts 'PASS Scopa presentation: both players and observer hear the breakdown before totals, once, without repeat on refresh'
