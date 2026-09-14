require "json"
require "open3"
require "rbconfig"

root = File.expand_path("..", __dir__)
names = %w[
  connection_recovery connection_recovery_ui synchronization_regressions
  native_live_sessions_store live_sessions_multiplayer live_sessions_resilience
  transport game_sync game_screen_network room_interface game_room_settings_widget
  game_sounds bot_turn_controller
  quiz_party_review_regressions observer_and_shortcut_regressions
  game_event_transport_limit monopoly_trade_compact packaged_rules_encoding
]
results = names.map do |name|
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, "test/#{name}_test.rb", chdir: root)
  puts "#{status.success? ? 'PASS' : 'FAIL'} #{name}"
  warn stdout + stderr unless status.success?
  { name: name, exit_code: status.exitstatus,
    seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3),
    stdout: stdout, stderr: stderr }
end
File.write(ARGV.first, JSON.pretty_generate(results) + "\n", encoding: "UTF-8") if ARGV.first
abort "Connection recovery regressions failed" unless results.all? { |result| result[:exit_code] == 0 }
puts "All #{results.length} targeted recovery tests passed. No live clients or server mutations."
