def _(text)
  text
end

$stdout.sync = true

require "optparse"
require "time"
require_relative "support/tysiac_audit"

options = {
  matches: 12,
  seed: 20_000,
  score_limit: 1_000,
  deep_checks: 80,
  samples: TysiacAudit::INFORMATION_SET_SAMPLES,
  variant: "candidate",
  output: File.expand_path("../reports/tysiac-audit.json", __dir__)
}
OptionParser.new do |parser|
  parser.banner = "Usage: audit-tysiac-bots.rb [options]"
  parser.on("--matches N", Integer) { |value| options[:matches] = value }
  parser.on("--seed N", Integer) { |value| options[:seed] = value }
  parser.on("--score-limit N", Integer) { |value| options[:score_limit] = value }
  parser.on("--deep-checks N", Integer) { |value| options[:deep_checks] = value }
  parser.on("--samples N", Integer) { |value| options[:samples] = value }
  parser.on("--variant NAME", %w[candidate baseline no_barrel samples64 passing leading]) { |value| options[:variant] = value }
  parser.on("--output PATH", String) { |value| options[:output] = File.expand_path(value) }
end.parse!

benchmark = TysiacAudit::Benchmark.new(
  matches: options[:matches],
  seed: options[:seed],
  score_limit: options[:score_limit],
  deep_checks: options[:deep_checks],
  information_set_samples: options[:samples],
  strategy: case options[:variant]
  when "baseline"
    TysiacAudit::LegacyStrategy.new
  when "samples64"
    TysiacAudit::SampleOnlyStrategy.new
  when "no_barrel"
    TysiacAudit::NoBarrelStrategy.new
  when "passing"
    TysiacAudit::PassingOnlyStrategy.new
  when "leading"
    TysiacAudit::LeadingOnlyStrategy.new
  end
)
puts "variant=#{options[:variant]}"
collector = benchmark.run do |index, total, elapsed, result|
  puts "match=#{index}/#{total} seed=#{result.seed} reason=#{result.reason} actions=#{result.actions} seconds=#{elapsed.round(3)}"
end
path = TysiacAudit.write_report(collector, options[:output])
puts JSON.pretty_generate(collector.summary)
puts "report=#{path}"
