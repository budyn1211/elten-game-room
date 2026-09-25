require_relative 'support/table_watch'

server_sample, elapsed, wrong_wall = 1000, 10, 4600
clock = GameRoomTableWatch::Clock.new(sample: -> { server_sample }, elapsed: -> { elapsed }, fallback: -> { wrong_wall })
assert(clock.call == 1000, "notice clock used the sender's skewed wall time")
elapsed += 301
wrong_wall -= 7200
assert(clock.call == 1301, "expiration froze with stale server status or followed a clock change")
server_sample = 1302
assert(clock.call == 1302, "fresh server timestamp did not refresh the anchor")
server_sample = nil
elapsed += 10
assert(clock.call == 1312, "connection gap discarded a known server clock")
clock = GameRoomTableWatch::Clock.new(sample: -> { server_sample }, elapsed: -> { elapsed }, fallback: -> { wrong_wall })
assert(clock.call == wrong_wall, "offline fallback before any host timestamp")
server_sample = 1320
assert(clock.call == 1320, "first server timestamp did not replace the startup fallback")

table = WatchTable.new
repository = GameRoomTableWatch::Preferences.new(table, games: %w[uno rummy])
assert(repository.load("Alice") == [] && table.writes.empty?, "first read wrote defaults")
repository.save("Alice", %w[uno uno fake])
assert(repository.load("Alice") == ["uno"], "selection normalization")
before = table.writes.size
repository.save("Alice", ["uno"])
assert(table.writes.size == before, "unchanged save wrote a record")
table.insert("username" => "Alice", "format" => 1, "games" => '["rummy"]')
assert(repository.load("Alice") == ["uno"], "duplicate winner is not deterministic")
table.user = "Mallory"
table.insert("username" => "Alice", "format" => 1, "games" => '["rummy"]')
table.user = "Alice"
repository.save("Alice", ["rummy"])
assert(table.rows.count { |row| row["__insertion_user"] == "Alice" } == 1, "own duplicates remain")
assert(table.rows.count { |row| row["__insertion_user"] == "Mallory" } == 1, "foreign row removed")
assert(repository.recipients("rummy", online: %w[ALICE Alice Mallory], sender: "Bob") == ["Alice"], "recipients forged or duplicated")
assert(repository.recipients("rummy", online: ["Alice"], sender: "alice") == [], "sender notified itself")

now = 1000
session_id = "12345678-1234-1234-1234-123456789abc"
meta = { "format" => 1, "game" => "uno", "table_id" => 12, "live_session_id" => session_id,
  "created_at" => now, "expires_at" => now + 300 }
notice = WatchNotice.new(id: 1, app_uuid: "uuid", type: GameRoomTableWatch::TYPE, sender: "Bob", metadata: meta)
stored = {}
receiver = GameRoomTableWatch::Receiver.new(user: "Alice", uuid: "uuid", games: %w[uno rummy],
  clock: -> { now }, persist: ->(data) { stored = Marshal.load(Marshal.dump(data)) })
assert(receiver.visible?(notice) && receiver.receive(notice), "fresh notice missing before startup preference read")
assert(!receiver.receive(notice) && receiver.visible?(notice), "same notice alerted twice or vanished")
duplicate = notice.dup; duplicate.id = 2
assert(!receiver.visible?(duplicate), "duplicate leaves an empty list row")
restarted = GameRoomTableWatch::Receiver.new(user: "Alice", uuid: "uuid", games: %w[uno rummy], stored: stored, clock: -> { now })
assert(stored.empty? && !restarted.received?(notice), "receiving unnecessarily persisted seen IDs; startup delivery belongs to the host")
receiver.games = ["rummy"]
assert(!receiver.visible?(notice), "disabled game passed receiver filter")
receiver.games = ["uno"]
now = 1300
assert(!receiver.visible?(notice), "expired announcement remains visible")
now = 1000
receiver.resolve(session_id)
assert(!receiver.visible?(notice), "manual join did not resolve announcement")
restarted = GameRoomTableWatch::Receiver.new(user: "Alice", uuid: "uuid", games: %w[uno rummy], stored: stored, clock: -> { now })
assert(!restarted.visible?(notice), "restart lost resolved/joined table suppression")
bad = notice.dup; bad.metadata = meta.merge("live_session_id" => "https://evil.invalid")
assert(receiver.data(bad) == nil, "untrusted target accepted")
bad.metadata = meta.merge("expires_at" => 999999)
assert(receiver.data(bad) == nil, "unbounded expiration accepted")

worker = WatchWorker.new
sent, online_calls, loads = [], 0, 0
fake_repository = Object.new
fake_repository.define_singleton_method(:recipients) { |*_, **_| loads += 1; %w[Bob Carol] }
sender = GameRoomTableWatch::Sender.new(user: "Alice", repository: fake_repository, worker: worker,
  online: -> { online_calls += 1; %w[Bob Carol] }, clock: -> { now }, current_user: -> { "Alice" },
  send_notice: ->(name, metadata, expires) { sent << [name, metadata, expires] })
row = { "owner" => "Alice", "status" => "waiting", "game" => "uno", "__id" => 12, "__live_session_id" => session_id }
assert(!sender.enqueue(row.merge("private" => true)), "private room announced")
assert(!sender.enqueue(row.merge("resume_save_id" => "save")), "resumed room announced")
assert(sender.enqueue(row) && !sender.enqueue(row), "created event not deduplicated")
sender.tick; worker.finish; sender.tick
assert(loads == 1 && online_calls == 1, "recipient discovery did not batch online")
worker.finish; sender.tick
assert(sent.size == 1 && !worker.busy?, "rate pacing ignored")
now += 0.5
sender.tick; worker.finish(Limited.new("HTTP 429")); sender.tick
now += 59
sender.tick
assert(!worker.busy?, "429 was immediately retried")
now += 1
sender.tick; worker.finish; sender.tick
assert(sent.map(&:first) == %w[Bob Carol], "explicit rejected send was not retried once")
assert(sent.last.last < sent.first.last, "expiry reset for each recipient")
now = 2000
new_row = row.merge("__live_session_id" => "12345678-1234-1234-1234-123456789abd")
sender.enqueue(new_row); sender.tick; worker.finish; sender.tick
worker.finish(Uncertain.new("response lost")); sender.tick
now += 20
sender.tick
sender.cancel(new_row["__live_session_id"])
worker.finish
sender.tick
assert(sent.size == 2, "uncertain write retried or cancelled job sent")
puts "Table subscriptions, author checks, receipts, expiry and paced notifications passed"
