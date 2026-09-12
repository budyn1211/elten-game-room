require 'open3'
require 'json'
require 'rbconfig'

# Focused rules/decision regression suite; no network, clients, packaging or
# hundreds-of-matches learning arena. Each file has an isolated Ruby process.
root=File.expand_path('..',__dir__)
tests=%w[
  audit_212_rules_and_decisions_test audit_212_strategy_features_test
  audit_212_search_test audit_212_information_test audit_212_spades_decisions_test
  audit_212_tic_exhaustive_test tic_tac_toe_test four_in_a_row_test
  new_board_games_test checkers_bot_optimization_test
  farkle_test ninety_nine_test categories_test tysiac_test tysiac_audit_test
  spades_test spades_planner_test spades_table_533_regression_test
  strategic_bots_test new_games_116_test five_games_regression_test
  five_games_followup_test five_games_207_feedback_test five_games_ui_test
  monopoly_regional_test new_games_complete_match_test
  monopoly_uno_poker_208_feedback_test monopoly_management_ui_test
  monopoly_poker_bot_208_feedback_test uno_interceptions_test
  monopoly_property_messages_test game_messages_after_211_test
  game_messages_ui_test game_messages_translation_test
  monopoly_auction_and_bankruptcy_test game_rules_test game_rules_ui_test
  game_rules_translation_test packaged_rules_encoding_test
]
results=[]
tests.each do |name|
  start=Process.clock_gettime(Process::CLOCK_MONOTONIC)
  output,status=Open3.capture2e({'GAME_ROOM_FIVE_GAMES_ONLY'=>'1'},RbConfig.ruby,"test/#{name}.rb",chdir:root)
  seconds=Process.clock_gettime(Process::CLOCK_MONOTONIC)-start
  results << {test:name,passed:status.success?,seconds:seconds.round(3),output:output}
  puts "#{status.success? ? 'PASS' : 'FAIL'} #{name} (#{seconds.round(2)} s)"
  puts output unless status.success?
  STDOUT.flush
end
output,status=Open3.capture2e(RbConfig.ruby,'tools/check-five-game-translations.rb',chdir:root)
results << {test:'check-five-game-translations',passed:status.success?,output:output}
path=ARGV.first
File.write(File.expand_path(path),JSON.pretty_generate(results)) if path
failures=results.reject { |result| result[:passed] }
abort "#{failures.length} failed: #{failures.map { |r| r[:test] }.join(', ')}" unless failures.empty?
puts "All #{results.length} focused rule/decision/UI/translation checks passed. No client/network test was run."
