require_relative 'table_lifecycle_controls_2'
require_relative 'session_runner'
require_relative '../../games/scientific_war'

class ScientificWarControlFixture
  attr_reader :broker, :app, :game, :table, :session, :bot, :transports, :repositories, :contexts

  def initialize(bots: 1, watcher: false)
    @broker = NativeLiveSessionsBroker.new
    @app = LifecycleApp.new(@broker)
    @game = GameRoomGames::ScientificWar.new
    @transports = {'Alice' => app.transport}
    @repositories = {'Alice' => app.games}
    @contexts = {}
    as('Alice') do
      @table = app.lobby.create_table(name: 'Scientific War controls', game: game.id, owner: 'Alice',
        game_options: JSON.generate(game.default_options.merge('bot_delay' => 0))).table
      add_client('Bob')
      add_client('Watcher') if watcher
      app.lobby.set_observer(table, 'Watcher', true) if watcher
      app.transport.update_room(table, {'bot_count' => bots}, actor: 'Alice') if bots > 0
      @bot = app.transport.room_snapshot(table)[:bots].first
      @session = app.games.start_session(table: table, game: game.id,
        players: %w[Alice Bob] + app.transport.room_snapshot(table)[:bots], options: table['game_options'])
    end
  end

  def add_client(user)
    program = ProgramDouble.new(broker.endpoint(user))
    transports[user] = GameRoomTransport.new(program)
    repositories[user] = GameRepository.new(program, transport: transports[user], server_tables: {})
    as(user) { transports[user].join_room(table, user) }
  end

  def as(user)
    previous = Thread.current[:game_room_test_user]
    Thread.current[:game_room_test_user] = user
    yield
  ensure
    Thread.current[:game_room_test_user] = previous
  end

  def context(user)
    contexts[user] ||= GameRoomGames::ActionContext.new(session_id: session['__id'],
      hidden_submissions: HiddenSubmissions::Vault.new(HiddenSubmissions::MemoryStorage.new))
  end

  def snapshot(user = 'Alice')
    as(user) do
      transports[user].room_snapshot(table)
      repositories[user].snapshot_for(session)
    end
  end

  def replay(user = 'Alice')
    current = snapshot(user)
    game.replay(current.session, current.events, repositories[user])
  end

  def choose(user, actor = user)
    act(user, actor, game.legal_actions(replay(user), actor).find { |action| action['action'] == 'select' })
  end

  def act(user, actor, selection)
    as(user) do
      current = snapshot(user)
      state = game.replay(current.session, current.events, repositories[user])
      status, plan = game.action_for(selection, state, actor, context: context(user))
      assert(status == :ok, "#{actor}: #{status}")
      repositories[user].append_events(session: current.session,
        sequence: repositories[user].next_sequence(current.session, current.events), events: plan.events, actor: actor)
    end
  end

  def guard(player: nil, replacement: nil)
    current = snapshot
    app.games.control_change_guard(table: table, game: game, session: current.session, player: player, replacement: replacement)
  end

  def native(user = 'Alice')
    broker.cores.values.first.views.find { |view| view.user == user }
  end
end
