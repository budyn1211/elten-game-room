# encoding: UTF-8
require "json"
require "time"

source_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)

CONTRACTIONS = {
  "aint" => "ain't", "arent" => "aren't", "cant" => "can't",
  "couldnt" => "couldn't", "didnt" => "didn't", "doesnt" => "doesn't",
  "dont" => "don't", "hasnt" => "hasn't", "havent" => "haven't",
  "isnt" => "isn't", "shouldnt" => "shouldn't", "wasnt" => "wasn't",
  "werent" => "weren't", "wont" => "won't", "wouldnt" => "wouldn't",
  "youll" => "you'll", "youre" => "you're", "youve" => "you've"
}.freeze

def repair_contractions(text)
  output = text.to_s.dup
  CONTRACTIONS.each do |plain, corrected|
    output.gsub!(/\b#{Regexp.escape(plain)}\b/i) do |found|
      if found == found.upcase
        corrected.upcase
      elsif found[0] == found[0].upcase
        corrected.sub(/\A./, corrected[0].upcase)
      else
        corrected
      end
    end
  end
  output
end

def repair_question(question)
  output = question.dup
  output["prompt"] = repair_contractions(question.fetch("prompt"))
  output["correct"] = repair_contractions(question.fetch("correct"))
  output["wrong"] = question.fetch("wrong").map { |answer| repair_contractions(answer) }
  output
end

source = JSON.parse(File.read(source_path, encoding: "UTF-8"))
decisions = source.fetch("decisions").select { |row| row.fetch("pack_id") == "quiz.general.en" }.map do |row|
  output = row.reject { |key, _value| key == "pack_id" }
  next output if output.fetch("decision") == "remove"

  repaired = repair_question(output.fetch("reviewed"))
  if repaired != output.fetch("reviewed")
    output["reviewed"] = repaired
    output["decision"] = "correct"
    output["reason"] = "language, wording, or the answer was corrected from checked source evidence"
  end
  output
end

raise "the combined report does not contain all English decisions" unless decisions.length == 28_575

payload = {
  "generated" => Time.now.utc.iso8601,
  "scope" => "English general quiz factual and language audit",
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("decision") }.transform_values(&:length),
  "source_statuses" => decisions.group_by { |row| row.fetch("source_status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary", "source_statuses"))
