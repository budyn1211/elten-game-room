require_relative "run-tests"

# A named selection only; execution, timeouts and reports belong to the shared runner.
tests = %w[
  test/new_games_116_test.rb
  test/five_games_regression_test.rb
  test/five_games_followup_test.rb
  test/five_games_207_feedback_test.rb
  test/five_games_ui_test.rb
  test/monopoly_regional_test.rb
  test/new_games_complete_match_test.rb
  test/monopoly_uno_poker_208_feedback_test.rb
  test/monopoly_management_ui_test.rb
  test/monopoly_poker_bot_208_feedback_test.rb
  test/uno_interceptions_test.rb
  test/uno_straights_test.rb
  test/uno_wild_colour_choice_test.rb
  test/makao_penalty_target_test.rb
  test/makao_bot_action_regressions_test.rb
  test/monopoly_property_messages_test.rb
  test/monopoly_trade_compact_test.rb
  test/game_event_transport_limit_test.rb
  test/game_sounds_test.rb
  test/game_messages_after_211_test.rb
  test/game_messages_ui_test.rb
  test/game_messages_translation_test.rb
  test/monopoly_auction_and_bankruptcy_test.rb
  test/monopoly_unaffordable_purchase_test.rb
]
exit GameRoomTestRunner.cli(ARGV, tests: tests, legacy_report: true,
  environment: {"GAME_ROOM_FIVE_GAMES_ONLY" => "1"},
  additional: ["tools/check-five-game-translations.rb"])
