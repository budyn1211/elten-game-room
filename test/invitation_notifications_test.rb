require_relative "../lib/invitation_notifications"

def assert(condition, message)
  raise message if !condition
end

Notification = Struct.new(:id, :app_uuid, :revoked, :payload, keyword_init: true)

class FakeNotificationGateway
  attr_reader :listed, :revoked, :revoked_many

  def initialize(notifications)
    @notifications = notifications
    @listed = []
    @revoked = []
    @revoked_many = []
  end

  def list(client, all:, app_uuids:)
    @listed << [client, all, app_uuids]
    @notifications
  end

  def revoke(client, id)
    @revoked << [client, id]
    true
  end

  def revoke_many(client, ids)
    @revoked_many << [client, ids]
    true
  end
end

uuid = "468f59c5-c9d7-47cd-80f1-1a6fbfd1aa80"
notifications = [
  Notification.new(id: 10, app_uuid: uuid, revoked: false, payload: { "type" => "game_room.invitation", "metadata" => { "invitation_id" => 7 } }),
  Notification.new(id: 11, app_uuid: uuid.upcase, revoked: false, payload: { type: "game_room.invitation", metadata: { invitation_id: 7 } }),
  Notification.new(id: 12, app_uuid: uuid, revoked: false, payload: { "type" => "game_room.invitation", "metadata" => { "invitation_id" => 8 } }),
  Notification.new(id: 13, app_uuid: "another-app", revoked: false, payload: { "type" => "game_room.invitation", "metadata" => { "invitation_id" => 7 } }),
  Notification.new(id: 14, app_uuid: uuid, revoked: true, payload: { "type" => "game_room.invitation", "metadata" => { "invitation_id" => 7 } })
]
gateway = FakeNotificationGateway.new(notifications)
cleaner = InvitationNotifications.new(client: :client, app_uuid: uuid, gateway: gateway)

count = cleaner.revoke(7)
assert(count == 2, "the cleaner did not report every matching notification")
assert(gateway.listed == [[:client, false, [uuid]]], "the cleaner did not request active notifications for its application")
assert(gateway.revoked_many == [[:client, [10, 11]]], "the cleaner revoked unrelated or incomplete notifications")

direct_gateway = FakeNotificationGateway.new([])
direct_cleaner = InvitationNotifications.new(client: :client, app_uuid: uuid, gateway: direct_gateway)
assert(direct_cleaner.revoke(7, notification_id: 42) == 1, "direct notification cleanup failed")
assert(direct_gateway.revoked == [[:client, 42]], "direct cleanup revoked the wrong notification")
assert(direct_gateway.listed.empty?, "direct cleanup performed an unnecessary notification lookup")

assert(direct_cleaner.revoke(0) == 0, "an invalid invitation id triggered cleanup")

# Removing form-wide shortcuts must preserve the independent notification
# entry point, including stale notifications and choosing the exact invitation.
require_relative "support/ui"

class Program
  def self.server_app(**_options); end
end

require_relative "../__app"

app = EltenGameRoom.allocate
transport = Object.new
transport.define_singleton_method(:start) { true }
app.instance_variable_set(:@transport, transport)
app.define_singleton_method(:initialize_services) {}
app.define_singleton_method(:run_network_task) { |_title, &operation| operation.call }
invitation = Struct.new(:id).new(7)
other = Struct.new(:id).new(8)
choices = [{ invitation: other }, { invitation: invitation }]
app.define_singleton_method(:load_pending_invitations) { choices }
action = :accept
app.define_singleton_method(:select_notification_invitation_action) { action }
received = Struct.new(:id, :metadata).new(42, { "invitation_id" => 7 })
table = { "__id" => 12 }
calls = []
app.define_singleton_method(:accept_pending_invitation) do |selected, notification_id:|
  calls << [:accept, selected.id, notification_id]
  table
end
app.define_singleton_method(:reject_pending_invitation) do |selected, notification_id:|
  calls << [:reject, selected.id, notification_id]
end
app.define_singleton_method(:revoke_invitation_notification) do |id, notification_id:|
  calls << [:revoke, id, notification_id]
end
app.define_singleton_method(:run_program_interface) { |row| calls << [:open, row] }
app.define_singleton_method(:alert) { |message| calls << [:alert, message] }

assert(app.notification_action(:unrelated, received) == false, "unrelated notification opened an invitation")
assert(app.notification_action(:open_invitation, received) == true, "invitation notification was not handled")
assert(calls == [[:accept, 7, 42], [:open, table]], "notification accepted the wrong invitation or failed to open its table")
calls.clear
action = :reject
app.notification_action(:open_invitation, received)
assert(calls == [[:reject, 7, 42]], "rejecting a notification opened a table or lost the invitation id")
calls.clear
action = nil
app.notification_action(:open_invitation, received)
assert(calls.empty?, "cancelling a notification acted on the invitation")
choices.delete_if { |choice| choice[:invitation].id == 7 }
app.notification_action(:open_invitation, received)
assert(calls == [[:revoke, 7, 42], [:alert, "This invitation is no longer available."]], "expired notification did not explain its removal")

puts "Invitation notification tests passed"
