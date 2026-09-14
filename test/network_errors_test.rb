require_relative "support/ui"
require_relative "support/log"

class Program
  def self.server_app(**_options); end
end

module EltenLink
  class Error < StandardError; end
end
module EltenAPI
  module LiveSessions
    class Error < StandardError; end
    class TimeoutError < Error; end
    class SessionClosed < Error; end
    class StackFull < Error; end
  end
  module Tasks
    class Cancelled < StandardError; end unless const_defined?(:Cancelled)
    def self.run(**_options)
      token = Object.new
      def token.raise_if_cancelled!; end
      yield nil, token
    end
  end
end
require_relative "../__app"

def assert(value, message); raise message unless value; end

[[EltenGameRoom, :run_network_task], [GameScreen, :network_task]].each do |klass, method|
  target = klass.allocate
  target.define_singleton_method(:announce_server_table_access) { nil }
  alerts = []
  target.define_singleton_method(:alert) { |text| alerts << text }
  [EltenLink::Error, EltenAPI::LiveSessions::TimeoutError,
    EltenAPI::LiveSessions::SessionClosed, EltenAPI::LiveSessions::StackFull].each do |error|
    before = alerts.length
    result = target.send(method, "Network operation") { raise error, "test failure" }
    assert(result == nil && alerts.length == before + 1, "#{klass} did not handle #{error}")
    target.send(method, "Background update", silent: true) { raise error, "test failure" }
    assert(alerts.length == before + 1, "#{klass} announced a silent failure")
  end
  assert(target.send(method, "Cancelled") { raise EltenAPI::Tasks::Cancelled } == nil, "cancellation escaped")
  begin
    target.send(method, "Bug") { raise NoMethodError, "programming error" }
    raise "#{klass} swallowed a programming error"
  rescue NoMethodError
    # Unexpected errors must retain their useful diagnostic stack trace.
  end
  assert(target.send(method, "Success") { :ok } == :ok, "success changed")
end

# Exercise the actual invitation UI path as well: neither false nor an
# exception from native delivery may send a fallback notification or say sent.
module Session
  def self.name; "Bob"; end
end
module EltenLink
  class Client; end
  module Users
    def self.online(_client); ["Carol", "Eve"]; end
  end
  module Contacts
    def self.list(_client); ["Carol", "Dana"]; end
  end
end
[:online, :contacts].each do |source|
  app = EltenGameRoom.allocate
  app.define_singleton_method(:invitation_sending_available?) { true }
  app.define_singleton_method(:announce_server_table_access) { nil }
  offered_users = []
  app.define_singleton_method(:select_invitation_recipient) do |users, _header|
    offered_users << users.dup
    users.first
  end
  app.define_singleton_method(:invitation_metadata) { |_row, id| { "invitation_id" => id } }
  table = { "__id" => 7, "owner" => "Alice" }
  snapshot = LobbyRepository::TableSnapshot.new(table: table, members: %w[Alice Bob], bots: [])
  lobby = Object.new
  lobby.define_singleton_method(:snapshot_for) { |_row| snapshot }
  lobby.define_singleton_method(:table_id) { |_row| 7 }
  registry = Object.new
  registry.define_singleton_method(:registered) { |users| users }
  transport = Object.new
  transport.define_singleton_method(:live_store?) { true }
  outcome = false
  transport.define_singleton_method(:invite_user) do |**_arguments|
    raise outcome if outcome.is_a?(Exception)
    outcome
  end
  app.instance_variable_set(:@lobby, lobby)
  app.instance_variable_set(:@game_room_users, registry)
  app.instance_variable_set(:@transport, transport)
  app.instance_variable_set(:@invitations, InvitationRepository.new(transport: transport))
  notifications = []
  alerts = []
  app.define_singleton_method(:alert) { |text| alerts << text }
  app.define_singleton_method(:send_notification) { |*args, **options| notifications << [args, options] }
  [false, EltenAPI::LiveSessions::TimeoutError.new("timeout")].each do |failure|
    outcome = failure
    app.send(:show_invite_users, table, source: source)
    assert(notifications.empty? && !alerts.include?("Invitation sent."), "#{source} announced an unsent invitation")
  end
  outcome = true
  app.send(:show_invite_users, table, source: source)
  assert(notifications.length == 1 && alerts.last == "Invitation sent.", "#{source} did not recover after delivery failure")
  expected_users = source == :contacts ? ["Carol"] : ["Carol", "Eve"]
  assert(offered_users.all? { |users| users == expected_users }, "#{source} invitation candidates do not respect online contacts")
end
puts "Native network error boundaries passed"
