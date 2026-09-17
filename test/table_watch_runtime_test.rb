require_relative "game_room_settings_widget_test"

Notice2 = Struct.new(:id, :app_uuid, :type, :sender, :metadata, keyword_init: true)
now = 2_000_000_000
EltenGameRoom.define_singleton_method(:server_app_uuid) { "468f59c5-c9d7-47cd-80f1-1a6fbfd1aa80" }
uuid = EltenGameRoom.server_app_uuid
session_id = "cP44FMhoJwxaQ80Rm02_JY0K9QxAsveo"
notice = Notice2.new(id: 500, app_uuid: uuid, type: GameRoomTableWatch::TYPE, sender: "Bob",
  metadata: { "format" => 1, "game" => "uno", "table_id" => 8, "live_session_id" => session_id,
    "created_at" => now, "expires_at" => now + 300 })
receiver = GameRoomTableWatch::Receiver.new(user: "Alice", games: ["uno"], uuid: uuid, clock: -> { now })
receiver.games = ["uno"]
EltenGameRoom.instance_variable_set(:@table_watch_receiver, receiver)
EltenGameRoom.instance_variable_set(:@table_watch_loader, nil)
EltenGameRoom.instance_variable_set(:@table_watch_pruned, {})
row = { "__id" => 8, "__live_session_id" => session_id, "game" => "uno", "owner" => "Bob", "status" => "waiting", "private" => false }
snapshot = WidgetSnapshot.new(table: row, members: ["Bob"])
rows = [snapshot]
app = EltenGameRoom.allocate
transport = Object.new
transport.define_singleton_method(:start) { true }
lobby = Object.new
lobby.define_singleton_method(:open_table_snapshots) { |**_| rows }
app.instance_variable_set(:@transport, transport)
app.instance_variable_set(:@lobby, lobby)
app.define_singleton_method(:initialize_services) { nil }
app.define_singleton_method(:run_network_task) { |*_, **_, &block| block.call }
opened = []
alerts = []
app.define_singleton_method(:open_widget_table) { |value| opened << value }
app.define_singleton_method(:alert) { |text| alerts << text }

app.send(:open_new_table_notification, notice)
assert(opened == [snapshot], "fresh endpoint did not use ordinary widget join")
opened.clear
app.define_singleton_method(:run_network_task) { |*_, **_| nil }
app.send(:open_new_table_notification, notice)
assert(opened.empty? && receiver.visible?(notice), "network failure expired an active notice")

app.define_singleton_method(:run_network_task) do |*_, **_, &block|
  result = block.call
  now += 301
  result
end
app.send(:open_new_table_notification, notice)
assert(opened.empty? && alerts.last.include?("expired"), "slow lookup bypassed expiry")
now -= 301
app.define_singleton_method(:run_network_task) { |*_, **_, &block| block.call }
row["private"] = true
app.send(:open_new_table_notification, notice)
assert(opened.empty? && !receiver.visible?(notice), "announcement granted private access")

# Extension stop must not leave a closed sender reused on restart. Startup
# preference loading is finite, outside the UI, and is not repeated by ticks.
fake_sender = Object.new
closed = false
fake_sender.define_singleton_method(:close) { closed = true }
EltenGameRoom.instance_variable_set(:@table_watch_sender, fake_sender)
EltenGameRoom.table_watch_stop
assert(closed && EltenGameRoom.instance_variable_get(:@table_watch_sender).nil?, "stop retained a closed sender")
assert(EltenGameRoom.instance_variable_get(:@table_watch_loader).nil?, "stop retained closed loader")
receiver.games = nil
loads = 0
repository = Object.new
repository.define_singleton_method(:load) { |_user| loads += 1; ["uno"] }
EltenGameRoom.define_singleton_method(:table_watch_repository) { repository }
EltenGameRoom.table_watch_start
loader = EltenGameRoom.instance_variable_get(:@table_watch_loader)
assert(loader && loader.instance_variable_get(:@thread).join(3), "finite startup load did not finish")
EltenGameRoom.table_watch_tick
assert(receiver.games == ["uno"] && loads == 1, "startup settings not applied")
50.times { EltenGameRoom.table_watch_tick }
assert(loads == 1, "ticks poll notification preferences")
EltenGameRoom.table_watch_stop
EltenGameRoom.table_watch_start
assert(EltenGameRoom.instance_variable_get(:@table_watch_loader).nil?, "loaded settings refetched on restart")
puts "Table notices: fresh-instance join, slow expiry, private guard, offline read, lifecycle and no polling: OK"
