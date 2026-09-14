# encoding: UTF-8
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_general_en_data")
require File.join(root, "content", "quiz_witcher_pl_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)

NEGATIVE_PROMPT = /\b(?:not|never|incorrect|false|except|isn't|aren't|doesn't|didn't|cannot|can't|wasn't|weren't)\b/i
CURRENT_PROMPT = /\b(?:currently|current|today|now|present-day|still in office|as of now)\b/i
GENERIC_ANSWER = /\A(?:all|both|none|neither)(?:\s+(?:of\s+)?(?:these|them|the\s+above|the\s+answers))?[.!]?\z/i

def normalized(value)
  value.to_s.unicode_normalize(:nfkc).downcase.gsub(/[^\p{L}\p{N}%]+/u, " ").gsub(/\s+/, " ").strip
end

def answer_shape(value)
  text = normalized(value)
  return :boolean if %w[true false yes no].include?(text)
  return :year if text.match?(/\A(?:bc |ad )?\d{3,4}(?: bc| ad)?\z/)
  return :number if text.match?(/\A[-+]?\d+(?:[.,]\d+)?(?: ?%)?\z/)
  return :range if text.match?(/\A[-+]?\d+(?:[.,]\d+)?\s*[-–]\s*[-+]?\d+(?:[.,]\d+)?\z/)
  :text
end

def overlapping_options(options)
  token_options = options.map { |option| normalized(option).split }
  token_options.each_index.flat_map do |left|
    ((left + 1)...token_options.length).filter_map do |right|
      a = token_options[left]
      b = token_options[right]
      next if a.empty? || b.empty? || a == b
      shorter, longer = [a, b].sort_by(&:length)
      contains = longer.each_cons(shorter.length).any? { |slice| slice == shorter }
      next unless contains
      [left, right]
    end
  end
end

packs = {
  "quiz.general.en" => GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions"),
  "quiz.witcher.pl" => GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
}

findings = packs.flat_map do |pack_id, questions|
  questions.flat_map do |question|
    options = [question.fetch("correct"), *question.fetch("wrong")]
    shapes = options.map { |option| answer_shape(option) }
    rows = []
    rows << "negative_or_exception_prompt" if pack_id == "quiz.general.en" && question.fetch("prompt").match?(NEGATIVE_PROMPT)
    rows << "temporally_unstable_prompt" if pack_id == "quiz.general.en" && question.fetch("prompt").match?(CURRENT_PROMPT)
    rows << "generic_combined_answer" if question.fetch("correct").match?(GENERIC_ANSWER)
    rows << "answer_shape_mismatch" if shapes.uniq.length > 1 && shapes.any? { |shape| shape != :text }
    overlap = overlapping_options(options)
    rows << "overlapping_answer_options" unless overlap.empty?
    rows.map do |kind|
      {
        "pack_id" => pack_id,
        "id" => question.fetch("id"),
        "kind" => kind,
        "prompt" => question.fetch("prompt"),
        "correct" => question.fetch("correct"),
        "wrong" => question.fetch("wrong"),
        "answer_shapes" => shapes.map(&:to_s),
        "overlap_pairs" => overlap
      }
    end
  end
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "question_count" => packs.values.sum(&:length),
  "finding_count" => findings.length,
  "summary" => findings.group_by { |row| [row.fetch("pack_id"), row.fetch("kind")] }
    .transform_keys { |key| key.join(":") }.transform_values(&:length),
  "findings" => findings
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "finding_count", "summary"))
