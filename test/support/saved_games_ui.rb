require_relative "ui"
require_relative "native_live_sessions"
require_relative "private_archives"
class Program
  def self.server_app(**_options); end
  def self.app_runtime; nil; end
end
require_relative "../../__app"
def n_(one, many, count); count == 1 ? one : many; end

class SaveAppDriver < EltenGameRoom
  attr_reader :transport, :games, :lobby, :notices, :errors
  def initialize(broker)
    @json, @errors, @notices = {}, [], []
    program = ProgramDouble.new(broker.endpoint("Alice"))
    @transport = GameRoomTransport.new(program)
    @lobby = LobbyRepository.new(program, transport: @transport, server_tables: {})
    @games = GameRepository.new(program, transport: @transport, server_tables: {})
    @invitations = InvitationRepository.new(transport: @transport)
    @save_resources = PrivateArchiveDouble.new
    @saved_games = AccountSavedGames.new(self, owner: 'Alice', resources: @save_resources)
  end
  def write_error=(value); @save_resources.write_error = value; end
  def write_error; @save_resources.write_error; end
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
