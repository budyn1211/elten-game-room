require_relative "packaged_rules_encoding_test"

# Match Dictionary#loadmo/#find: keys stay binary, successful values become
# UTF-8, and a missing key is returned unchanged. No helpful encoding fix in
# the fake. Optionally exercise the real, local ELTEN dictionary as well.
class BinaryRuleDictionary
  def initialize(catalog)
    @catalog = catalog.to_h { |key, value| [key.b, value] }
  end
  def _(source)
    @catalog.fetch(source, source)
  end
end

$rules_dictionary = BinaryRuleDictionary.new(RULES_CATALOG)
if ENV["ELTEN_DICTIONARY_SOURCE"]
  module EltenAPI; module Resources; end; end
  module Programs
    def self.current_runtime; nil; end
    def self.runtime_from_caller; nil; end
  end
  require ENV.fetch("ELTEN_DICTIONARY_SOURCE")
  $rules_dictionary = Object.new.extend(EltenAPI::Dictionary)
  $rules_dictionary.send(:loadmo, BinaryRulesLoad.read(File.join(BinaryRulesLoad::ROOT, "locale/PL.mo")))
end

def _(source)
  return source if $rules_english
  $rules_dictionary.send(:_, source)
end

GameRoomTestLocalization.use_language(:pl)
game = GameRoomGames::Taboo.new
authoring = JSON.parse(File.read(File.join(BinaryRulesLoad::ROOT, "docs/rulebooks/taboo.json"), encoding: "UTF-8"))
english_sources = authoring.fetch("sections").flat_map { |section| section.fetch("paragraphs").map { |pair| pair.fetch("en") } }
  .reject(&:ascii_only?)
raise "Missing non-ASCII fixtures" if english_sources.empty?
english_sources.each do |source|
  raise "Fixture does not reproduce native lookup failure" unless _(source) == source
  raise "Local rule translation did not recover binary key" unless GameRoomRules.translate(source) == RULES_CATALOG.fetch(source)
end

original_source = BinaryRulesLoad.read(File.join(BinaryRulesLoad::ROOT, "games/taboo_ui.rb"))
raise "Taboo sources lack declared encoding" unless original_source.start_with?("# encoding: UTF-8")
[false, true].each do |english|
  $rules_english = english
  GameRoomTestLocalization.use_language(english ? :en : :pl)
  documents_by_language = %w[pl-PL en].map do |language|
    options = game.normalize_options("content_language_id" => language)
    game.rule_book(options: options).documents.take(2)
  end
  raise "Rules followed card language instead of interface" unless documents_by_language[0].map(&:text) == documents_by_language[1].map(&:text)
  documents_by_language.flatten.each do |document|
    raise "Bad rule encoding" unless document.text.encoding == Encoding::UTF_8 && document.text.valid_encoding?
  end
  combined = documents_by_language.first.map(&:text).join("\n")
  english_sources.each do |source|
    expected = english ? source : RULES_CATALOG.fetch(source)
    raise "Mixed-language Taboo document" unless combined.include?(expected)
  end
end
puts "PASS Taboo: binary/native dictionary, complete rules and shortcuts, PL/EN independent of card language"
