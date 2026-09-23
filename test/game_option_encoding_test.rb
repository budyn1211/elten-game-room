require_relative "packaged_rules_encoding_test"

# Dictionary#find returns an untranslated source unchanged when its key is
# absent. In an installed app that source is ASCII-8BIT, not necessarily UTF-8.
# The host's checkbox role and state can still be translated (e.g. Russian).
$option_host_language = "ru"

def p_(_context, text)
  {
    "en" => { "Checkbox" => "Checkbox", "ticked" => "ticked", "unticked" => "unticked" },
    "pl" => { "Checkbox" => "Pole wyboru", "ticked" => "zaznaczone", "unticked" => "niezaznaczone" },
    "ru" => { "Checkbox" => "Флажок", "ticked" => "отмечено", "unticked" => "не отмечено" }
  }.fetch($option_host_language).fetch(text)
end

class CheckBox < FakeControl
  attr_accessor :label, :checked

  def initialize(label, checked: false)
    super()
    @label, @checked = label, checked
  end

  # Same concatenations as ELTEN src/ui/controls/check_box.rb#focus. Do not
  # repair encoding in this fake: doing that would hide the reported crash.
  def focus(*_arguments)
    text = @label + " ... "
    text += p_("EAPI_Form", "Checkbox") + " "
    text += p_("EAPI_Form", @checked ? "ticked" : "unticked")
    speak(text)
  end
end

class Static < FakeControl
  attr_reader :text
  def initialize(text)
    super()
    @text = text
  end
end

class EditBox
  module Flags
    Numbers = 8 unless const_defined?(:Numbers)
  end
  def select_all; end
end

class Form
  class << self
    attr_accessor :option_encoding_driver
  end
  def wait
    Form.option_encoding_driver.call(self)
  end
  def resume; end
end

app = EltenGameRoom.allocate
app.define_singleton_method(:read_json) { |_path, default:| default }
app.define_singleton_method(:remember_multiple_choice_options) { |*_arguments| }
app.define_singleton_method(:alert) { |message| raise message }
checks = { forms: 0, checkbox_states: 0, labels: 0 }
Form.option_encoding_driver = lambda do |form|
  form_labels = []
  form.fields.each do |field|
    next if form.hidden_controls.include?(field)
    labels = case field
    when CheckBox
      original = field.checked
      [true, false].each do |checked|
        field.checked = checked
        field.focus
        raise "Checkbox speech is not valid UTF-8" unless $spoken_messages.last.encoding == Encoding::UTF_8 && $spoken_messages.last.valid_encoding?
        checks[:checkbox_states] += 1
      end
      field.checked = original
      [field.label]
    when ListBox then [field.header] + field.options
    when EditBox then [field.header]
    else []
    end
    form_labels.concat(labels)
  end
  form_labels.each do |label|
    raise "Option label was not normalized: #{label.inspect}" unless label.encoding == Encoding::UTF_8 && label.valid_encoding?
    # Also exercise non-checkbox fields next to the host's translated text.
    label + " — выбранное поле"
    checks[:labels] += 1
  end
  checks[:forms] += 1
  form.accept_button.trigger(:press)
end

# Reversi/Russian first reproduces the real failure before any stricter
# encoding assertions, with the untranslated em dash in Mandatory capture.
ids = ["reversi"] + (EltenGameRoom::GAME_REGISTRY.ids - ["reversi"])
%w[ru en pl].each do |language|
  $option_host_language = language
  GameRoomTestLocalization.use_language(language)
  ids.each do |id|
    game = EltenGameRoom::GAME_REGISTRY.build(id)
    actual = app.send(:configure_game_options, game)
    raise "Encoding fix changed defaults for #{id}" unless actual == game.default_options
    if id == "tysiac"
      %w[2 3].product([false, true]).each do |size, award|
        changed = game.normalize_options("variant" => "two_players", "talon_size" => size, "last_trick_talon" => award)
        actual = app.send(:configure_game_options, game, initial_options: changed, submit_label: "Save changes")
        raise "Editing Tysiac changed selected variants" unless actual == changed
      end
    end
    next unless id == "reversi"

    changed = game.normalize_options("allow_passing" => false, "mandatory_capture" => false)
    actual = app.send(:configure_game_options, game, initial_options: changed, submit_label: "Save changes")
    raise "Editing Reversi changed selected variants" unless actual == changed
  end
end

label = "Capture — żółty".b.freeze
value = "stable-value".b.freeze
choice = GameRoomGames::OptionChoice.new(value: value, label: label)
definition = GameRoomGames::OptionDefinition.new(key: value, label: label, kind: :choice,
  default: value, choices: [choice], visible_if: { "enabled" => true })
raise "Encoding fix mutated a frozen source string" unless label.encoding == Encoding::ASCII_8BIT
raise "Encoding fix changed option identity" unless definition.key.equal?(value) && definition.default.equal?(value) && choice.value.equal?(value)
[definition.label, choice.label].each do |text|
  raise "Lost option label characters" unless text == "Capture — żółty" && text.encoding == Encoding::UTF_8
end

puts "Binary game-option focus passed: #{checks[:forms]} forms, #{checks[:checkbox_states]} checkbox states, #{checks[:labels]} labels; untranslated EN with RU host, EN and PL"
