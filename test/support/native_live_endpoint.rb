require_relative 'host_source'
require EltenTestHost.file('src/eapi/live_sessions.rb')

# Use the host's constructor so new queue/dispatch guards are not omitted by
# an Endpoint.allocate fixture. There are no sessions, profile or real token;
# only local callback delivery is allowed in these UI regressions.
module NativeLiveEndpointFixture
  class Client
    attr_reader :context

    def initialize(context)
      @context = context
    end

    def api_data(*)
      raise 'Unexpected network request in callback fixture'
    end
  end

  def self.build(context:)
    endpoint = EltenAPI::LiveSessions::Endpoint.new(
      app_id: 'ef8a0700-2d36-411b-ae13-6e6811a63a78',
      client: Client.new(context), user: 'offline-fixture', token: 'offline-fixture'
    )
    endpoint.define_singleton_method(:protocol_tick) { raise 'UI performed protocol/network work' }
    endpoint.define_singleton_method(:tick) { raise 'UI ticked the whole endpoint' }
    at_exit do
      endpoint.close
      EltenAPI::LiveSessions.unregister(endpoint)
    end
    endpoint
  end
end
