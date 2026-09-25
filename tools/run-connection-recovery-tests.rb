require_relative "run-tests"

# A named selection only; execution, timeouts and reports belong to the shared runner.
tests = %w[
  test/connection_recovery_test.rb
  test/connection_recovery_ui_test.rb
  test/synchronization_regressions_test.rb
  test/native_live_sessions_store_test.rb
  test/live_sessions_multiplayer_test.rb
  test/live_sessions_resilience_test.rb
  test/transport_test.rb
  test/game_sync_test.rb
  test/game_screen_network_test.rb
  test/room_interface_test.rb
  test/game_room_settings_widget_test.rb
  test/game_sounds_test.rb
  test/bot_turn_controller_test.rb
  test/quiz_party_review_regressions_test.rb
  test/observer_and_shortcut_regressions_test.rb
  test/game_event_transport_limit_test.rb
  test/monopoly_trade_compact_test.rb
  test/packaged_rules_encoding_test.rb
]
exit GameRoomTestRunner.cli(ARGV, tests: tests, legacy_report: true)
