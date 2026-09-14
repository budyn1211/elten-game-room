# encoding: UTF-8
require "json"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_general_en_data")

path = File.expand_path(ARGV.fetch(0), Dir.pwd)
offset = Integer(ARGV[1] || 0)
limit = Integer(ARGV[2] || 5)
payload = JSON.parse(File.read(path, encoding: "UTF-8"))
questions = GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions")
by_id = questions.to_h { |question| [question.fetch("id"), question] }

payload.fetch("completed_ids").slice(offset, limit).to_a.each do |id|
  question = by_id.fetch(id)
  search = payload.fetch("searches").fetch(id)
  puts id
  puts question.fetch("prompt")
  puts "CORRECT: #{question.fetch('correct')}"
  puts "QUERY: #{search.fetch('query')}"
  search.fetch("results").first(3).each do |result|
    puts "- #{result.fetch('title')}: #{result.fetch('snippet')}"
  end
  puts "---"
end
