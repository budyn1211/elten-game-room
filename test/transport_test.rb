require_relative "../lib/game_room_transport"

def assert(condition, message)
  raise message if !condition
end

class FakeTransportBackend
  attr_reader :messages, :activations, :deactivations

  def initialize
    @messages = []
    @activations = []
    @deactivations = []
  end

  def publish(users:, packet:)
    @messages << { users: users, packet: packet }
    GameRoomTransport::DeliveryResult.new(status: :sent, recipients: users)
  end

  def activate_table(**options)
    @activations << options
    true
  end

  def deactivate_table(table_id:)
    @deactivations << table_id
    true
  end
end

backend = FakeTransportBackend.new
transport = GameRoomTransport.new(nil, backend: backend)
assert(
  transport.activate_table(table_id: 7, owner: "Alice", capacity: 4),
  "transport did not activate a table backend"
)
assert(backend.activations == [{ table_id: 7, owner: "Alice", capacity: 4 }], "table activation changed its arguments")

transport.table_changed(
  table_id: 7,
  users: ["Alice", "Bob", "bot:7:1", "bob", "Carol"],
  actor: "alice"
)
message = backend.messages.last
assert(message[:users] == ["Bob", "Carol"], "transport did not normalize recipients")
assert(message[:packet]["version"] == GameRoomTransport::PROTOCOL_VERSION, "table packet has no protocol version")
assert(message[:packet]["actor"] == "alice", "table packet has no authenticated actor")
assert(message[:packet]["packet_id"].to_s.length == 36, "table packet has no unique identifier")
assert(message[:packet]["type"] == "game_room_table_changed", "table packet has an invalid type")
assert(message[:packet]["table_id"] == 7, "table packet has an invalid table id")

transport.table_joined(
  table_id: 7,
  users: ["Alice", "Bob", "Carol"],
  actor: "Carol"
)
message = backend.messages.last
assert(message[:users] == ["Alice", "Bob"], "table join did not normalize fallback recipients")

transport.game_changed(
  table_id: 7,
  session_id: 19,
  users: ["Alice", "Bob"],
  change: "started",
  actor: "Alice"
)
message = backend.messages.last
assert(message[:users] == ["Bob"], "game transport notified the actor")
assert(message[:packet]["session_id"] == 19, "game packet has an invalid session id")

game_packet = message[:packet]
assert(transport.receive("Alice", game_packet), "a valid game signal was rejected")
received_at = transport.consume_game_change(19)
assert(received_at.is_a?(Numeric), "game change did not preserve its receive timestamp")
assert(!transport.consume_game_change(19), "game change was consumed twice")
assert(transport.consume_game_start(7) == 19, "game start was not queued")
assert(transport.consume_game_start(7) == nil, "game start was consumed twice")
assert(!transport.receive("Alice", game_packet), "a duplicate signal was accepted")
assert(!transport.consume_game_change(19), "a duplicate signal queued another refresh")

table_packet = backend.messages.first[:packet]
assert(transport.receive("alice", table_packet), "a valid table signal was rejected")
second_table_packet = table_packet.merge("packet_id" => "d26ec4bf-c798-455a-971f-acce95068c03")
assert(transport.receive("alice", second_table_packet), "a second valid table signal was rejected")
assert(transport.consume_table_change(7), "table change was not queued")
assert(!transport.consume_table_change(7), "rapid table changes caused duplicate room refreshes")

forged = table_packet.merge("packet_id" => "7f6b6f14-3839-4a53-9fe6-87dbcae18489")
assert(!transport.receive("Mallory", forged), "a signal with a forged sender was accepted")
assert(!transport.consume_table_change(7), "a forged signal queued a table refresh")

old_protocol = table_packet.merge(
  "version" => 0,
  "packet_id" => "7286c61c-67ad-44cf-82ee-e5461f03dcc3"
)
assert(!transport.receive("alice", old_protocol), "an unversioned signal was accepted")

assert(transport.deactivate_table(table_id: 7), "transport did not deactivate a table backend")
assert(backend.deactivations == [7], "table deactivation changed its identifier")

class MembershipTransportBackend < FakeTransportBackend
  attr_reader :membership_requests, :accepted_invitations, :rejected_invitations, :waits
  attr_accessor :membership_ready

  def initialize
    super
    @membership_requests = []
    @accepted_invitations = []
    @rejected_invitations = []
    @waits = []
    @membership_ready = true
  end

  def request_membership(table_id:, owner:, packet:)
    @membership_requests << { table_id: table_id, owner: owner, packet: packet }
    true
  end

  def accept_invitation(table_id:, invitation_id:, participant_metadata:)
    @accepted_invitations << [table_id, invitation_id, participant_metadata]
    true
  end

  def reject_invitation(table_id:, invitation_id:)
    @rejected_invitations << [table_id, invitation_id]
    true
  end

  def wait_for_membership(table_id:, timeout:)
    @waits << [table_id, timeout]
    @membership_ready
  end
end

membership_backend = MembershipTransportBackend.new
membership_transport = GameRoomTransport.new(nil, backend: membership_backend)
membership_transport.activate_table(table_id: 21, owner: "Alice", capacity: 4, user: "Bob")
membership_transport.activate_table(table_id: 21, owner: "Alice", capacity: 4, user: "Bob")
assert(membership_backend.membership_requests.empty?, "plain table activation sent a membership bootstrap signal")
assert(
  membership_transport.establish_membership(
    table_id: 21,
    owner: "Alice",
    capacity: 4,
    user: "Bob",
    bootstrap: true,
    timeout: 0.1
  ),
  "manual membership establishment failed"
)
assert(membership_backend.membership_requests.length == 1, "one manual join sent more than one bootstrap signal")
assert(
  membership_backend.membership_requests.first[:packet]["type"] == "game_room_transport_join",
  "manual membership establishment sent an invalid bootstrap packet"
)

membership_transport.establish_membership(
  table_id: 22,
  owner: "Alice",
  capacity: 4,
  user: "Bob",
  invitation_id: 91,
  timeout: 0.1
)
assert(membership_backend.membership_requests.length == 1, "accepting an invitation sent a bootstrap signal")
assert(
  membership_backend.accepted_invitations.last == [22, 91, { "table_id" => 22 }],
  "invitation membership was not accepted through LiveSessions"
)

membership_backend.membership_ready = false
failed_membership = membership_transport.establish_membership(
  table_id: 23,
  owner: "Alice",
  capacity: 4,
  user: "Bob",
  invitation_id: 92,
  timeout: 0.0
)
assert(!failed_membership, "membership establishment ignored a LiveSessions timeout")
assert(membership_backend.rejected_invitations.last == [23, 92], "a timed-out invitation remained pending")
assert(membership_backend.deactivations.last == 23, "a timed-out membership kept an active table transport")

class RecoveringTransportBackend
  attr_reader :messages

  def initialize
    @messages = []
    @results = [
      GameRoomTransport::DeliveryResult.new(status: :no_session),
      GameRoomTransport::DeliveryResult.new(status: :no_recipient),
      GameRoomTransport::DeliveryResult.new(status: :sent, recipients: ["Bob"])
    ]
  end

  def publish(users:, packet:)
    @messages << { users: users.dup, packet: packet.dup }
    @results.shift
  end

  def activate_table(**_options)
    true
  end
end

recovering_backend = RecoveringTransportBackend.new
recovering_transport = GameRoomTransport.new(nil, backend: recovering_backend)
missing_session_result = recovering_transport.game_changed(
  table_id: 8,
  session_id: 20,
  users: ["Alice", "Bob"],
  change: "action",
  actor: "Alice"
)
assert(missing_session_result.status == :no_session, "a missing session was not reported to the caller")
assert(recovering_transport.consume_recovery(8), "a missing session did not request authoritative recovery")
recovering_transport.activate_table(table_id: 8, owner: "Alice", capacity: 2, user: "Alice")
assert(recovering_backend.messages.length == 1, "activating a session resent a stale game notification")
missing_recipient_result = recovering_transport.game_changed(
  table_id: 8,
  session_id: 20,
  users: ["Alice", "Bob"],
  change: "action",
  actor: "Alice"
)
assert(missing_recipient_result.status == :no_recipient, "a missing recipient was not reported to the caller")
assert(!recovering_transport.consume_recovery(8), "a missing recipient triggered forced session recovery")
recovering_transport.activate_table(table_id: 8, owner: "Alice", capacity: 2, user: "Alice")
assert(recovering_backend.messages.length == 2, "a missing-recipient notification was retained for resend")

class FakeFallbackBackend
  attr_reader :messages, :announced

  def initialize(delivered = [])
    @delivered = delivered
    @messages = []
    @announced = []
  end

  def publish(users:, packet:)
    @messages << { users: users, packet: packet }
    @delivered
  end

  def activate_table(**_options)
    true
  end

  def deactivate_table(**_options)
    true
  end

  def connected_users(_table_id)
    @delivered
  end

  def invite_participant(table_id:, user:)
    @announced << [table_id, user]
    true
  end
end

bootstrap_backend = Object.new
bootstrap_requests = []
bootstrap_backend.define_singleton_method(:request) do |owner:, packet:|
  bootstrap_requests << { owner: owner, packet: packet }
  true
end
live_fallback_backend = FakeFallbackBackend.new(["Bob"])
hybrid = GameRoomTransport::HybridBackend.new(bootstrap: bootstrap_backend, live: live_fallback_backend)
hybrid.publish(users: ["Bob", "Carol"], packet: table_packet)
assert(live_fallback_backend.messages.last[:users] == ["Bob", "Carol"], "LiveSessions did not see every recipient")
assert(bootstrap_requests.empty?, "a normal table update fell back to Signals")
hybrid.table_joined(users: ["Bob", "Carol"], packet: table_packet)
assert(bootstrap_requests.empty?, "a table join update fell back to Signals")
hybrid.request_membership(table_id: 7, owner: "Alice", packet: table_packet)
assert(bootstrap_requests.last[:owner] == "Alice", "membership bootstrap did not notify the table owner")
hybrid.participant_announced(table_id: 7, user: "Carol")
assert(live_fallback_backend.announced.last == [7, "Carol"], "membership bootstrap did not create a LiveSessions invitation")

class FakeLiveParticipant
  attr_reader :id, :user, :metadata

  def initialize(id, user, table_id: 7)
    @id = id
    @user = user
    @metadata = { "table_id" => table_id }
  end
end

class FakeLiveSession
  attr_reader :participants, :metadata, :sent, :invitations
  attr_accessor :send_error

  def initialize(participants, metadata, local_owner:)
    @participants = participants
    @metadata = metadata
    @local_owner = local_owner
    @closed = false
    @sent = []
    @invitations = []
  end

  def owner?
    @local_owner
  end

  def closed?
    @closed
  end

  def on_message(&block)
    @message_callback = block
  end

  def on_closed(&block)
    @closed_callback = block
  end

  def on_gap(&block)
    @gap_callback = block
  end

  def on_participant_joined(&block)
    @participant_joined_callback = block
  end

  def on_participant_left(&block)
    @participant_left_callback = block
  end

  def invite(user, metadata: {})
    @invitations << [user, metadata]
    true
  end

  def send(packet)
    raise @send_error if @send_error != nil

    @sent << packet
    true
  end

  def emit(sender, packet)
    @message_callback.call(sender, packet)
  end

  def emit_gap(from, to)
    @gap_callback.call(from, to)
  end

  def emit_joined(participant)
    @participants << participant
    @participant_joined_callback&.call(participant)
  end

  def close
    @closed = true
    @closed_callback&.call(:closed)
    true
  end

  def leave
    @closed = true
    @closed_callback&.call(:left)
    true
  end
end

class FakeLiveEndpoint
  attr_reader :user, :created

  def initialize(user, session, pending_invitations: [])
    @user = user
    @session = session
    @created = []
    @pending_invitations = pending_invitations.dup
  end

  def create(**options)
    @created << options
    @session
  end

  def on_invitation(&block)
    @invitation_callback = block
  end

  def emit_invitation(invitation)
    @invitation_callback.call(invitation)
  end

  def next_invitation(timeout: nil)
    @pending_invitations.shift
  end
end


class FakeIncomingInvitation
  attr_reader :metadata, :invitation_metadata, :accepted_metadata, :state

  def initialize(session, table_id:, invitation_id: 0, purpose: "game_invitation", owner: "Alice")
    @session = session
    @metadata = {
      "kind" => GameRoomTransport::LIVE_SESSION_KIND,
      "protocol" => GameRoomTransport::LIVE_SESSION_PROTOCOL,
      "table_id" => table_id,
      "owner" => owner
    }
    @invitation_metadata = { "purpose" => purpose, "invitation_id" => invitation_id }
    @state = :pending
  end

  def pending?
    @state == :pending
  end

  def accept(participant_metadata: {})
    @accepted_metadata = participant_metadata
    @state = :accepted
    @session
  end

  def reject
    @state = :rejected
    true
  end
end

alice = FakeLiveParticipant.new("1", "Alice")
bob = FakeLiveParticipant.new("2", "Bob")
session = FakeLiveSession.new(
  [alice, bob],
  {
    "kind" => GameRoomTransport::LIVE_SESSION_KIND,
    "protocol" => GameRoomTransport::LIVE_SESSION_PROTOCOL,
    "table_id" => 7,
    "owner" => "Alice"
  },
  local_owner: true
)
endpoint = FakeLiveEndpoint.new("Alice", session)
received = []
membership_changes = []
gaps = []
live = GameRoomTransport::LiveSessionBackend.new(
  nil,
  receiver: ->(user, packet) { received << [user, packet] },
  membership_receiver: ->(table_id, user, change) { membership_changes << [table_id, user, change] },
  gap_receiver: ->(table_id, from, to) { gaps << [table_id, from, to] },
  endpoint_provider: -> { endpoint }
)
missing_session = live.publish(users: ["Bob"], packet: table_packet)
assert(missing_session.status == :no_session, "LiveSessions hid a missing session behind an empty recipient list")
assert(live.send(:session_capacity, 10) == 8, "LiveSessions capacity was not capped at 8")
assert(live.activate_table(table_id: 7, owner: "Alice", capacity: 4), "LiveSessions owner session was not created")
assert(endpoint.created.last[:capacity] == 4, "LiveSessions table has the wrong capacity")
assert(endpoint.created.last[:metadata]["table_id"] == 7, "LiveSessions table metadata lost its table id")
assert(live.invite_user(table_id: 7, user: "Carol", metadata: { "invitation_id" => 12 }), "LiveSessions invitation was not sent")
assert(
  session.invitations.last == ["Carol", { "invitation_id" => 12, "purpose" => "game_invitation" }],
  "LiveSessions invitation changed its metadata"
)

incoming = FakeIncomingInvitation.new(session, table_id: 7, invitation_id: 12)
endpoint.emit_invitation(incoming)
assert(
  live.accept_invitation(table_id: 7, invitation_id: 12, participant_metadata: { "table_id" => 7 }),
  "incoming LiveSessions invitation was not accepted"
)

carol = FakeLiveParticipant.new("3", "Carol")
session.emit_joined(carol)
assert(membership_changes.last == [7, "Carol", :joined], "participant join did not queue a table refresh")

live_packet = table_packet.merge("packet_id" => "2d5e5030-dd74-4cdb-ae4d-a98464bc7272")
delivered = live.publish(users: ["Bob", "Dave"], packet: live_packet)
assert(delivered.status == :sent, "LiveSessions did not report a successful publish")
assert(delivered.recipients == ["Bob"], "LiveSessions did not report its connected recipient")
assert(session.sent.last == live_packet, "LiveSessions changed the published packet")
missing_recipient = live.publish(users: ["Dave"], packet: live_packet)
assert(missing_recipient.status == :no_recipient, "LiveSessions hid a missing recipient")
session.send_error = RuntimeError.new("simulated transport failure")
failed_delivery = live.publish(users: ["Bob"], packet: live_packet)
assert(failed_delivery.status == :failed, "LiveSessions hid a failed send")
assert(failed_delivery.error.message == "simulated transport failure", "LiveSessions lost the send error")
session.send_error = nil

session.emit(bob, live_packet)
assert(received == [["Bob", live_packet]], "LiveSessions did not pass an incoming packet to the transport")
session.emit_gap(8, 10)
assert(gaps.last == [7, 8, 10], "a LiveSessions gap did not request reconciliation")
assert(live.deactivate_table(table_id: 7), "LiveSessions owner session was not closed")
assert(session.closed?, "LiveSessions owner session remained open")

member_session = FakeLiveSession.new([alice, bob], session.metadata, local_owner: false)
member_endpoint = FakeLiveEndpoint.new("Bob", member_session)
member_live = GameRoomTransport::LiveSessionBackend.new(
  nil,
  receiver: ->(_user, _packet) {},
  endpoint_provider: -> { member_endpoint }
)
assert(!member_live.activate_table(table_id: 7, owner: "Alice", capacity: 4), "a table member created the owner's LiveSession")
membership_invitation = FakeIncomingInvitation.new(
  member_session,
  table_id: 7,
  purpose: "table_membership",
  owner: "Alice"
)
member_endpoint.emit_invitation(membership_invitation)
assert(membership_invitation.accepted_metadata == { "table_id" => 7 }, "active table membership was not accepted automatically")
assert(member_live.connected_users(7).sort == ["Alice", "Bob"], "accepted LiveSessions membership was not attached")
assert(member_live.wait_for_membership(table_id: 7, timeout: 0.0), "attached membership was not observable by its waiter")

late_session = FakeLiveSession.new([alice, bob], session.metadata, local_owner: false)
late_endpoint = FakeLiveEndpoint.new("Bob", late_session)
late_live = GameRoomTransport::LiveSessionBackend.new(
  nil,
  receiver: ->(_user, _packet) {},
  endpoint_provider: -> { late_endpoint }
)
late_live.start
late_membership = FakeIncomingInvitation.new(
  late_session,
  table_id: 7,
  purpose: "table_membership",
  owner: "Alice"
)
late_endpoint.emit_invitation(late_membership)
assert(late_membership.state == :rejected, "a membership invitation was accepted after the join attempt ended")
assert(!late_live.wait_for_membership(table_id: 7, timeout: 0.0), "a rejected late invitation attached a session")

invited_session = FakeLiveSession.new([alice, bob], session.metadata, local_owner: false)
invited_endpoint = FakeLiveEndpoint.new("Bob", invited_session)
invited_live = GameRoomTransport::LiveSessionBackend.new(
  nil,
  receiver: ->(_user, _packet) {},
  endpoint_provider: -> { invited_endpoint }
)
game_invitation = FakeIncomingInvitation.new(invited_session, table_id: 7, invitation_id: 15)
invited_live.start
invited_endpoint.emit_invitation(game_invitation)
assert(
  invited_live.accept_invitation(table_id: 7, invitation_id: 15, participant_metadata: { "table_id" => 7 }),
  "an explicit table invitation did not attach its LiveSession"
)
assert(
  invited_live.activate_table(table_id: 7, owner: "Alice", capacity: 4),
  "an accepted invitation was not registered as the active table"
)
assert(invited_endpoint.created.empty?, "a member created a second LiveSession after accepting an invitation")

queued_session = FakeLiveSession.new(
  [alice, bob],
  session.metadata.merge("table_id" => 9),
  local_owner: false
)
queued_invitation = FakeIncomingInvitation.new(
  queued_session,
  table_id: 9,
  invitation_id: 25
)
queued_endpoint = FakeLiveEndpoint.new(
  "Bob",
  queued_session,
  pending_invitations: [queued_invitation]
)
queued_live = GameRoomTransport::LiveSessionBackend.new(
  nil,
  receiver: ->(_user, _packet) {},
  endpoint_provider: -> { queued_endpoint }
)
queued_live.start
assert(
  queued_live.accept_invitation(table_id: 9, invitation_id: 25, participant_metadata: { "table_id" => 9 }),
  "an invitation queued before callback registration was not recovered"
)
assert(
  queued_invitation.accepted_metadata == { "table_id" => 9 },
  "the recovered invitation did not attach its LiveSession"
)

puts "Game Room transport tests passed"
