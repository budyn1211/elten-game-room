# Loaded before a single selected scenario in its own Ruby process.
case ENV.fetch("GAME_ROOM_BINARY_MODE")
when "source" then require_relative "binary_rules_load"
when "dictionary" then require_relative "binary_rule_dictionary"
when "pong" then require_relative "pong_ui"
else raise "Unknown binary test bootstrap"
end
language = ENV.fetch("GAME_ROOM_BINARY_LANGUAGE")
$rules_english = language != "pl"
GameRoomTestLocalization.use_language(language)
