require_relative "run-tests"

# A named selection only; execution, timeouts and reports belong to the shared runner.
tests = %w[
  test/audit_212_rules_and_decisions_test.rb
  test/audit_212_strategy_features_test.rb
  test/audit_212_search_test.rb
  test/audit_212_information_test.rb
  test/audit_212_spades_decisions_test.rb
  test/audit_212_tic_exhaustive_test.rb
  test/tic_tac_toe_test.rb
  test/four_in_a_row_test.rb
  test/new_board_games_test.rb
  test/checkers_bot_optimization_test.rb
  test/farkle_test.rb
  test/ninety_nine_test.rb
  test/categories_test.rb
  test/tysiac_test.rb
  test/tysiac_audit_test.rb
  test/spades_test.rb
  test/spades_planner_test.rb
  test/spades_table_533_regression_test.rb
  test/strategic_bots_test.rb
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
  test/monopoly_property_messages_test.rb
  test/game_messages_after_211_test.rb
  test/game_messages_ui_test.rb
  test/game_messages_translation_test.rb
  test/monopoly_auction_and_bankruptcy_test.rb
  test/game_rules_test.rb
  test/game_rules_ui_test.rb
  test/game_rules_translation_test.rb
  test/packaged_rules_encoding_test.rb
]
exit GameRoomTestRunner.cli(ARGV, tests: tests, legacy_report: true,
  environment: {"GAME_ROOM_FIVE_GAMES_ONLY" => "1"},
  additional: ["tools/check-five-game-translations.rb"])
