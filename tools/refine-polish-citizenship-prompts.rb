# encoding: UTF-8
require "json"
require "time"

path = File.expand_path(ARGV.fetch(0), Dir.pwd)
payload = JSON.parse(File.read(path, encoding: "UTF-8"))
changed = []

payload.fetch("decisions").each do |row|
  next if row.fetch("decision") == "remove"

  reviewed = row.fetch("reviewed")
  prompt = reviewed.fetch("prompt")
  match = prompt.match(/\A(.+?) — jakie ma(?: lub miała)? obywatelstwo\?\z/i)
  next unless match

  subject = match[1].strip
  reviewed["prompt"] = "Jakie obywatelstwo przypisano osobie #{subject}?"
  row["decision"] = "correct"
  row["reason"] = "verified wording was made natural and time-neutral without changing the fact"
  changed << row.fetch("id")
end

payload["generated"] = Time.now.utc.iso8601
payload["summary"] = payload.fetch("decisions").group_by { |row| row.fetch("decision") }.transform_values(&:length)
payload["citizenship_prompt_corrections"] = changed.length
File.write(path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary", "citizenship_prompt_corrections"))
