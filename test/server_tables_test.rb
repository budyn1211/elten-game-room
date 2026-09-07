module EltenLink
  module Apps
    class << self
      attr_reader :table_calls

      def table(client, uuid, name)
        @table_calls ||= []
        object = Object.new
        @table_calls << [client, uuid, name, object]
        object
      end
    end
  end
end

require_relative "../lib/game_room_server_tables"

def assert(condition, message)
  raise message if !condition
end

program = Struct.new(:server_app_uuid).new("server-uuid")
client = Object.new
tables = GameRoomServerTables.new(program, client: client)
first = tables.fetch("tables")
second = tables.fetch("tables")
events = tables.fetch("game_events")

assert(first.equal?(second), "a server table object was recreated")
assert(!first.equal?(events), "different server tables shared one object")
assert(EltenLink::Apps.table_calls.length == 2, "the provider repeated a table lookup")
assert(
  EltenLink::Apps.table_calls.all? { |call| call[0].equal?(client) && call[1] == "server-uuid" },
  "the provider did not reuse its context-free client and declared UUID"
)

puts "Server table provider tests passed"
