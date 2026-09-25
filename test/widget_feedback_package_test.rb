require_relative "support/binary_suite"

# Every original scenario retains its assertions and binary runtime boundary,
# with fresh fixture/global state and the common timeout/skip reporting.
BinaryTestSuite.run(%w[
  widget_feedback_binary_test
  widget_and_games_feedback_test
  krowa_reroll_test
], mode: "dictionary", polish: ["widget_feedback_binary_test"])
puts "PASS binary feedback: widget creation/presets, privacy, new game controls and Krowa reroll"
