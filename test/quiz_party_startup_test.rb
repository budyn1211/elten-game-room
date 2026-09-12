$LOAD_PATH.unshift(File.expand_path("..", __dir__))

def _(text)
  text
end

def p_(_context, text)
  text
end

module GameSurfaces
  Action = Struct.new(:kind, :name, :payload, :source, keyword_init: true) do
    def initialize(kind:, name:, payload: {}, source: nil)
      super(kind: kind.to_s, name: name.to_s, payload: payload, source: source)
    end

    def [](key)
      return kind if key.to_s == "kind"
      return name if ["action", "name"].include?(key.to_s)

      payload[key.to_s]
    end
  end
  QuestionOption = Struct.new(:id, :label, :value, keyword_init: true)
  QuestionSpec = Struct.new(:id, :prompt, :mode, :options, :value, :submit_label, :required, :read_only, :max_length, :submit_on_select, :prompt_in_choices, keyword_init: true)
end

require "json"
require_relative "../lib/game_content"
require_relative "../content/languages"
require_relative "../content/quiz_general_en"
require_relative "../content/quiz_pl_wikidata"
require_relative "../content/quiz_witcher_pl"
require_relative "../games/quiz_party"
require_relative "../games/registry"

def assert(condition, message)
  raise message if !condition
end

registry = GameRoomGames::Registry.new([GameRoomGames::QuizParty])
assert(registry.ids == ["quiz"], "the game did not register under its own id")
assert(registry.name("quiz") == "Quiz Party", "the registered game has no readable name")

game = registry.build("quiz")
book = game.rule_book
assert(book.sections.map(&:id) == [:goal, :setup, :play, :ending, :variants, :controls], "the rule book has the wrong sections")
assert(book.sections.all? { |section| section.paragraphs.any? { |text| !text.to_s.strip.empty? } }, "a rule section is empty")

options = game.default_options
options_book = game.rule_book(options: options)
assert(options_book.sections.first.id == :current_options, "the rule book does not show the table options")
assert(options_book.sections.first.paragraphs.first.include?("15"), "the shown table options lost the target score")
keys = game.effective_option_definitions.map(&:key)
assert(keys.uniq.length == keys.length, "the game exposes duplicate option keys")
assert(keys.include?("content_language_id"), "the table cannot choose a question language")

polish_pack = GameRoomContent.registry.pack("quiz.wikidata.pl")
assert(polish_pack != nil && polish_pack.verified?, "the Polish Wikidata question pack did not load")
assert(polish_pack.data["questions"].length == 15_498, "the Polish Wikidata question pack lost its questions")
witcher_pack = GameRoomContent.registry.pack("quiz.witcher.pl")
assert(witcher_pack != nil && witcher_pack.verified?, "the Polish Witcher question pack did not load")
assert(witcher_pack.data["questions"].length == 6_623, "the Polish Witcher question pack lost its questions")
assert(game.selected_content_pack(options) != nil, "the default table options do not resolve to an installed pack")
polish_sets = game.send(:available_content_sets, "pl-PL").map(&:id).sort
assert(polish_sets == ["quiz.wikidata", "quiz.witcher"], "Polish does not offer exactly the two intended question sets")
[
  ["quiz.wikidata", "pl-PL"],
  ["quiz.witcher", "pl-PL"]
].each do |set_id, language_id|
  set_options = game.normalize_options("content_set_id" => set_id, "content_language_id" => language_id)
  assert(JSON.generate(set_options).bytesize <= 256, "#{set_id} options exceed the server field limit")
end

english_pack = GameRoomContent.registry.pack("quiz.general.en")
assert(english_pack != nil && english_pack.verified?, "the English question pack did not load")
assert(english_pack.license == "CC-BY-SA-4.0", "the English question pack lost its license")
assert(english_pack.author == "OpenTriviaQA contributors", "the English question pack lost its attribution")
assert(english_pack.data["questions"].length == 28_577, "the English question pack lost its questions")
assert(english_pack.data["questions"].map { |question| question["category"] }.uniq.length == 20, "the English question pack lost its categories")
assert(GameRoomContent.registry.pack_set("quiz.general").language_ids == ["en"], "the removed Polish general variant is still registered")

GameRoomContent.registry.register_language(
  GameRoomContent::LanguageProfile.new(
    id: "it-IT",
    label: "Italian",
    alphabet: ("a".."z").to_a,
    normalizer: ->(text) { text.downcase }
  )
)
GameRoomContent.registry.register_pack(
  GameRoomContent::Pack.new(
    id: "quiz.general.it",
    set_id: "quiz.general",
    kind: :quiz,
    language_id: "it-IT",
    version: 1,
    title: "General knowledge",
    game_ids: ["quiz"],
    author: "ELTEN Game Room",
    license: "CC0-1.0",
    data: {
      questions: [
        {
          id: "it0000000001",
          category: "geografia",
          level: "easy",
          prompt: "Qual e la capitale dell'Italia?",
          correct: "Roma",
          wrong: ["Milano", "Napoli", "Torino"]
        },
        {
          id: "it0000000002",
          category: "geografia",
          level: "easy",
          prompt: "Qual e la capitale della Francia?",
          correct: "Parigi",
          wrong: ["Lione", "Marsiglia", "Nizza"]
        },
        {
          id: "it0000000003",
          category: "geografia",
          level: "easy",
          prompt: "Qual e la capitale della Spagna?",
          correct: "Madrid",
          wrong: ["Barcellona", "Valencia", "Siviglia"]
        }
      ]
    }
  )
)

fresh = GameRoomGames::QuizParty.new
language_choices = fresh.effective_option_definitions
  .find { |definition| definition.key == "content_language_id" }.choices.map(&:value)
assert(language_choices.sort == ["en", "it-IT", "pl-PL"], "a newly installed language did not appear as a table choice: #{language_choices.inspect}")

italian = fresh.normalize_options(
  "content_set_id" => "quiz.general",
  "content_language_id" => "it-IT"
)
assert(fresh.validation_error(italian, player_count: 2) == nil, "an Italian table was rejected: #{fresh.validation_error(italian, player_count: 2)}")
assert(fresh.selected_content_pack(italian).language_id == "it-IT", "the Italian table did not resolve to the Italian pack")
assert(fresh.options_summary(italian).include?("15"), "the Italian table lost its options summary")

mismatched = italian.merge("content_pack_checksum" => "0" * 64)
assert(fresh.validation_error(mismatched, player_count: 2) != nil, "a table with a tampered content checksum was accepted")

puts "Quiz Party startup tests passed: registry, two Polish sets, English OpenTriviaQA, and an added Italian language"
