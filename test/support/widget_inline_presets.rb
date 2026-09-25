require_relative "private_table_creation"

class InlinePresetApp < CreationFormApp
  attr_reader :stored, :writes, :choices
  attr_accessor :cancel_game, :fail_write

  def initialize
    super(GameRoomGames::Makao.new)
    @stored = GameRoomPreferences.defaults(GAME_REGISTRY.ids).merge("sentinel" => "keep")
    @writes, @choices = [], 0
  end

  def read_json(path, default:)
    assert(path == "settings.json", "unexpected local read")
    JSON.parse(JSON.generate(@stored))
  end

  def update_json(path, default:)
    assert(path == "settings.json", "unexpected local write")
    raise IOError, "test storage failure" if fail_write
    @stored = yield(JSON.parse(JSON.generate(@stored)))
    @writes << JSON.parse(JSON.generate(@stored))
  end

  def select_game(*)
    @choices += 1
    cancel_game ? nil : super
  end

  def self.table_watch_repository
    @watch_repository ||= Object.new.tap do |repo|
      def repo.load(_); []; end
      def repo.save(*); raise "unexpected server write"; end
    end
  end

  def self.table_watch_set_games(_); end
  def self.contacts_settings_changed(_); end
end

def inline_presets(form)
  form.fields.first.index = form.fields.first.options.index('Widget')
  form.fields.first.trigger(:move)
  list = form.fields.find { |field| field.is_a?(ListBox) && field.header == "Table shortcuts" }
  assert(list && !form.hidden_controls.include?(list), "missing inline preset list in Widget")
  visible = form.fields.reject { |field| form.hidden_controls.include?(field) }
  assert(visible[-3].equal?(list), "presets are not the final Widget field before Save/Cancel")
  assert(list.options.length == 30, "wrong slot count")
  form.index = form.fields.index(list)
  list
end
