require_relative '../../support/private_card_games'
require_relative '../../../games/bouillabaisse'

game=GameRoomGames::Bouillabaisse.new
h,runners=PrivateCardGamesTest.create(game,users:%w[Alice Bob Carol])
injected=false
begin
  51.times do
    replay=h.replay('Alice')
    actor=replay.current_player
    mine=h.replay(actor)
    legal=game.legal_actions(mine,actor)
    off=mine.state[:hands][actor].find { |card| legal.none? { |action| action['card']==card } }
    if off && !injected
      receipt=GameRoomPrivateCardLedger.locate(mine.state,actor,off)
      assert(receipt,'missing own native receipt')
      status=game.action_for({'kind'=>'card','action'=>'select','zone'=>'hand','card'=>off},mine,actor).first
      assert(status==:must_follow_suit,'ordinary UI permits revoke')
      # An authentic owner can expose a real card with a dishonest rule command.
      # It must not obtain a scored result merely because the receipt is genuine.
      h.write(actor,[GameRoomPrivateCards.command('play',off,**receipt.merge(operation:'reveal'))])
      injected=true
    else
      PrivateCardGamesTest.submit(h,runners,actor,legal.first)
    end
  end
  assert(injected,'fixture did not contain a revoke')
  h.users.each do |user|
    replay=h.replay(user)
    assert(replay.state[:private_error]==:invalid_round,'false follow-suit claim was not caught')
    assert(replay.state[:scores].values.all?(&:zero?),'unaudited points committed')
    assert(!replay.finished? && replay.current_player.nil?,'invalid round produced a winner')
    assert(replay.history.none? { |entry| [:score,:result].include?(entry.kind) },'unproved score in public history')
    assert(game.tournament_scored_checkpoint(replay,options:game.default_options)=={'status'=>'unsupported'},'bad round exported a checkpoint')
  end
  puts 'PASS Bouillabaisse audit: authentic private-card revoke caught on all viewers before any score or tournament checkpoint'
ensure
  runners.each_value(&:close)
end
