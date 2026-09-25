require_relative "support/binary_suite"

# Every original scenario retains its assertions and binary runtime boundary,
# with fresh fixture/global state and the common timeout/skip reporting.
BinaryTestSuite.run(%w[
  tysiac_two_player_ui_test
  tysiac_two_player_bot_test
  tysiac_two_player_save_test
  tysiac_barrel_messages_test
], mode: "dictionary", polish: [])
puts "PASS binary two-player Tysiac: model, bots, saved replay, UI, translations and barrel announcements"
