require_relative '../support/native_live_sessions'

# Actual host SDK and EltenLink acknowledgement wrappers. Only HTTP is fake;
# no private SDK state is used by the production adapter.
module EltenLink
  class Client
    DEFAULT_TIMEOUT = 45 unless const_defined?(:DEFAULT_TIMEOUT)
  end
end
require EltenTestHost.file('src/eltenlink/apps.rb')
require EltenTestHost.file('src/eapi/live_sessions.rb')

class DepartureHttpClient
  attr_accessor :fault
  attr_reader :calls, :present
  def initialize
    @calls, @present = [], true
  end
  def api_data(method, path, params, **options)
    @calls << [method, path, params, options]
    fault, @fault = @fault, nil
    raise EltenAPI::LiveSessions::TimeoutError, 'offline before RPC' if fault == :before
    raise EltenLink::Error.new('account unavailable', code: 'auth.unauthorized') if fault == :auth
    raise EltenLink::Error.new('not a member', code: 'apps.live_sessions.membership_required') unless @present
    @present = false
    raise EltenAPI::LiveSessions::TimeoutError, 'lost RPC reply' if fault == :after
    {}
  end
end

def native_departure_fixture(owner: false)
  client = DepartureHttpClient.new
  endpoint = EltenAPI::LiveSessions::Endpoint.new(app_id: '00000000-0000-4000-8000-000000000001',
    client: client, user: 'Bob', token: 'headless-test-no-network')
  session = endpoint.send(:store_session, {'id' => 'headless-departure',
    'participant_id' => 'member-bob', 'owner_id' => owner ? 'member-bob' : 'member-alice',
    'participants' => [{'id' => 'member-bob', 'user' => 'Bob'}, {'id' => 'member-alice', 'user' => 'Alice'}]})
  store = GameRoomLiveSessionStore.new(ProgramDouble.new(endpoint))
  store.instance_variable_set(:@endpoint, endpoint)
  store.instance_variable_get(:@sessions)[7] = session
  room = store.send(:room_state, 7)
  room.attachment = Object.new
  yield store, session, endpoint, client
ensure
  store&.instance_variable_get(:@discovery_work)&.close
  endpoint&.close
  EltenAPI::LiveSessions.unregister(endpoint) if endpoint
end

# Prove the host's original failure behavior, rather than simulating its
# conclusion with a test double's closed flag.
native_departure_fixture do |_store, session, endpoint, client|
  client.fault = :before
  begin
    session.leave
    raise 'Native fixture did not fail'
  rescue EltenAPI::LiveSessions::TimeoutError
  end
  assert(session.closed? && client.present, 'Host failure behavior changed; reassess the adapter')
  assert(endpoint.diagnostics[:pending_departures] == 1, 'Unconfirmed host departure was not deferred')
end

[false, true].each do |owner|
  [:before, :after, :auth].each do |fault|
    native_departure_fixture(owner: owner) do |store, session, endpoint, client|
      client.fault = fault
      begin
        store.deactivate_room(7)
        raise 'Failed/unconfirmed departure was reported successful'
      rescue EltenAPI::LiveSessions::TimeoutError, EltenLink::Error
      end
      assert(!session.closed? && store.active_membership?(7), 'Adapter discarded the exact unresolved membership')
      assert(endpoint.diagnostics[:pending_departures] == 0, 'Adapter raced a second host departure queue')
      assert(store.deactivate_room(7), 'Acknowledgement/confirmed absence did not finish departure')
      assert(session.closed? && !store.active_membership?(7), 'Confirmed departure did not clean up locally')
      assert(client.calls.size == 2, 'Departure retried independently or performed extra network operations')
      assert(client.calls.all? { |row| row[2] == {'participant_id' => 'member-bob'} }, 'Retry changed the membership identity')
      suffix = owner ? '/close' : '/leave'
      assert(client.calls.all? { |row| row[1].end_with?(suffix) }, 'Retry changed the requested operation')
    end
  end
end
native_departure_fixture do |store, session, endpoint, client|
  client.fault = :before
  begin
    store.deactivate_room(7, deferred: true)
    raise 'Provisional cleanup did not preserve the RPC error'
  rescue EltenAPI::LiveSessions::TimeoutError
  end
  assert(session.closed? && endpoint.diagnostics[:pending_departures] == 1,
    'Rejected provisional membership lost the SDK deferred cleanup')
end
puts 'PASS actual native departure SDK: leave/close, pre-RPC failure, lost reply, auth refusal, exact identity, confirmed cleanup'
