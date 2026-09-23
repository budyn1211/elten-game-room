require_relative 'packaged_rules_encoding_test'
ui_method = FakeControl.instance_method(:update)
BinaryRulesLoad.load(File.join(BinaryRulesLoad::ROOT, 'test/support/ui.rb'))
raise 'Binary loader reloaded an already required test helper' unless FakeControl.instance_method(:update) == ui_method
require_relative 'support/audio_ball_client'

%w[games/audio_ball.rb lib/audio_ball/engine.rb lib/audio_ball/bot.rb lib/audio_ball/audio.rb lib/audio_ball/point_audio.rb lib/audio_ball/client.rb lib/audio_ball/keyboard.rb lib/audio_ball/preferences.rb lib/audio_ball/settings.rb lib/game_surfaces/audio_ball_surface.rb].each do |name|
  path = File.join(BinaryRulesLoad::ROOT, name)
  raise "Audio Ball runtime bypassed binary loading: #{name}" unless BinaryRulesLoad.instance_variable_get(:@loaded)[path]
end
require_relative 'audio_ball_client_test'
require_relative 'audio_ball_relay_test'
require_relative 'audio_ball_warning_recovery_test'
require_relative 'audio_ball_spectator_recovery_test'
require_relative 'audio_ball_settings_client_test'
previous_translation = Object.instance_method(:_)
begin
  Object.send(:define_method, :_) { |text| GameRoomContent.utf8(text) }
  require_relative 'audio_ball_settings_test'
  require_relative 'audio_ball_point_audio_test'
  require_relative 'audio_ball_announcements_test'
ensure
  Object.send(:define_method, :_, previous_translation)
end
require_relative 'audio_ball_defense_input_test'
require_relative 'audio_ball_lane_test'
require_relative 'audio_ball_keyboard_test'
require_relative 'audio_ball_held_engine_test'
require_relative 'audio_ball_flight_test'
require_relative 'audio_ball_client_audio_tick_test'
puts "PASS Audio Ball #{ARGV.first ? 'installer' : 'binary sources'}: actual runtime records, per-flight defense, seven-point matches, recovery and Pong score recordings"
