def _(text)
  text
end

require_relative "../games/base"
require_relative "../games/four_in_a_row"
require_relative "../games/tic_tac_toe"
require_relative "../games/spades"
require_relative "../games/farkle"
require_relative "../games/ninety_nine"
require_relative "../games/tysiac"
require_relative "../games/registry"

def assert(condition, message)
  raise message if !condition
end

game_types = [
  GameRoomGames::FourInARow,
  GameRoomGames::TicTacToe,
  GameRoomGames::Spades,
  GameRoomGames::Farkle,
  GameRoomGames::NinetyNine,
  GameRoomGames::Tysiac
]

registry = GameRoomGames::Registry.new(game_types)
assert(registry.ids.length == 6, "the rules registry lost a game")

game_types.each do |game_type|
  game = game_type.new
  book = game.rule_book
  ids = book.sections.map(&:id)
  missing = GameRoomRules::REQUIRED_SECTION_IDS - ids
  assert(missing.empty?, "#{game.id} is missing rule sections: #{missing.join(", ")}")
  required_order = ids.select { |id| GameRoomRules::REQUIRED_SECTION_IDS.include?(id) }
  assert(required_order == GameRoomRules::REQUIRED_SECTION_IDS, "#{game.id} has rule sections out of order")
  assert(ids.uniq.length == ids.length, "#{game.id} repeats a rule section")
  assert(book.sections.all? { |section| !section.text.empty? }, "#{game.id} contains empty rules")
  assert(book.sections.all? { |section| !section.title.empty? }, "#{game.id} contains an untitled rule section")
end

farkle = GameRoomGames::Farkle.new
configured = farkle.rule_book(
  options: {
    "score_limit" => 2_000,
    "turn_minimum" => 40,
    "entry_minimum" => 80
  }
)
assert(configured.sections.first.id == :current_options, "room rules do not begin with current table options")
assert(configured.sections.first.text.include?("2000"), "room rules lost the configured score limit")
assert(farkle.rule_book.sections.first.id == :goal, "library rules unexpectedly contain table options")

class ShortcutEventSource
  attr_accessor :pressed_key

  def keyevents
    [[:key_a, :a]]
  end

  def key_first_pressed?(key)
    key == pressed_key
  end
end

shortcut_source = ShortcutEventSource.new
shortcut_source.extend(GameRoomRules::ShortcutFormEvents)
shortcut_source.pressed_key = 0x70
shortcut_events = shortcut_source.send(:keyevents)
assert(shortcut_events.include?([:key_f1, :f1]), "F1 is not captured directly by the form")
assert(shortcut_events.include?([:key_a, :a]), "the rules shortcut replaced standard form events")
shortcut_source.pressed_key = nil
assert(!shortcut_source.send(:keyevents).include?([:key_f1, :f1]), "an idle form reported F1")

assert(GameRoomRules.ctrl_f1_event?([false, true, false]), "Ctrl+F1 was not recognized")
assert(!GameRoomRules.ctrl_f1_event?([false, false, false]), "F1 without Ctrl opened the rules")
assert(!GameRoomRules.ctrl_f1_event?([true, true, false]), "Ctrl+Shift+F1 opened the rules")
assert(!GameRoomRules.ctrl_f1_event?([false, true, true]), "Ctrl+Alt+F1 opened the rules")

tip_field = Object.new
tips = []
tip_field.define_singleton_method(:add_tip) { |tip| tips << tip }
bound_handler = nil
fake_form = Object.new
fake_form.define_singleton_method(:extend) { |_mod| self }
fake_form.define_singleton_method(:on) do |event, &handler|
  bound_handler = [event, handler]
end
called = false
GameRoomRules.bind_ctrl_f1(fake_form, [tip_field]) { called = true }
assert(tips == ["Press Ctrl+F1 to read the game rules."], "F1 help does not advertise Ctrl+F1")
assert(bound_handler[0] == :key_f1, "Ctrl+F1 was bound to the wrong form event")
bound_handler[1].call([false, true, false])
assert(called, "the Ctrl+F1 handler was not called")

invalid_game = Class.new(GameRoomGames::Base) do
  def id
    "invalid"
  end

  def name
    "Invalid"
  end

  def rule_sections
    [rule_section(:goal, "Goal", "Missing the other required sections")]
  end
end
begin
  GameRoomGames::Registry.new([invalid_game])
  raise "the registry accepted a game with incomplete rules"
rescue ArgumentError => error
  raise if !error.message.include?("missing rule sections")
end

puts "Game rules tests passed"
