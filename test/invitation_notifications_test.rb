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

puts "Invitation notification tests passed"
