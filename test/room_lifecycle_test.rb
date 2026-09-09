def _(text)
  text
end

require_relative "../lib/room_presentation"
require_relative "../lib/game_teams"
require_relative "../lib/lobby_repository"
require_relative "../lib/game_repository"
require_relative "../lib/game_lifecycle"

def players_json(*players)
  JSON.generate(
    "version" => 1,
    "seats" => players.each_with_index.map { |player, index| { "id" => index + 1, "controller" => player } }
  )
end

def assert(condition, message)
  raise message if !condition
end

if !defined?(Session)
  module Session
    def self.name
      "Alice"
    end
  end
end

table = { "__id" => 7, "game" => "four_in_a_row", "owner" => "Alice" }
sessions = [
  {
    "__id" => 11,
    "table_id" => 7,
    "game" => "four_in_a_row",
    "player_one" => "Alice",
    "player_two" => "Bob",
    "players_json" => players_json("Alice", "Bob")
  },
  {
    "__id" => 19,
    "table_id" => 7,
    "game" => "four_in_a_row",
    "player_one" => "Alice",
    "player_two" => "Bob",
    "players_json" => players_json("Alice", "Bob")
  }
]
repository = GameRepository.allocate
repository.define_singleton_method(:session_rows) { |table_id: nil| sessions }
repository.define_singleton_method(:valid_session_for_table?) { |_session, _table, players:| !players.empty? }

latest = repository.session_for_table(table)
assert(repository.session_id(latest) == 19, "the latest game session was not selected")
assert(repository.latest_session_id_for_table(table) == 19, "the latest game session id was not detected")
assert(repository.session_by_id(11, table: table)["__id"] == 11, "a game session could not be restored by id")

room_snapshot = Struct.new(:participants).new(["Alice", "Bob"])
snapshot_struct = Struct.new(:session)
active_replay = Struct.new(:history) do
  def finished?
    false
  end
end.new([Struct.new(:text).new("Current move")])
finished_replay = Struct.new(:history) do
  def finished?
    true
  end
end.new([Struct.new(:text).new("Last move")])
active_lifecycle = GameRoomLifecycle::State.new(
  room: room_snapshot,
  game_snapshot: snapshot_struct.new(sessions.last),
  game: Object.new,
  replay: active_replay,
  players: ["Alice", "Bob"]
)
assert(active_lifecycle.phase == :active, "an active game has an invalid lifecycle phase")
assert(active_lifecycle.role_for("Bob") == :player, "a current player became an observer")
assert(active_lifecycle.role_for("Carol") == :observer, "a late participant became a player in the running game")
assert(!active_lifecycle.startable_by?("Alice", owner: "Alice"), "an active game allowed another start")

elimination_game = Object.new
elimination_game.define_singleton_method(:active_competitor?) { |_replay, participant| participant != "Bob" }
eliminated_lifecycle = GameRoomLifecycle::State.new(
  room: room_snapshot,
  game_snapshot: snapshot_struct.new(sessions.last),
  game: elimination_game,
  replay: active_replay,
  players: ["Alice", "Bob"]
)
assert(eliminated_lifecycle.role_for("Bob") == :observer, "a formally eliminated player remained an active competitor")
assert(!eliminated_lifecycle.active_competitor?("Bob"), "a formally eliminated player could still interrupt the game by leaving")

cancelled_lifecycle = GameRoomLifecycle::State.new(
  room: room_snapshot,
  game_snapshot: snapshot_struct.new(sessions.last.merge("status" => "cancelled")),
  game: Object.new,
  replay: active_replay,
  players: ["Alice", "Bob"]
)
assert(cancelled_lifecycle.phase == :waiting, "an interrupted game did not reopen the room")
assert(cancelled_lifecycle.startable_by?("Alice", owner: "Alice"), "an interrupted game could not be restarted")

finished_lifecycle = GameRoomLifecycle::State.new(
  room: room_snapshot,
  game_snapshot: snapshot_struct.new(sessions.last),
  game: Object.new,
  replay: finished_replay,
  players: ["Alice", "Bob"]
)
assert(finished_lifecycle.phase == :finished, "a finished game has an invalid lifecycle phase")
assert(finished_lifecycle.history.map(&:text) == ["Last move"], "the finished game lost its history while waiting")
assert(finished_lifecycle.startable_by?("Alice", owner: "Alice"), "the table master cannot start the next game")

next_replay = Struct.new(:history) do
  def finished?
    false
  end
end.new([Struct.new(:text).new("New game started")])
next_lifecycle = GameRoomLifecycle::State.new(
  room: room_snapshot,
  game_snapshot: snapshot_struct.new(sessions.last.merge("__id" => 20)),
  game: Object.new,
  replay: next_replay,
  players: ["Alice", "Bob"]
)
assert(
  next_lifecycle.history.map(&:text) == ["New game started"],
  "history from the previous game leaked into the new game"
)

stale_repository = GameRepository.allocate
stale_session = sessions.last.merge("__players" => ["Alice", "Bob"])
stale_repository.define_singleton_method(:session_for_table) { |_row| stale_session }
returned_session = stale_repository.start_session(
  table: table,
  game: "four_in_a_row",
  players: ["Alice", "Bob"],
  expected_previous_session_id: 11
)
assert(
  stale_repository.session_id(returned_session) == 19,
  "a stale start request created a competing game session"
)

start_reads = 0
session_writes = []
notifications = []
previous_session = sessions.last.merge("__players" => ["Alice", "Bob"])
competing_session = previous_session.merge("__id" => 21)
fake_sessions_table = Object.new
fake_sessions_table.define_singleton_method(:insert) do |values|
  session_writes << values
  values.merge("__id" => 20, "__insertion_user" => "Alice")
end
competing_repository = GameRepository.allocate
competing_repository.define_singleton_method(:session_for_table) do |_row|
  start_reads += 1
  start_reads == 1 ? previous_session : competing_session
end
competing_repository.define_singleton_method(:sessions_table) { fake_sessions_table }
competing_repository.define_singleton_method(:events_table) { raise "starting a game wrote participant events" }
competing_repository.define_singleton_method(:notify_game_changed) do |session, _users, change:|
  notifications << [session, change]
end
resolved_session = competing_repository.start_session(
  table: table,
  game: "four_in_a_row",
  players: ["Alice", "Bob"],
  expected_previous_session_id: 19
)
assert(session_writes.length == 1, "a valid start did not create one candidate session")
assert(
  JSON.parse(session_writes.first["players_json"])["seats"].map { |seat| seat["controller"] } == ["Alice", "Bob"],
  "a valid start did not freeze its complete player list atomically"
)
assert(
  competing_repository.session_id(resolved_session) == 21,
  "simultaneous starts did not converge on the newest complete session"
)
assert(notifications.empty?, "a superseded candidate session was announced as current")

many_players = {
  "__players" => ["Alice", "Bob", "Carol", "Dave"],
  "player_one" => "Alice",
  "player_two" => "Bob"
}
assert(
  repository.players_for(many_players) == ["Alice", "Bob", "Carol", "Dave"],
  "a generic game session was reduced to two players"
)

event_session = {
  "__id" => 23,
  "__insertion_user" => "Alice",
  "table_id" => 7,
  "player_one" => "Alice",
  "player_two" => "Bob",
  "status" => "active",
  "players_json" => players_json("Alice", "Bob", "Carol", "Dave")
}
assert(
  repository.players_for(event_session) == ["Alice", "Bob", "Carol", "Dave"],
  "the atomic persisted player list was not restored"
)
assert(repository.players_for(event_session.merge("players_json" => "")).empty?, "a session without the new player list was accepted")
assert(repository.players_for(event_session.merge("players_json" => "not-json")).empty?, "an invalid player list was accepted")
assert(
  repository.players_for(event_session.merge("players_json" => players_json("Alice", "alice"))).empty?,
  "duplicate players were accepted"
)
invalid_seats = JSON.generate(
  "version" => 1,
  "seats" => [{ "id" => 2, "controller" => "Alice" }, { "id" => 1, "controller" => "Bob" }]
)
assert(repository.players_for(event_session.merge("players_json" => invalid_seats)).empty?, "unordered seats were accepted")

bot = GameRoomParticipants.bot_id(7, 1)
bot_session = {
  "__id" => 24,
  "__insertion_user" => "Alice",
  "table_id" => 7,
  "player_one" => "Alice",
  "__players" => ["Alice", bot]
}
valid_bot_event = { "__insertion_user" => "Alice", "actor" => bot }
forged_bot_event = { "__insertion_user" => "Bob", "actor" => bot }
forged_human_event = { "__insertion_user" => "Alice", "actor" => "Bob" }
assert(repository.actor_of(valid_bot_event, bot_session) == bot, "the table owner's computer move was rejected")
assert(repository.actor_of(forged_bot_event, bot_session).empty?, "another user was allowed to move a computer")
assert(repository.actor_of(forged_human_event, bot_session) == "Alice", "a claimed human actor replaced the server author")
assert(
  repository.next_sequence(
    event_session.merge("__players" => ["Alice", "Bob", "Carol", "Dave"]),
    [{ "sequence" => 1 }, { "sequence" => 2 }]
  ) == 3,
  "game events did not continue after the greatest accepted sequence"
)
assert(
  repository.next_sequence(
    event_session.merge("__players" => ["Alice", "Bob"]),
    [{ "sequence" => 7 }]
  ) == 8,
  "a session did not continue after its greatest accepted sequence"
)

inserted_values = []
fake_events_table = Object.new
fake_events_table.define_singleton_method(:insert) do |values|
  inserted_values << values
  values.merge("__id" => 49 + inserted_values.length)
end
fast_repository = GameRepository.allocate
fast_repository.define_singleton_method(:events_table) { fake_events_table }
fast_repository.define_singleton_method(:session_rows) { |table_id: nil| raise "move submission read game sessions" }
fast_repository.define_singleton_method(:events_for) { |_session| raise "move submission read game events" }
fast_repository.define_singleton_method(:notify_game_changed) do |_session, _users, change:|
  assert(change == "action", "game action notification has an invalid change type")
end
fast_session = {
  "__id" => 24,
  "table_id" => 7,
  "__insertion_user" => "Alice",
  "player_one" => "Alice",
  "__players" => ["Alice", "Bob"]
}
inserted_actions = fast_repository.append_events(
  session: fast_session,
  sequence: 4,
  events: [
    { "action" => "answer", "value" => "Poland" },
    { action: "answer", value: "Poznan" }
  ],
  recipients: ["Alice", "Bob"]
)
assert(inserted_actions.map { |row| row["__id"] } == [50, 51], "multi-event action lost inserted rows")
assert(inserted_values.all? { |values| values["session_id"] == 24 }, "the direct action insert used an invalid session")
assert(inserted_values.map { |values| values["sequence"] } == [4, 5], "multi-event action has invalid sequence numbers")

fast_session["__players"] << bot
fast_repository.append_events(
  session: fast_session,
  sequence: 6,
  events: [{ action: "place", value: "2,2" }],
  recipients: ["Alice", bot, "Bob"],
  actor: bot
)
assert(inserted_values.last["actor"] == bot, "a computer move was written as its coordinating user")

event_selects = []
cached_rows = [
  { "__id" => 70, "session_id" => 24, "sequence" => 1, "created_at" => 1 },
  { "__id" => 71, "session_id" => 24, "sequence" => 2, "created_at" => 2 },
  { "__id" => 72, "session_id" => 24, "sequence" => 3, "created_at" => 3 }
]
fake_cached_events_table = Object.new
fake_cached_events_table.define_singleton_method(:select) do |where:, order:, limit:, offset: nil|
  event_selects << { where: where, order: order, limit: limit, offset: offset.to_i }
  cached_rows.drop(offset.to_i).take(limit.to_i)
end
cached_repository = GameRepository.allocate
cached_repository.define_singleton_method(:events_table) { fake_cached_events_table }
first_cached = cached_repository.send(:events_for, fast_session)
second_cached = cached_repository.send(:events_for, fast_session)
assert(first_cached.map { |row| row["__id"] } == [70, 71, 72], "the event cache changed event order")
assert(second_cached.map { |row| row["__id"] } == [70, 71, 72], "the event cache lost events")
assert(event_selects.length == 1, "a fresh event cache repeated the full server read")

cached_rows << { "__id" => 73, "session_id" => 24, "sequence" => 4, "created_at" => 4 }
incremental = cached_repository.send(:events_for, fast_session, force: true)
assert(incremental.map { |row| row["__id"] } == [70, 71, 72, 73], "the event cache did not append a remote event")
assert(event_selects.last[:offset] == 3, "incremental event loading did not begin after cached rows")

revision = cached_repository.events_revision(incremental)
assert(
  cached_repository.event_revision(fast_session, known_revision: revision) == revision,
  "an unchanged event log reported a new revision"
)
assert(event_selects.last[:limit] == 1 && event_selects.last[:offset] == 4, "revision checking fetched the full event log")

lobby = LobbyRepository.allocate
assert(lobby.capacity_of({ "max_players" => 2 }) == 8, "an old two-person table was not upgraded logically")
assert(lobby.capacity_of({ "max_players" => 12 }) == 8, "an old oversized room capacity was not capped")
bot_table = { "__id" => 7, "max_players" => 8, "bot_count" => 2 }
assert(lobby.bots_for(bot_table) == ["bot:7:1", "bot:7:2"], "table computers were not restored")
snapshot = LobbyRepository::TableSnapshot.new(table: bot_table, members: ["Alice"], bots: lobby.bots_for(bot_table))
assert(snapshot.participants == ["Alice", "bot:7:1", "bot:7:2"], "table participants lost computers")

listed_rows = [
  { "__id" => 1, "status" => "playing", "updated_at" => 300, "game" => "spades" },
  { "__id" => 2, "status" => "waiting", "updated_at" => 100, "game" => "spades" },
  { "__id" => 3, "status" => "waiting", "updated_at" => 200, "game" => "spades" },
  { "__id" => 4, "status" => "closed", "updated_at" => 400, "game" => "spades" }
]
listing_table = Object.new
listing_table.define_singleton_method(:select) { |**_arguments| listed_rows }
listing_lobby = LobbyRepository.allocate
listing_lobby.define_singleton_method(:tables_table) { listing_table }
assert(
  listing_lobby.open_tables.map { |row| row["__id"] } == [3, 2, 1],
  "open tables are not listed before games in progress"
)

managed_row = {
  "__id" => 8,
  "__insertion_user" => "Alice",
  "owner" => "Alice",
  "status" => "waiting",
  "max_players" => 8,
  "bot_count" => 0,
  "player_count" => 1
}
fake_tables = Object.new
fake_tables.define_singleton_method(:update) do |_id, values|
  managed_row.merge(values)
end
managed_lobby = LobbyRepository.allocate
managed_lobby.define_singleton_method(:active_member_rows) { [] }
managed_lobby.define_singleton_method(:open_table) { |_id, _tables = nil| managed_row }
managed_lobby.define_singleton_method(:reconcile_members) { |_row, _members| ["Alice"] }
managed_lobby.define_singleton_method(:tables_table) { fake_tables }
managed_lobby.define_singleton_method(:notify_table_changed) { |_row, _users, actor:| actor }

snapshot_updates = []
snapshot_tables = Object.new
snapshot_tables.define_singleton_method(:update) do |_id, values|
  snapshot_updates << values
  managed_row.merge(values)
end
snapshot_lobby = LobbyRepository.allocate
snapshot_lobby.define_singleton_method(:open_tables) { [managed_row] }
snapshot_lobby.define_singleton_method(:active_member_rows) { [] }
snapshot_lobby.define_singleton_method(:reconcile_members) { |_row, _members| ["Alice"] }
snapshot_lobby.define_singleton_method(:tables_table) { snapshot_tables }
unchanged_snapshot = snapshot_lobby.snapshot_for(managed_row)
assert(unchanged_snapshot.members == ["Alice"], "an unchanged table snapshot lost its members")
assert(snapshot_updates.empty?, "an unchanged table snapshot performed a server write")

managed_row["player_count"] = 7
repaired_snapshot = snapshot_lobby.snapshot_for(managed_row)
assert(snapshot_updates.length == 1, "an inconsistent table snapshot was not repaired")
assert(repaired_snapshot.table["player_count"] == 1, "table counters were repaired incorrectly")
managed_row["player_count"] = 1

assert(managed_lobby.add_bot(managed_row) == :updated, "the table owner could not add a computer")
assert(managed_row["bot_count"] == 1 && managed_row["player_count"] == 2, "adding a computer did not update the table")
assert(managed_lobby.remove_bot(managed_row) == :updated, "the table owner could not remove a computer")
assert(managed_row["bot_count"] == 0 && managed_row["player_count"] == 1, "removing a computer did not update the table")
assert(managed_lobby.remove_bot(managed_row) == :none, "removing a missing computer changed the table")
managed_row["bot_count"] = 9
assert(managed_lobby.add_bot(managed_row) == :full, "a computer exceeded the table capacity")
managed_row["bot_count"] = 0
assert(managed_lobby.set_game_active(managed_row, true)["status"] == "playing", "starting a game did not mark the table as playing")
assert(managed_lobby.set_game_active(managed_row, false)["status"] == "waiting", "finishing a game did not reopen the table")

# Adding several computers from an already loaded room must not reread the
# complete tables and membership collections after every click. The confirmed
# server write remains authoritative and updates the cached snapshot only after
# it succeeds.
fast_row = {
  "__id" => 18,
  "__insertion_user" => "Alice",
  "owner" => "Alice",
  "status" => "waiting",
  "max_players" => 8,
  "bot_count" => 0,
  "player_count" => 1
}
fast_snapshot = LobbyRepository::TableSnapshot.new(table: fast_row, members: ["Alice"], bots: [])
fast_updates = []
fast_activities = []
fast_notifications = []
fast_tables = Object.new
fast_tables.define_singleton_method(:update) do |_id, values|
  fast_updates << values.dup
  fast_row.merge(values)
end
fast_lobby = LobbyRepository.allocate
fast_lobby.define_singleton_method(:tables_table) { fast_tables }
fast_lobby.define_singleton_method(:active_member_rows) { raise "cached bot update performed a membership read" }
fast_lobby.define_singleton_method(:open_table) { |_id, _tables = nil| raise "cached bot update performed a table read" }
fast_lobby.define_singleton_method(:append_activity) do |_row, kind, actor:, table_users:|
  fast_activities << [kind, actor, table_users.dup]
  Struct.new(:id).new(100 + fast_activities.length)
end
fast_lobby.define_singleton_method(:notify_table_changed) do |_row, users, actor:|
  fast_notifications << [users.dup, actor]
end

7.times do |index|
  result = fast_lobby.add_bot(fast_row, snapshot: fast_snapshot)
  assert(result.is_a?(LobbyRepository::BotUpdateResult) && result.updated?, "cached computer #{index + 1} was not added")
  assert(result.snapshot.equal?(fast_snapshot), "cached computer update replaced the room snapshot")
  assert(result.activity != nil, "cached computer update lost its history entry")
end
assert(fast_updates.length == 7, "adding seven computers used extra table writes")
assert(fast_activities.length == 7, "adding seven computers lost or duplicated activity writes")
assert(fast_notifications.length == 7, "adding seven computers lost change notifications")
assert(fast_snapshot.participants.length == 8 && fast_snapshot.bots.length == 7, "cached room did not contain all computers")
full_result = fast_lobby.add_bot(fast_row, snapshot: fast_snapshot)
assert(full_result.status == :full, "cached room capacity was not enforced")
assert(fast_updates.length == 7 && fast_activities.length == 7, "a rejected computer addition wrote to the server")

fast_lobby.set_game_active(fast_row, true, snapshot: fast_snapshot)
assert(fast_updates.length == 8, "starting a game from a verified room used extra table writes")
assert(fast_snapshot.table["status"] == "playing", "starting a game did not update the verified room snapshot")

live_members = Object.new
live_members.define_singleton_method(:connected_users) { |_table_id| ["Alice", "Bob"] }
fast_lobby.instance_variable_set(:@transport, live_members)
stale_result = fast_lobby.remove_bot(fast_row, snapshot: fast_snapshot)
assert(stale_result.status == :stale, "a concurrent human join did not invalidate the local room snapshot")
assert(fast_snapshot.bots.length == 7, "a stale room snapshot was modified")
assert(fast_updates.length == 8 && fast_activities.length == 7, "a stale bot update wrote to the server")

active_labels = RoomPresentation.user_labels(
  ["Alice", "Bob", "Carol"],
  bots: ["bot:7:1"],
  owner: "alice",
  players: ["Alice", "Bob", "bot:7:1"],
  active: true,
  team_assignment: GameRoomTeams::Assignment.new(
    players: ["Alice", "Bob", "bot:7:1", "Dave"],
    team_size: 2,
    seats: [0, 1, 0, 1]
  )
)
assert(active_labels[0].include?("table master") && active_labels[0].include?("player") && active_labels[0].include?("team 1"), "the table master role is incomplete")
assert(active_labels[1].include?("player"), "the second player role is missing")
assert(active_labels[2].include?("observer"), "an observer was presented as a player")
assert(active_labels[3].include?("Computer 1") && active_labels[3].include?("computer") && active_labels[3].include?("player") && active_labels[3].include?("team 1"), "a computer has invalid room roles")

waiting_labels = RoomPresentation.user_labels(
  ["Alice", "Carol"],
  owner: "Alice",
  players: ["Alice", "Bob"],
  active: false
)
assert(waiting_labels.all? { |label| label.include?("waiting for a game") }, "finished-game users are not waiting")

puts "Room lifecycle tests passed"
