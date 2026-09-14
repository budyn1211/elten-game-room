# encoding: UTF-8
require "json"
require "time"

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
payload = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
accepted = %w[verified_candidate verified_full_wikipedia]
decisions = payload.fetch("decisions").reject { |row| accepted.include?(row.fetch("status")) }

File.write(
  output_path,
  JSON.pretty_generate(
    "generated" => Time.now.utc.iso8601,
    "source" => analysis_path,
    "question_count" => decisions.length,
    "statuses" => decisions.map { |row| row.fetch("status") }.tally,
    "decisions" => decisions.map { |row| { "id" => row.fetch("id"), "status" => row.fetch("status") } }
  ) + "\n",
  encoding: "UTF-8"
)
puts output_path
