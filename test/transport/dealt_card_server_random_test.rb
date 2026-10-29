require_relative '../support/session_runner'
require_relative '../../games/catalog'

class NoDealtCardEntropy
  def roll(**); raise 'Native deal used local entropy'; end
end
%w[bouillabaisse scopa].each do |id|
  game=GameRoomGames::CATALOG.build(id)
  h=NativeRoomHarness.new(game:game)
  h.start
  context=GameRoomGames::ActionContext.new(server_random:true,random_source:NoDealtCardEntropy.new)
  status,plan=game.action_for({'kind'=>'command','action'=>'deal'},h.replay('Alice'),'Alice',context:context)
  assert(status==:ok,'no deal plan')
  h.broker.automatic_delivery=false
  h.view('Alice').fail_next_push=:after
  assert_raises(EltenAPI::LiveSessions::TimeoutError) { h.write('Alice',plan.events) }
  h.transports['Alice'].reconcile(h.table['__id'])
  h.broker.automatic_delivery=true
  h.broker.deliver(duplicate:true)
  h.assert_converged(id,expected_count:1)
  assert(h.view('Alice').calls[:random]==1,'deal rerolled after lost reply')
  assert(h.replay('Alice').state[:phase]==:playing,'deal not accepted')
  forged=NativeRoomHarness.new(game:game)
  forged.start
  forged.write('Alice',[GameRoomServerRandom.command(action:'deal',count:1,sides:2)])
  assert(forged.replay('Alice').accepted_events.empty?,'wrong random recipe accepted')
end
puts 'PASS new card native randomness: public dealer/deck, no client entropy, exactly one write, lost ACK, forged recipe'
