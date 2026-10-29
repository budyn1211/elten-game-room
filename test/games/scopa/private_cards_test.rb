require_relative '../../support/private_card_games'
require_relative '../../../games/scopa'

game = GameRoomGames::Scopa.new
[[2,{}],[3,{'scopone'=>true}],[5,{}],[6,{'scopone'=>true,'escoba'=>true,'muerto'=>true,'team_size'=>2}]].each do |count, options|
  users = %w[Alice Bob Carol Dave Eve Frank].first(count)
  assignment = game.team_assignment(options, players:users)
  options = game.with_team_assignment(options, players:users, seats:assignment.seats) if assignment
  h,runners = PrivateCardGamesTest.create(game,users:users,options:options)
  begin
    PrivateCardGamesTest.assert_private(h)
    initial = h.replay(users.first)
    assert(initial.state[:phase] == :playing, "opening stalled: #{initial.state[:phase]}")
    assert(initial.state[:table].size == (options['scopone'] ? 0 : count==5 ? 5 : 4), 'public table not drawn')
    80.times do
      replay = h.replay(users.first)
      break if [:round_complete,:finished].include?(replay.state[:phase])
      if replay.current_player
        actor = replay.current_player
        selection = game.legal_actions(h.replay(actor), actor).first
        assert(selection, "no own card for #{actor}")
        PrivateCardGamesTest.submit(h,runners,actor,selection)
        PrivateCardGamesTest.assert_private(h)
      else
        PrivateCardGamesTest.tick(h,runners)
      end
    end
    state = h.replay(users.first).state
    assert([:round_complete,:finished].include?(state[:phase]), "round stalled: #{state[:phase]}")
    all = state[:taken].values.flatten + state[:table] + state[:discarded]
    assert(all.sort == GameRoomGames::Scopa::DECK.sort, 'private deck not fully accounted for')
    assert(state[:private_pools].size == 1, 'redeal created another pool')
    assert(state[:private_pools].values.first[:remaining].zero?, 'cards left undealt')
    assert(h.events(users.first).size == h.replay(users.first).accepted_events.size, 'wire event rejected')
    history = h.replay(users.first).history
    assert(history.count { |entry| entry.kind == :last_deal } == (options['scopone'] ? 0 : 1), 'Wrong private final-deal announcement count')
    unless options['scopone']
      index = history.index { |entry| entry.kind == :last_deal }
      assert(history[index + 1].kind == :redeal, 'Private final deal announcement follows its cards')
    end
    puts "PASS Scopa private #{count}/#{options}: single pool, public opening, private redeals, complete round"
  ensure
    runners.each_value(&:close)
  end
end
