require_relative "game_option_form"

class CheckBox
  def focus(*_arguments)
    speak("#{@header} ... Checkbox #{checked ? 'ticked' : 'unticked'}")
  end
end

class CreationLobbyDouble
  Result = Struct.new(:table) do
    def created?; true; end
  end
  attr_reader :creations

  def initialize
    @creations = []
  end

  def create_table(**values)
    @creations << values
    Result.new({ "__id" => "created-table", "private" => values.fetch(:private_table) })
  end
end

class CreationFormApp < EltenGameRoom
  attr_reader :lobby, :network_calls, :opened_tables, :notices, :remembered

  def initialize(game)
    @creation_game = game
    @lobby = CreationLobbyDouble.new
    @network_calls, @opened_tables, @notices, @remembered = [], [], [], []
  end

  def select_game(*); @creation_game.id; end
  def game_definition(*); @creation_game; end
  def game_name(*); @creation_game.id; end
  def default_table_name; "Alice's table"; end
  def read_json(_, default:); default; end
  def remember_multiple_choice_options(*arguments); @remembered << arguments; end
  def run_network_task(title, **)
    @network_calls << title
    yield
  end
  def activate_table_transport(_); end
  def play_game_sound(*); end
  def show_table_screen(table); @opened_tables << table; end
  def alert(message); @notices << message; end
end

def privacy_field(form)
  found = form.fields.select { |field| field.is_a?(CheckBox) && field.header == "Private table" }
  assert(found.length == 1, "creation must contain one Private table checkbox in the game-options form")
  found.first
end
