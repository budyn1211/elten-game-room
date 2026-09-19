# Exercise actual binary sources/package, including the host's no-argument
# Array#shuffle overrides. The imported suites use the loaded real surfaces.
require_relative "tysiac_two_player_ui_test"
require_relative "tysiac_two_player_bot_test"
require_relative "tysiac_two_player_save_test"
require_relative "tysiac_barrel_messages_test"
puts "PASS binary two-player Tysiac: model, bots, saved replay, UI, translations and barrel announcements"
