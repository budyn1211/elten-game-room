require_relative '../../support/dealt_card_games'
include GameRoomTest::Assertions

(2..6).each do |count|
  [false, true].each do |scopone|
    table = GameRoomTest::DealtCardTable.new('scopa', count: count, options: {'scopone' => scopone, 'score_limit' => 1000})
    2.times do |index|
      table.finish_round
      round = index + 1
      history = table.replay.history
      warnings = history.select { |entry| entry.kind == :last_deal }
      assert_equal(scopone ? 0 : round, warnings.size, "#{count}/#{scopone}: wrong final-deal warning count")
      unless scopone
        warning = warnings.last
        after = history[history.index(warning) + 1]
        assert_equal(warning.event_id, after.event_id, 'Warning detached from the last deal event')
        assert_equal(:redeal, after.kind, 'Final warning at the wrong deal')
        assert_equal('Final deal.', warning.text)
        dealt = table.events.select { |event| event['id'] <= warning.event_id }
        replay = table.game.replay(table.session, dealt, table.repository)
        assert(replay.state[:stock].empty? && replay.state[:hands].values.all?(&:any?), 'Final deal was announced after the hands were played')
      end
      assert(table.state[:stock].empty?, 'Last announced packet left cards in the stock')
      assert_equal(table.game.replay(table.session, table.events, table.repository), table.replay, 'Replay changed the deal warning')
      table.deal if round == 1
    end
  end
end

puts 'PASS Scopa final deal: 2–6 players, two rounds, before the last packet, no repeat on reconstruction and no warning in Scopone'
