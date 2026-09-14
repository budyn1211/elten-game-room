# encoding: UTF-8
require "json"
require "time"

english_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
witcher_path = File.expand_path(ARGV.fetch(1), Dir.pwd)

NEGATIVE_PROMPT = /(?:\b(?:which|what|who|where)\b.{0,100}\bnot\b|\bexcept(?: one)?\b|\bnot true\b|\bdoes not belong\b|\bwill you not find\b|\bnever\b|\bincorrect\b|\bfalse\b)/i
NEGATIVE_ANSWER = /\A(?:none|nobody|no one|nothing|neither)(?:\s+of\s+(?:these|the above))?[.!]?\z/i
EXPLICIT_NEGATION = /\b(?:not|never|no|none|neither|incorrect|false|except|without|cannot|can't|isn't|aren't|wasn't|weren't|doesn't|didn't)\b/i
CURRENT_PROMPT = /\b(?:currently|current|today|now|present-day|still in office|as of now)\b/i
MUTABLE_SUBJECT = /\b(?:president|prime minister|leader|office|capital|member|population|record|largest|smallest|highest|lowest|most|least|ranked|ranking)\b/i

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

def overlap_pairs(options)
  values = options.map { |option| normalized(option).split }
  values.each_index.flat_map do |left|
    ((left + 1)...values.length).filter_map do |right|
      a = values[left]
      b = values[right]
      next if a.empty? || b.empty?
      next if options[left].match?(/\d/) && options[right].match?(/\d/)
      shorter, longer = [a, b].sort_by(&:length)
      [left, right] if longer.each_cons(shorter.length).any? { |slice| slice == shorter }
    end
  end
end

def unsafe_overlap?(question, pack_id)
  options = [question.fetch("correct"), *question.fetch("wrong")]
  pairs = overlap_pairs(options).select { |pair| pair.include?(0) }
  return false if pairs.empty?

  title_choices = question.fetch("prompt").match?(
    pack_id == "quiz.witcher.pl" ? /w której .*(?:grze|książ)|w którym .*utworze/i :
      /\b(?:which|what|name).*(?:movie|film|book|novel|song|album|game|show|series|title)\b/i
  )
  return false if title_choices

  true
end

def evidence_text(row)
  Array(row["evidence"]).flat_map do |evidence|
    evidence.is_a?(Hash) ? evidence.values : evidence
  end.flatten.compact.join(" ")
end

def remove(row, reason)
  row.merge(
    "decision" => "remove",
    "reason" => reason,
    "reviewed" => nil,
    "semantic_safety_removal" => true
  )
end

def refine(path, pack_id)
  payload = JSON.parse(File.read(path, encoding: "UTF-8"))
  decisions = payload.fetch("decisions").map do |row|
    next row if row.fetch("decision") == "remove"

    question = row.fetch("reviewed")
    options = [question.fetch("correct"), *question.fetch("wrong")]
    if unsafe_overlap?(question, pack_id)
      remove(row, "answer options overlap semantically or lexically, so the question does not have one unambiguous choice")
    elsif pack_id == "quiz.general.en" && question.fetch("prompt").match?(NEGATIVE_PROMPT) &&
        !evidence_text(row).match?(EXPLICIT_NEGATION)
      remove(row, "the checked source does not explicitly prove the negative or exception asserted by the prompt")
    elsif pack_id == "quiz.general.en" && question.fetch("correct").match?(NEGATIVE_ANSWER) &&
        !evidence_text(row).match?(EXPLICIT_NEGATION)
      remove(row, "the checked source does not explicitly support the negative answer")
    elsif pack_id == "quiz.general.en" && question.fetch("prompt").match?(CURRENT_PROMPT) &&
        question.fetch("prompt").match?(MUTABLE_SUBJECT) && !question.fetch("prompt").match?(/\b(?:19|20)\d{2}\b/)
      remove(row, "the question asks for a mutable current fact without a reference date")
    else
      row
    end
  end
  payload["generated"] = Time.now.utc.iso8601
  payload["semantic_safety"] = {
    "overlapping_options" => true,
    "mixed_value_types" => "reported for manual inspection; not removed automatically because numeric wording varies legitimately",
    "negative_claims_require_explicit_evidence" => pack_id == "quiz.general.en",
    "mutable_current_claims_require_date" => pack_id == "quiz.general.en"
  }
  payload["summary"] = decisions.group_by { |row| row.fetch("decision") }.transform_values(&:length)
  payload["decisions"] = decisions
  File.write(path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
  payload.slice("question_count", "summary", "semantic_safety")
end

puts JSON.pretty_generate(
  "quiz.general.en" => refine(english_path, "quiz.general.en"),
  "quiz.witcher.pl" => refine(witcher_path, "quiz.witcher.pl")
)
