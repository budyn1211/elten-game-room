require_relative '../support/private_card_games'
require_relative '../../games/catalog'

%w[bouillabaisse scopa].each do |id|
  game=GameRoomGames::CATALOG.build(id)
  h,runners=PrivateCardGamesTest.create(game,users:%w[Alice Bob Carol])
  begin
    original=h.replay('Bob').state[:hands]['Bob'].dup
    before_takes=h.core.entries.count { |entry| entry.dig('pool','operation')=='take' }
    runners['Bob'].close
    h.view('Bob').leave
    h.add_client('Bob')
    assert(h.join('Bob'),'cold return rejected')
    runners['Bob']=runner_for(h,'Bob')
    PrivateCardGamesTest.tick(h,runners)
    assert(h.replay('Bob').state[:hands]['Bob']==original,'return drew different cards')
    assert(h.core.entries.count { |entry| entry.dig('pool','operation')=='take' }==before_takes,'return took cards again')
    h.view('Alice').transfer_ownership(h.view('Alice').participants.find { |part| part.user=='Carol' })
    PrivateCardGamesTest.tick(h,runners)
    h.instance_variable_set(:@session,h.repositories['Carol'].snapshot_for(h.session).session)
    PrivateCardGamesTest.assert_private(h)
    assert(game.save_game_error(h.replay('Carol')),'private save enabled')
    assert(game.participant_replacement_error(h.replay('Carol'),player:'Bob'),'private replacement enabled')
    actor=h.replay('Carol').current_player
    mine=h.replay(actor)
    selection=game.legal_actions(mine,actor).first
    status,plan=game.action_for(selection,mine,actor,context:GameRoomGames::ActionContext.new(table_owner:'Carol'))
    assert(status==:ok && GameRoomPrivateCards.request_from(plan.events)['operation']=='reveal','play did not require native proof')
    h.broker.automatic_delivery=false
    h.view(actor).fail_next_push=:after
    assert_raises(EltenAPI::LiveSessions::TimeoutError) { h.write(actor,plan.events) }
    h.transports[actor].reconcile(h.table['__id'])
    h.broker.automatic_delivery=true
    h.broker.deliver(duplicate:true)
    PrivateCardGamesTest.assert_private(h)
    assert(h.events(actor).count { |event| event['action']=='play' }==1,'lost reply duplicated card')
    6.times do
      actor=h.replay('Carol').current_player
      break unless actor
      PrivateCardGamesTest.submit(h,runners,actor,game.legal_actions(h.replay(actor),actor).first)
    end
    PrivateCardGamesTest.assert_private(h)
    puts "PASS #{id}: account return, host transfer, foreign-hand isolation, lost reveal ACK, continued private play"
  ensure
    runners.each_value(&:close)
  end
end
