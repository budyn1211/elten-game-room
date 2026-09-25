require "open3"
require "rbconfig"

def assert(value, message); raise message unless value; end
root = File.expand_path("..", __dir__)
imports = Dir.glob(File.join(root, "test/**/*.rb")).flat_map do |path|
  File.readlines(path).each_with_index.filter_map do |line, index|
    "#{path}:#{index + 1}" if line.match?(/\b(?:require_relative|require|load)\s*[(]?\s*["'][^"']*_test(?:\.rb)?["']/)
  end
end
assert(imports.empty?, "A test still imports another scenario: #{imports.join(', ')}")
%w[audio_ball_point_audio axel_pong_doubles_lobby audio_tutorial_native table_lifecycle_controls_2 no_bot_table_control post_233_ping table_notice_presentation game_option_encoding].each do |name|
  helper = File.join(root, "test/support/#{name}.rb")
  output, status = Open3.capture2e(RbConfig.ruby, "-r", helper, "-e", 'puts "fixture loaded"')
  assert(status.success? && output.lines.last.to_s.strip == "fixture loaded", "#{name}: fixture failed: #{output}")
  assert(!output.match?(/^(?:PASS|FAIL|All |passed:|\[\d+\/)/), "#{name}: import ran another scenario: #{output}")
end
puts "PASS fixture boundaries: no test imports, native/point/lifecycle/ping/notification helpers load without scenarios"
