require_relative "support/ui"

class Program
  def self.server_app(**_options); end
end

class Static < FakeControl
  def initialize(text)
    super()
    @header = text
  end
end

class CheckBox < FakeControl
  attr_accessor :checked
  def initialize(label, checked: false)
    super()
    @header, @checked = label, checked
  end
end

class EditBox
  module Flags
    Numbers = 4
  end

  def select_all
    @index, @check = 0, text.length
  end
end

class Form
  class << self
    attr_accessor :driver
  end

  def wait
    raise "Unexpected form" unless self.class.driver
    self.class.driver.call(self)
  end

  def resume; end
end

require_relative "../__app"

def assert(condition, message)
  raise message unless condition
end

# Drive the actual rules screen through both library and in-room paths.
# Only list/document rendering is simulated; no server or game is started.
game = GameRoomGames::Makao.new
[game.rule_book, game.rule_book(options: { "profile" => "joker" })].each do |book|
  visits = 0
  current_document = nil
  expected_index = 0
  Form.driver = lambda do |form|
    visible = form.fields - form.hidden_controls
    assert(visible.length == 1, "headings or buttons became extra tab stops")
    control = visible.first
    if control.is_a?(ListBox)
      assert(control.options == book.documents.map(&:title), "rules picker contains section headings instead of documents")
      assert(control.index == expected_index, "return from document loses chosen item")
      if visits < book.documents.length
        control.index = visits
        current_document = book.documents[visits]
        expected_index = visits
        visits += 1
        form.accept_button.trigger(:press)
      else
        form.cancel_button.trigger(:press)
      end
    else
      assert(control.is_a?(EditBox), "rules are not one text document")
      assert(control.flags & EditBox::Flags::ReadOnly != 0, "rules are editable")
      assert(control.flags & EditBox::Flags::MultiLine != 0, "rules lost multiline paragraphs")
      assert(control.text == current_document.text, "document did not contain all paragraphs")
      form.cancel_button.trigger(:press)
    end
  end
  GameRoomScreens::GameRules.new(book).wait
  assert(visits == book.documents.length, "a rules document could not be opened")
end

# Makao's existing custom profile must retain every agreed checkbox and both
# numeric values locally. Use real configuration and persistence methods,
# replacing only the host's UI and JSON store.
app = EltenGameRoom.allocate
store = {}
app.define_singleton_method(:read_json) { |file, default:| store.fetch(file, default) }
app.define_singleton_method(:update_json) do |file, default:, &block|
  store[file] = block.call(store.fetch(file, default))
end
definitions = game.option_definitions
switches = definitions.select { |definition| definition.kind == :boolean }
saved = { "profile" => "custom", "hand_size" => 8, "makao_penalty" => 4, "bot_delay" => 3 }
switches.each_with_index { |definition, index| saved[definition.key] = index.even? }
Form.driver = lambda do |form|
  profile = form.fields.find { |field| field.is_a?(ListBox) && field.header == "Rule profile" }
  profile.index = 3
  profile.trigger(:move)
  definitions.each do |definition|
    next if definition.key == "profile"
    field = form.fields.find { |control| control.header == definition.label }
    assert(field && !form.hidden_controls.include?(field), "Makao custom editor hides #{definition.key}")
    if definition.kind == :boolean
      field.checked = saved.fetch(definition.key)
    else
      field.text = saved.fetch(definition.key).to_s
    end
  end
  form.accept_button.trigger(:press)
end
result = app.send(:configure_game_options, game)
assert(result == saved, "Makao custom editor changed selected settings")
assert(store["game_option_preferences.json"]["makao"] == saved.reject { |key, _| key == "profile" }, "not every custom option was saved")

Form.driver = lambda do |form|
  profile = form.fields.find { |field| field.is_a?(ListBox) && field.header == "Rule profile" }
  assert(profile.index == 0, "saved custom profile replaced the simple default")
  profile.index = 3
  profile.trigger(:move)
  definitions.each do |definition|
    next if definition.key == "profile"
    field = form.fields.find { |control| control.header == definition.label }
    value = definition.kind == :boolean ? field.checked : field.text.to_i
    assert(value == saved.fetch(definition.key), "Makao forgot custom #{definition.key}")
  end
  form.accept_button.trigger(:press)
end
assert(app.send(:configure_game_options, game) == saved, "Makao could not reuse the custom profile")
Form.driver = nil
puts "Rules UI (2/3 documents) and Makao custom profile tests passed"
