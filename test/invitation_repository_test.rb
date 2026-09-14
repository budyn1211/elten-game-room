require_relative "../lib/invitation_repository"

def assert(condition, message)
  raise message if !condition
end

class FakeInvitationTable
  attr_reader :rows

  def initialize(rows = [])
    @rows = rows.map(&:dup)
    @next_id = @rows.map { |row| row["__id"].to_i }.max.to_i + 1
  end

  def insert(values)
    row = values.merge("__id" => @next_id, "__insertion_user" => values["sender"] || values["recipient"])
    @next_id += 1
    @rows << row
    row.dup
  end

  def select(where:, order:, limit:)
    selected = @rows.select do |row|
      where.all? { |key, value| row[key].to_s == value.to_s }
    end
    order.to_a.reverse_each do |key, direction|
      selected = selected.sort_by { |row| row[key].to_i }
      selected.reverse! if direction.to_s == "desc"
    end
    selected.take(limit.to_i).map(&:dup)
  end
end

invitations = FakeInvitationTable.new
responses = FakeInvitationTable.new
repository = InvitationRepository.new(
  server_tables: {
    "invitations" => invitations,
    "invitation_responses" => responses
  }
)
table = { "__id" => 7, "status" => "waiting", "name" => "Alice's table" }

created = repository.create(table: table, sender: "Alice", recipient: "Bob", now: 100, ttl: 60)
assert(created.created?, "the first invitation was not created")
duplicate = repository.create(table: table, sender: "alice", recipient: "Bob", now: 110, ttl: 60)
assert(!duplicate.created?, "a duplicate invitation was created")

pending = repository.pending_for("Bob", tables: [table], now: 120)
assert(pending.length == 1 && pending.first.table_id == 7, "a valid invitation was not listed")
repository.respond(pending.first, recipient: "Bob", response: "accepted", now: 125)
assert(repository.pending_for("Bob", tables: [table], now: 126).empty?, "an accepted invitation remained pending")

expired = repository.create(table: table, sender: "Alice", recipient: "Carol", now: 200, ttl: 5)
assert(expired.created?, "an invitation for another user was not created")
assert(repository.pending_for("Carol", tables: [table], now: 206).empty?, "an expired invitation remained pending")
assert(repository.pending_for("Carol", tables: [table.merge("status" => "closed")], now: 202).empty?, "a closed table invitation remained pending")

class FakeNativeInvitationTransport
  attr_reader :pending

  def initialize(pending)
    @pending = pending
  end

  def live_store?
    true
  end

  def pending_invitations
    @pending.map(&:dup)
  end
end

native_row = {
  "__id" => 91,
  "table_id" => 7,
  "sender" => "Alice",
  "recipient" => "Bob",
  "status" => "pending",
  "created_at" => 300,
  "expires_at" => 600
}
native_transport = FakeNativeInvitationTransport.new([native_row])
native_repository = InvitationRepository.new(transport: native_transport)
native_pending = native_repository.pending_for("Bob", tables: [table], now: 350)
assert(native_pending.length == 1, "a native invitation was not listed")
native_repository.respond(native_pending.first, recipient: "Bob", response: "accepted", now: 351)
assert(native_repository.pending_for("Bob", tables: [table], now: 352).empty?, "a locally resolved native invitation reappeared")

puts "Invitation repository tests passed"
