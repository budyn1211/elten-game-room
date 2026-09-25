require_relative "ui"
require_relative "native_live_sessions"
class Program
  def self.server_app(**_options); end
  def self.app_runtime; nil; end
end
require_relative "../../__app"

class LifecycleApp < EltenGameRoom
  attr_reader :transport, :games, :lobby, :notices, :form_initial
  attr_accessor :form_answer, :during_dialog, :confirmed
  def initialize(broker)
    @notices, @confirmed = [], true
    program = ProgramDouble.new(broker.endpoint("Alice"))
    @transport = GameRoomTransport.new(program)
    @lobby = LobbyRepository.new(program, transport: @transport, server_tables: {})
    @games = GameRepository.new(program, transport: @transport, server_tables: {})
    @table_activity = TableActivityRepository.new(transport: @transport, server_tables: {})
  end
  def run_network_task(*_args, **_kwargs); yield; end
  def confirm(_question); @confirmed; end
  def alert(message); @notices << message; end
  def remember_multiple_choice_options(*_args); end
  def configure_game_options(game, initial_options: nil, submit_label: nil)
    @form_initial = [game.id, initial_options, submit_label]
    @during_dialog&.call
    @form_answer
  end
end

class LifecycleMenu
  attr_reader :items
  def initialize; @items = []; end
  def option(label, value = nil, key = '', &handler); @items << [label,key,handler]; end
end
