require_relative "support/binary_suite"

# Every original scenario retains its assertions and binary runtime boundary,
# with fresh fixture/global state and the common timeout/skip reporting.
BinaryTestSuite.run(%w[
  axel_pong_engine_test
  realtime_protocol_test
  axel_pong_integration_test
  axel_pong_rally_sync_test
  axel_pong_serve_input_test
  axel_pong_audio_feedback_test
  axel_pong_point_audio_test
  axel_pong_reference_test
  axel_pong_audio_reference_test
  axel_pong_hurry_test
  axel_pong_peer_events_test
  axel_pong_frame_timing_test
  axel_pong_mouse_client_test
  axel_pong_deep_parity_test
  axel_pong_parity_fixes_test
  axel_pong_source_physics_test
  axel_pong_source_audio_test
  axel_pong_source_client_test
  axel_pong_settings_test
  realtime_recovery_test
  realtime_delivery_test
  axel_pong_connection_recovery_test
  axel_pong_network_wait_test
  axel_pong_goal_latency_test
  axel_pong_rematch_test
  pong_history_feedback_test
  pong_spectator_test
], mode: "pong", polish: [])
puts 'PASS binary Pong: engine, protocol, channel, audio, clients, durable points and PL/EN UI'
