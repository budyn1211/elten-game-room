require "open3"
require "rbconfig"

root = File.expand_path("..", __dir__)
stdout, stderr, status = Open3.capture3(
  RbConfig.ruby,
  "tools/rebuild-audited-polish-quiz.rb",
  "--check",
  chdir: root
)
raise "Polish quiz audit verification failed:\n#{stdout}#{stderr}" if !status.success?

puts stdout.strip
