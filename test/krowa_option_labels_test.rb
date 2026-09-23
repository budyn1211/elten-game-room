require_relative "taboo_rules_dictionary_test"

def assert(value, message)
  raise message unless value
end

game = GameRoomGames::Krowa.new
%w[pl en fallback].each do |language|
  $rules_english = language != "pl"
  GameRoomTestLocalization.use_language(language)
  expected = language == "pl" ? ["Liczba liter", "Kryterium wyniku"] : ["Number of letters", "Scoring criterion"]
  labels = game.option_definitions.to_h { |definition| [definition.key, definition.label] }
  assert(labels.values_at("length", "race_scoring") == expected, "Redundant Krowa labels in #{language}: #{labels}")
  {"daily" => %w[variant], "random" => %w[variant length], "race" => %w[variant length race_scoring], "tower" => %w[variant]}.each do |variant, keys|
    options = game.normalize_options("variant" => variant)
    actual = game.effective_option_definitions(options).select { |definition| game.option_visible?(definition, options) }.map(&:key)
    assert(actual == keys, "Visibility changed for #{variant}")
  end
  rules = game.rule_book.documents.first.text
  expected.each { |label| assert(rules.include?(label), "Help omits the current label #{label}") }
end
puts "PASS Krowa: concise labels, matching help and variant visibility in PL/EN/fallback"
