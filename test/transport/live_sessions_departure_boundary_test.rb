require_relative '../support/native_live_sessions'

def departure_fixture(user: 'Bob')
  broker = NativeLiveSessionsBroker.new
  transports = %w[Alice Bob Carol].to_h do |name|
    [name, GameRoomTransport.new(ProgramDouble.new(broker.endpoint(name)))]
  end
  table = transports['Alice'].create_room(name: 'Departure', game: 'uno', owner: 'Alice', game_options: '{}')
  transports['Bob'].join_room(table, 'Bob')
  [broker, transports, table, broker.endpoint(user).sessions.first]
end

# A failed native Session#leave emits on_closed even though the server has
# not removed the participant. The application must use a confirmed boundary,
# for guests and observers as well as for the final owner's table closure.
[:leave, :close].each do |operation|
  user = operation == :close ? 'Alice' : 'Bob'
  broker, transports, table, native = departure_fixture(user: user)
  endpoint = broker.endpoint(user)
  method = "#{operation}_session"
  original = endpoint.method(method)
  endpoint.define_singleton_method(method) { |_session| raise EltenAPI::LiveSessions::TimeoutError, 'offline before departure' }
  transport = transports.fetch(user)
  begin
    transport.deactivate_table(table_id: table['__id'])
    raise 'Failed departure was reported as successful'
  rescue EltenAPI::LiveSessions::TimeoutError
  end
  assert(!native.closed?, "#{operation}: failed departure closed the local membership")
  assert(transport.active_membership?(table['__id']), "#{operation}: failed departure forgot the visit")
  assert(broker.cores.fetch(table['__live_session_id']).participants.key?(user.downcase), 'Server membership was lost')
  assert(transport.consume_recovery(table['__id']) != :closed, 'Failure was delivered as confirmed server closure')
  endpoint.define_singleton_method(method, original)
  assert(transport.deactivate_table(table_id: table['__id']), 'Retry failed')
  assert(!transport.active_membership?(table['__id']), 'Acknowledged departure retained its visit')
end

# A lost reply is not an acknowledgement. A retry for the same membership
# may confirm its absence; it must not create/join a new session to find out.
broker, transports, table, native = departure_fixture
endpoint, calls = broker.endpoint('Bob'), 0
endpoint.define_singleton_method(:leave_session) do |session|
  calls += 1
  if calls == 1
    session.remote_leave
    raise EltenAPI::LiveSessions::TimeoutError, 'reply lost after departure'
  end
  raise EltenLink::Error.new('Membership no longer exists', code: 'apps.live_sessions.membership_required')
end
begin
  transports['Bob'].deactivate_table(table_id: table['__id'])
  raise 'Lost reply was accepted as an acknowledgement'
rescue EltenAPI::LiveSessions::TimeoutError
end
assert(!native.closed? && transports['Bob'].active_membership?(table['__id']), 'Uncertain departure erased its identity')
assert(transports['Bob'].deactivate_table(table_id: table['__id']), 'Absence did not resolve the same departure')
assert(calls == 2 && broker.cores.size == 1 && !native.owner?, 'Recovery created another table or changed ownership')

puts 'PASS confirmed departure: member/owner, failure before request, lost reply, exact retry, no false closure'

broker, transports, table, native = departure_fixture(user: 'Alice')
lobby = LobbyRepository.new(ProgramDouble.new(broker.endpoint('Alice')), transport: transports['Alice'], server_tables: {})
endpoint = broker.endpoint('Alice')
original = endpoint.method(:leave_session)
endpoint.define_singleton_method(:leave_session) { |_| raise EltenAPI::LiveSessions::TimeoutError, 'offline after host transfer' }
begin
  lobby.leave_table(table, 'Alice')
  raise 'Incomplete host departure succeeded'
rescue EltenAPI::LiveSessions::TimeoutError
end
core = broker.cores.fetch(table['__live_session_id'])
assert(core.owner == 'Bob' && core.participants.keys.sort == %w[alice bob], 'Transfer/departure boundary lost an unconfirmed member')
assert(!native.closed? && transports['Alice'].active_membership?(table['__id']), 'Failed departure after transfer returned a closed visit')
endpoint.define_singleton_method(:leave_session, original)
assert(lobby.leave_table(table, 'Alice') == :left && core.owner == 'Bob' && core.participants.keys == ['bob'], 'Retry failed to finish the original departure')

broker, transports, table, native = departure_fixture
transports['Bob'].set_observer(table, true, actor: 'Bob')
assert(transports['Bob'].deactivate_table(table_id: table['__id']), 'Observer could not leave')
assert(broker.cores.fetch(table['__live_session_id']).participants.keys == ['alice'], 'Observer departure touched the host')

# A completed old request is not permission to discard a newer visit to the
# same table. Keep the existing attachment and stale-callback protections.
broker, transports, table, native = departure_fixture
endpoint = broker.endpoint('Bob')
store = transports['Bob'].instance_variable_get(:@live_store)
fresh = nil
endpoint.define_singleton_method(:leave_session) do |session|
  session.remote_leave
  fresh = add_view(broker.cores.fetch(table['__live_session_id']))
  store.send(:attach_session, table['__id'], fresh)
  true
end
begin
  transports['Bob'].deactivate_table(table_id: table['__id'])
  raise 'An old departure was reported as leaving the new visit'
rescue GameRoomNetworkErrors::GamePaused
end
assert(store.send(:active_session, table['__id']).equal?(fresh), 'Old departure erased a new membership')
puts 'PASS host transfer then failed leave/retry, observer departure, concurrent rejoin identity'
