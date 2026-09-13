require_relative "support/ui"
require_relative "support/log"

class Program
  def self.server_app(**_options); end
end

module Session
  def self.name
    "Alice"
  end
end

class Static < FakeControl
  attr_reader :text

  def initialize(text)
    super()
    @text = text
  end

  def focus(*_arguments); end
end

class Form
  class << self
    attr_accessor :driver
  end

  alias wait_with_option_test_driver wait

  def wait
    wait_with_option_test_driver
    Form.driver.call(self)
  end

  def resume; end
end

require_relative "../__app"

def assert(condition, message)
  raise message if !condition
end

app = EltenGameRoom.allocate
app.define_singleton_method(:read_json) { |_path, default:| default }
app.define_singleton_method(:alert) { |message| raise message }
game = GameRoomGames::QuizParty.new
polish_set_ids = game.send(:available_content_sets, "pl-PL").map(&:id).sort
assert(
  polish_set_ids == ["quiz.wikidata", "quiz.witcher", "quiz.witcher.b", "quiz.witcher.g"],
  "the Polish question-set list is incomplete"
)
target_language = game.default_options["content_language_id"] == "en" ? "pl-PL" : "en"
step = 0

Form.driver = lambda do |form|
  definitions = game.effective_option_definitions
  language_definition = definitions.find { |definition| definition.key == "content_language_id" }
  language_control = form.fields.find do |field|
    field.is_a?(ListBox) && field.header == language_definition.label
  end
  raise "language control missing" if language_control == nil

  if step == 0
    language_control.index = language_definition.choices.index { |choice| choice.value == target_language }
    step += 1
    language_control.trigger(:move)
  else
    selected_language = language_definition.choices[language_control.index].value
    assert(selected_language == target_language, "rebuilding the option form reset the selected language")
    set_control = form.fields.find { |field| field.is_a?(ListBox) && field.header == "Game content set" }
    assert(form.fields[form.index] == set_control, "the rebuilt form did not focus the question set")
    expected_count = target_language == "pl-PL" ? 4 : 1
    assert(set_control != nil && set_control.options.length == expected_count, "changing language did not immediately replace the question sets")
    labels = set_control.options.join(" ")
    if target_language == "pl-PL"
      polish_counts = %w[quiz.wikidata.pl quiz.witcher.pl quiz.witcher.g.pl quiz.witcher.b.pl]
        .map { |id| GameRoomContent.registry.pack(id).entry_count.to_s }
      assert(polish_counts.all? { |count| labels.include?(count) } && !labels.include?(GameRoomContent.registry.pack("quiz.general.en").entry_count.to_s), "Polish still shows the English question set")
    else
      assert(labels.include?(GameRoomContent.registry.pack("quiz.general.en").entry_count.to_s), "English does not show the OpenTriviaQA set")
    end
    step += 1
    form.fields.find { |field| field.is_a?(Button) && field.label == "Create table" }.trigger(:press)
  end
end

options = app.send(:configure_game_options, game)
assert(step == 2, "changing the question language did not rebuild the option form once")
assert(options["content_language_id"] == target_language, "the rebuilt option form rejected the selected language")
selected_pack = game.selected_content_pack(options)
assert(selected_pack != nil && selected_pack.language_id == target_language, "the rebuilt option form did not select a compatible question set")

multiple_choice_game = Class.new(GameRoomGames::QuizParty) do
  def option_definitions
    super + [
      GameRoomGames::OptionDefinition.new(
        key: "topics",
        label: "Topics",
        kind: :multiple_choice,
        default: 1,
        choices: [
          GameRoomGames::OptionChoice.new(value: "alpha", label: "Alpha"),
          GameRoomGames::OptionChoice.new(value: "beta", label: "Beta")
        ]
      )
    ]
  end
end.new
multiple_target_language = multiple_choice_game.default_options["content_language_id"] == "en" ? "pl-PL" : "en"
multiple_step = 0

Form.driver = lambda do |form|
  definitions = multiple_choice_game.effective_option_definitions
  language_definition = definitions.find { |definition| definition.key == "content_language_id" }
  topics_definition = definitions.find { |definition| definition.key == "topics" }
  language_control = form.fields.find { |field| field.is_a?(ListBox) && field.header == language_definition.label }
  topics_control = form.fields.find { |field| field.is_a?(ListBox) && field.header == topics_definition.label }
  raise "multiple-choice controls missing" if language_control == nil || topics_control == nil

  if multiple_step == 0
    language_control.index = language_definition.choices.index { |choice| choice.value == multiple_target_language }
    topics_control.select_multiselection_indices([1])
    multiple_step += 1
    language_control.trigger(:move)
  else
    selected_language = language_definition.choices[language_control.index].value
    assert(selected_language == multiple_target_language, "rebuilding reset the language beside a multiple-choice option")
    assert(topics_control.multiselections.sort == [0, 1], "rebuilding reset a multiple-choice option")
    multiple_step += 1
    form.fields.find { |field| field.is_a?(Button) && field.label == "Create table" }.trigger(:press)
  end
end

multiple_options = app.send(:configure_game_options, multiple_choice_game)
assert(multiple_step == 2, "the multiple-choice option test did not rebuild the form")
assert(multiple_options["topics"] == 3, "the rebuilt form lost its multiple-choice mask")

puts "Game option form tests passed"
