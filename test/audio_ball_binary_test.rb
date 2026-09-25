require_relative "support/binary_suite"

# Every original scenario retains its assertions and binary runtime boundary,
# with fresh fixture/global state and the common timeout/skip reporting.
BinaryTestSuite.run(%w[
  audio_ball_binary_boundary_test
  audio_ball_client_test
  audio_ball_warning_recovery_test
  audio_ball_spectator_recovery_test
  audio_ball_settings_client_test
  audio_ball_difficulty_test
  audio_ball_settings_test
  audio_ball_point_audio_test
  audio_ball_announcements_test
  audio_ball_defense_input_test
  audio_ball_lane_test
  audio_ball_keyboard_test
  audio_ball_fast_input_test
  audio_ball_input_boundary_test
  audio_ball_held_engine_test
  audio_ball_flight_test
  audio_ball_client_audio_tick_test
  audio_ball_sound_pack_test
  audio_ball_stop_cue_test
], mode: "source", polish: [])
puts "PASS Audio Ball #{ARGV.first ? 'installer' : 'binary sources'}: actual runtime records, per-flight defense, seven-point matches, recovery and Pong score recordings"
