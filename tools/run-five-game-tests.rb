require "rbconfig"
root = File.expand_path("..", __dir__)
tests = %w[new_games_116_test five_games_regression_test five_games_followup_test five_games_207_feedback_test five_games_ui_test monopoly_regional_test new_games_complete_match_test monopoly_uno_poker_208_feedback_test monopoly_management_ui_test monopoly_poker_bot_208_feedback_test uno_interceptions_test monopoly_property_messages_test game_messages_after_211_test game_messages_ui_test game_messages_translation_test monopoly_auction_and_bankruptcy_test]
tests.each do |name|
  puts "Running #{name}"
  ok = system({ "GAME_ROOM_FIVE_GAMES_ONLY" => "1" }, RbConfig.ruby, "test/#{name}.rb", chdir: root)
  abort "Failed: #{name}" unless ok
end
abort "Missing translations" unless system(RbConfig.ruby, "tools/check-five-game-translations.rb", chdir: root)
puts "Only UNO, Poker, Yahtzee, Monopoly and Makao were tested."
