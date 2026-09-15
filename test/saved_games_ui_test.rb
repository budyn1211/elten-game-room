require_relative "support/ui"
require_relative "support/native_live_sessions"
class Program
  def self.server_app(**_options); end
  def self.app_runtime; nil; end
end
require_relative "../__app"
def n_(one, many, count); count == 1 ? one : many; end

class SaveAppDriver < EltenGameRoom
  attr_reader :transport, :games, :lobby, :notices, :errors
  attr_accessor :write_error
  def initialize(broker)
    @json, @errors, @notices = {}, [], []
    program = ProgramDouble.new(broker.endpoint("Alice"))
    @transport = GameRoomTransport.new(program)
    @lobby = LobbyRepository.new(program, transport: @transport, server_tables: {})
    @games = GameRepository.new(program, transport: @transport, server_tables: {})
    @invitations = InvitationRepository.new(transport: @transport)
  end
  def read_json(path, default:); JSON.parse(JSON.generate(@json.fetch(path, default))); end
  def update_json(path, default:)
    raise IOError, "disk denied" if write_error
    root = read_json(path, default: default)
    yield(root)
    @json[path] = JSON.parse(JSON.generate(root))
  end
  def run_network_task(*_arguments, **_keywords)
    yield
  rescue StandardError => error
    raise unless GameRoomNetworkErrors.expected?(error)
    @errors << error
    nil
  end
  def confirm(_message); true; end
  def alert(message); @notices << message; end
  def play_game_sound(_name); end
  def send_notification(user, type:, metadata:, expires_in:); @notices << [user, type, metadata, expires_in]; end
  def room_state(table)
    room = @lobby.snapshot_for(table)
    session = @games.session_for_table(table)
    snapshot = @games.snapshot_for(session) if session
    game = game_definition(table["game"])
    replay = game.replay(snapshot.session, snapshot.events, @games) if snapshot
    GameRoomLifecycle::State.new(room: room, game_snapshot: snapshot, game: game, replay: replay,
      players: session == nil ? [] : @games.players_for(session))
  end
end

broker = NativeLiveSessionsBroker.new
app = SaveAppDriver.new(broker)
$game_room_test_user = "Alice"
game = GameRoomGames::Uno.new
created = app.lobby.create_table(name: "Saved UNO", game: game.id, owner: "Alice", game_options: "{}", bot_count: 1)
table = created.table
bob = GameRoomTransport.new(ProgramDouble.new(broker.endpoint("Bob")))
selected = bob.discover_rooms.first
assert(bob.establish_membership(table_id: table["__id"], owner: "Alice", capacity: 8, user: "Bob", table: selected), "Bob cannot join original game")
players = %w[Alice Bob] + GameRoomParticipants.bots_for(table["__id"], 1)
session = app.games.start_session(table: table, game: game.id, players: players, options: JSON.generate(game.default_options))
env = GameRoomSimulation::Environment.new_game(game: game, players: players, seed: 11)
env.events.each { |event| app.games.append_events(session: session, sequence: event["sequence"], events: [GameRoomGames::EventCommand.new(action: event["action"], value: event["value"])], actor: event["actor"], controller: true) }
app.write_error = true
assert(!app.send(:save_current_game, table, session, game), "write failure closed the table")
assert(app.transport.current_room("Alice") != nil && !app.games.snapshot_for(session).session["__frozen"], "write failure lost membership or kept game frozen")
assert(app.send(:saved_games).list.empty?, "failed write left a fake save")
app.write_error = false
view = broker.endpoint("Alice").sessions.first
view.define_singleton_method(:close) { raise EltenAPI::LiveSessions::TimeoutError, "close denied" }
assert(!app.send(:save_current_game, table, session, game), "unconfirmed close was treated as success")
assert(app.send(:saved_games).list.length == 1, "close failure lost the verified save")
assert(app.transport.current_room("Alice") != nil && !app.games.snapshot_for(session).session["__frozen"], "close failure left the room unusable")
view.singleton_class.remove_method(:close)
assert(app.send(:save_current_game, table, session, game), "confirmed save did not close room: #{app.errors}")
assert(app.transport.current_room("Alice") == nil && broker.cores.values.first.closed, "successful save kept original table open")
saved = app.send(:saved_games).list.first
new_table = app.send(:create_saved_game_table, saved)
assert(new_table && new_table["resume_save_id"] == saved["id"], "saved game did not create a continuation room")
assert(broker.cores[new_table["__live_session_id"]].metadata["protocol"] == 3, "legacy clients can join an unsupported archive")
assert(new_table["bot_count"] == 1, "original bots were not restored before waiting")
assert(app.notices.any? { |notice| notice.is_a?(Array) && notice[0] == "Bob" && notice[2]["continuation"] == true }, "original human did not receive continuation invitation")
state = app.room_state(new_table)
assert(app.send(:resume_saved_game_at_table, new_table, state) == nil, "resume silently replaced missing original human")
assert(app.notices.last.include?("Bob"), "missing original player was not identified")
assert(GameRoomParticipantMenu.management_actions(room: state.room, game: game, active: false, viewer: "Alice", owner: "Alice", restoring: true).empty?, "bots can be replaced in continuation waiting room")
assert(app.send(:create_saved_game_table, saved)["__id"] == new_table["__id"], "repeated resume created a duplicate table")
bob = GameRoomTransport.new(ProgramDouble.new(broker.endpoint("Bob", fresh: true)))
selected = bob.discover_rooms.first
assert(bob.establish_membership(table_id: new_table["__id"], owner: "Alice", capacity: 8, user: "Bob", table: selected), "original human cannot enter continuation room")
resumed = app.send(:resume_saved_game_at_table, new_table, app.room_state(new_table))
assert(resumed && app.games.players_for(resumed) == %w[Alice Bob] + GameRoomParticipants.bots_for(new_table["__id"], 1), "continuation changed original seats")
assert(game.replay(resumed, app.games.snapshot_for(resumed).events, app.games).accepted_events.length == saved["events"].length, "UI continuation did not replay all saved events")
assert(app.send(:saved_games).list.include?(saved), "resume deleted the only archive")
assert(app.send(:start_new_game, new_table, state: app.room_state(new_table))["__id"] == resumed["__id"], "active continuation restarted instead of opening")
puts "Save UI: disk/close failures, original seats, bots, invitations, missing players and duplicate prevention OK"
