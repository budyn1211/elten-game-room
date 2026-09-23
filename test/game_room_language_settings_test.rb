require_relative "support/ui"
require_relative "../lib/game_content"
require_relative "../lib/game_room_screens"
require_relative "../lib/game_room_localization"

GameRoomLocalization.boot(settings: { "interface_language" => "en" }, host_language: "en")

class CheckBox < FakeControl
  attr_accessor :checked

  def initialize(_label, checked: false)
    super()
    @checked = checked
  end
end

class Form
  class << self
    attr_accessor :language_settings_driver
  end

  def wait
    Form.language_settings_driver.call(self)
  end

  def resume; end
end

class ListBox
  attr_reader :language_tips

  def add_tip(tip)
    (@language_tips ||= []) << tip
    super
  end


end

def assert(condition, message)
  raise message unless condition
end

def settings_dialog(values = {}, &driver)
  Form.language_settings_driver = driver
  program = Object.new
  [:read_json, :write_json, :update_json, :run_network_task].each do |method|
    program.define_singleton_method(method) { |*| raise "language settings performed IO through #{method}" }
  end
  GameRoomScreens::Settings.new(values, games: [], program: program).wait
ensure
  Form.language_settings_driver = nil
end

settings_dialog do |form|
  assert(form.fields.first.options == ["Lobby messages", "Notification settings", "Sounds", "Widget", "Axel Pong", "Language"],
    "Language must follow Widget and Axel Pong without changing their category indices")
  form.cancel_button.trigger(:press)
end

settings_dialog("interface_language" => "pl", "known_languages" => %w[pl en]) do |form|
  categories = form.fields.first
  categories.index = 5
  categories.trigger(:move)
  visible = form.fields - form.hidden_controls
  assert(visible[1...-2].map(&:header) == ["Primary interface language", "Known languages"],
    "Tab must enter the primary selector then known languages without an extra help field")
  primary, known = visible[1..2]
  assert(primary.instance_variable_get(:@flags) == 0 && known.instance_variable_get(:@flags) == ListBox::Flags::MultiSelection,
    "primary must be single-select and known languages must be native MultiSelection")
  assert(primary.options == ["English", "polski"] && known.options == primary.options,
    "language choices do not match the available catalogs")
  assert(primary.index == 1 && known.multiselections == [0, 1], "saved language selections were not restored")
  categories.index = 4
  categories.trigger(:move)
  assert(form.hidden_controls.include?(primary) && form.hidden_controls.include?(known), "language controls remained visible in Pong")
  categories.index = 5
  categories.trigger(:move)
  assert((form.fields - form.hidden_controls) == visible, "returning to Language lost its controls or order")
  form.cancel_button.trigger(:press)
end

settings_dialog("interface_language" => "pl", "known_languages" => %w[pl en]) do |form|
  primary, known = form.fields[-4..-3]
  known.deselect_multiselection_indices([1])
  assert(known.multiselections == [0, 1], "the primary language can be unchecked")
  primary.index = 0
  primary.trigger(:move)
  known.deselect_multiselection_indices([0, 1])
  assert(known.multiselections == [0], "changing primary must unlock the previous language and retain the new one")
  primary.index = 1
  primary.trigger(:move)
  assert(known.multiselections == [0, 1], "changing primary did not check the new primary")
  known.deselect_multiselection_indices([0, 1])
  assert(known.multiselections == [1], "select-none removed the primary language")
  form.cancel_button.trigger(:press)
end

original = {
  "interface_language" => "en", "known_languages" => ["en"].freeze,
  "unrelated" => { "keep" => true }.freeze, "table_presets" => [nil].freeze,
  "pong" => GameRoomPong::Preferences::DEFAULTS.merge("own_volume" => 75).freeze,
  "sound_volumes" => GameRoomPreferences.sound_volumes("game_sounds" => false).freeze
}.freeze
before = Marshal.dump(original)
saved = settings_dialog(original) do |form|
  primary, known = form.fields[-4..-3]
  primary.index = 1
  primary.trigger(:move)
  known.deselect_multiselection_indices([0])
  form.accept_button.trigger(:press)
end
assert(saved["interface_language"] == "pl" && saved["known_languages"] == ["pl"], "Save did not return the staged language choices")
assert(saved["unrelated"] == original["unrelated"] && saved["pong"] == original["pong"] && saved["sound_volumes"] == original["sound_volumes"],
  "language Save changed unrelated settings")
assert(!saved.key?("table_presets"), "language Save could overwrite independently saved table shortcuts")
assert(Marshal.dump(original) == before, "language editing mutated the opening settings")
assert(GameRoomLocalization.primary_language == "en", "Save changed the active language before restart")
cancelled = settings_dialog(original) do |form|
  primary = form.fields[-4]
  primary.index = 1
  primary.trigger(:move)
  form.cancel_button.trigger(:press)
end
assert(cancelled.nil? && Marshal.dump(original) == before, "Cancel persisted staged language choices")
settings_dialog(saved) do |form|
  primary, known = form.fields[-4..-3]
  assert(primary.index == 1 && known.multiselections == [1], "reopening settings lost the saved language choices")
  form.cancel_button.trigger(:press)
end

normalized = GameRoomPreferences.normalize(original.merge("interface_language" => "PL-pl", "known_languages" => %w[en en xx]), [])
assert(normalized["interface_language"] == "pl" && normalized["known_languages"] == %w[en pl],
  "preferences must merge normalized languages and include the primary language")
assert(normalized["unrelated"] == original["unrelated"] && normalized["pong"] == original["pong"] &&
  normalized["table_presets"] == original["table_presets"] && normalized["sound_volumes"] == original["sound_volumes"],
  "normalizing language preferences changed unrelated settings")
assert(Marshal.dump(original) == before, "normalizing preferences mutated saved settings")
[nil, {}, { "interface_language" => "unknown", "known_languages" => 123 }].each do |values|
  expected = GameRoomLocalization.normalize_settings(values)
  actual = GameRoomPreferences.normalize(values, [])
  assert(actual.slice("interface_language", "known_languages") == expected, "preference defaults differ from the language backend")
end
symbolized = GameRoomPreferences.normalize({ interface_language: "pl", known_languages: [] }, [])
assert(symbolized["interface_language"] == "pl" && symbolized["known_languages"] == ["pl"], "language normalization discarded symbol-keyed preferences")

language_tip = "Missing translations use other known languages, then English. Restart ELTEN to apply language changes."
settings_dialog do |form|
  form.fields[-4..-3].each do |control|
    assert(control.language_tips.to_a.include?(language_tip), "language controls do not explain fallback and restart in their help")
  end
  form.cancel_button.trigger(:press)
end

GameRoomLocalization.boot(settings: { "interface_language" => "pl" }, host_language: "en")
settings_dialog do |form|
  assert(form.fields.first.header == "Ustawienia", "settings labels did not use the independent Polish catalog")
  form.cancel_button.trigger(:press)
end
GameRoomLocalization.boot(settings: { "interface_language" => "en" }, host_language: "en")

translation_path = File.expand_path("../locale/interface-language-pl.json", __dir__)
assert(File.file?(translation_path), "Polish language-settings translations are missing")
translations = JSON.parse(File.read(translation_path, encoding: "UTF-8"))
{
  "Language" => "Język",
  "Primary interface language" => "Główny język interfejsu",
  "Known languages" => "Znane języki",
  language_tip => "Jeśli brakuje tłumaczenia, używany jest inny znany język, a na końcu angielski. Zmiany języka zaczną obowiązywać po ponownym uruchomieniu ELTEN-a."
}.each do |source, translated|
  assert(translations[source] == translated, "missing Polish language setting: #{source}")
end

metadata = "Content-Type: text/plain; charset=UTF-8\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Language-Name: čeština\n"
header = [0x950412de, 0, 1, 28, 36, 0, 0].pack("V7")
czech = header + [0, header.bytesize + 16, metadata.bytesize, header.bytesize + 17].pack("V4") + "\0" + metadata.b + "\0"
catalogs = { "pl" => File.binread(File.expand_path("../locale/PL.mo", __dir__)), "cs" => czech }
runtime = Object.new
runtime.define_singleton_method(:language_files) { catalogs }
runtime.define_singleton_method(:manifest) { Struct.new(:supported_languages).new(%w[en pl cs]) }
runtime.define_singleton_method(:language_data) { |language| catalogs[language] }
GameRoomLocalization.boot(runtime: runtime, settings: { "interface_language" => "en" }, host_language: "en")
languages = GameRoomLocalization.available_languages
codes = languages.map { |language| language.fetch(:id) }
assert(codes.include?("cs"), "the future-language fixture was not discovered by the real backend")
czech_index, english_index, polish_index = %w[cs en pl].map { |code| codes.index(code) }
future_saved = settings_dialog("interface_language" => "en", "known_languages" => ["en"]) do |form|
  primary, known = form.fields[-4..-3]
  assert(primary.options == languages.map { |language| language.fetch(:label) } && known.options == primary.options,
    "a future catalog was not added to both language controls")
  assert(primary.options[czech_index] == "čeština" && primary.options.all? { |label| label.encoding == Encoding::UTF_8 && label.valid_encoding? },
    "a future catalog's native label lost UTF-8 encoding")
  primary.index = czech_index
  primary.trigger(:move)
  known.select_multiselection_indices([polish_index])
  known.deselect_multiselection_indices([czech_index, english_index])
  assert(known.multiselections.sort == [czech_index, polish_index].sort, "the future primary was removable or a known language was lost")
  form.accept_button.trigger(:press)
end
future_saved = GameRoomPreferences.normalize(future_saved, [])
assert(future_saved["interface_language"] == "cs" && future_saved["known_languages"].sort == %w[cs pl],
  "a future language was not persisted by its stable code")
assert(GameRoomLocalization.primary_language == "en", "choosing a future language changed the live interface")
settings_dialog(future_saved) do |form|
  primary, known = form.fields[-4..-3]
  assert(primary.index == czech_index && known.multiselections.sort == [czech_index, polish_index].sort,
    "a future language was not restored when reopening settings")
  form.cancel_button.trigger(:press)
end
GameRoomLocalization.boot(settings: { "interface_language" => "en" }, host_language: "en")

puts "PASS Game Room language settings: category order/visibility, native multiselection lock, staged Save/Cancel, normalization, help, Polish labels and future Czech catalog"
