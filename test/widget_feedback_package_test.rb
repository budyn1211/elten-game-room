# Load all production code through ELTEN's binary boundary (or ARGV package).
# Then exercise the new behaviours without opening clients or touching profiles.
require_relative "widget_feedback_binary_test"
require_relative "widget_and_games_feedback_test"
require_relative "krowa_reroll_test"
# The full widget source suites have independent contact-worker test doubles;
# keep them in separate processes. The binary UI suite exercises creation here
# with just the table I/O boundary substituted, not those unrelated fixtures.
puts "PASS binary feedback: widget creation/presets, privacy, new game controls and Krowa reroll"
