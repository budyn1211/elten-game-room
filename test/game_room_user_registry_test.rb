require_relative "../lib/game_room_user_registry"

def assert(condition, message)
  raise message if !condition
end

class FakeGameRoomUsersTable
  attr_reader :rows

  def initialize(rows = [], insertion_user: "Alice")
    @rows = rows.map(&:dup)
    @insertion_user = insertion_user
    @next_id = @rows.map { |row| row["__id"].to_i }.max.to_i + 1
  end

  def select(where: nil, order: nil, limit: nil, offset: nil)
    selected = @rows.select do |row|
      where == nil || where.all? { |key, value| row[key].to_s == value.to_s }
    end
    order.to_a.reverse_each do |key, direction|
      selected = selected.sort_by { |row| row[key].to_i }
      selected.reverse! if direction.to_s == "desc"
    end
    selected.drop(offset.to_i).take(limit.to_i).map(&:dup)
  end

  def insert(values)
    row = values.merge("__id" => @next_id, "__insertion_user" => @insertion_user)
    @next_id += 1
    @rows << row
    row.dup
  end

  def update(id, values)
    row = @rows.find { |candidate| candidate["__id"].to_i == id.to_i }
    raise "missing row" if row == nil

    row.merge!(values)
    row.dup
  end
end

table = FakeGameRoomUsersTable.new
registry = GameRoomUserRegistry.new(server_tables: { "game_room_users" => table })

created = registry.register(username: "Alice", version: "0.1.0", build_id: 125, capabilities: %w[invitations])
assert(created["registered_at"].to_i > 0, "registration time was not stored")
assert(table.rows.length == 1, "the first launch did not create one registry row")

registered_at = table.rows.first["registered_at"]
registry.register(username: "Alice", version: "0.2.0", build_id: 126, capabilities: %w[invitations games])
assert(table.rows.length == 1, "a later launch duplicated the registry row")
assert(table.rows.first["build_id"] == 126, "the registry build was not updated")
assert(table.rows.first["registered_at"] == registered_at, "a launch changed the original registration time")

table.rows << {
  "__id" => 20,
  "__insertion_user" => "Mallory",
  "username" => "Bob",
  "registered_at" => 1
}
table.rows << {
  "__id" => 21,
  "__insertion_user" => "Carol",
  "username" => "carol",
  "registered_at" => 2
}
candidates = registry.registered(["Alice", "Bob", "Carol", "Dave"])
assert(candidates == ["Alice", "Carol"], "the registry accepted a spoofed or unregistered user")

puts "Game Room user registry tests passed"
