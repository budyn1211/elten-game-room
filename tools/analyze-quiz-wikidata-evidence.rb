# encoding: UTF-8
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

input_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
evidence = JSON.parse(File.read(input_path, encoding: "UTF-8"))
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")
matches = evidence.fetch("matches")
separator = " #{[0x2014].pack("U")} "

# Do not rely only on majority inference for small or exceptional templates.
# These prompts were generated from known Wikidata relations and some of them
# have too few surviving rows for inference to discover the property.
EXPLICIT_PROPERTIES = {
  "w jakim państwie leży?" => %w[P17],
  "w jakim państwie płynie?" => %w[P17],
  "w jakim województwie leży to miasto?" => %w[P131],
  "do jakiego pasma górskiego należy?" => %w[P4552],
  "na jakim kontynencie się znajduje?" => %w[P30],
  "do jakiej rzeki wpada?" => %w[P403],
  "do jakiego morza wpada?" => %w[P403],
  "najwyższy punkt jakiego państwa?" => %w[P17 P131],
  "jaki szczyt jest najwyższym punktem tego regionu?" => %w[P17 P131],
  "kto wygrał klasyfikację?" => %w[P1346],
  "która reprezentacja zwyciężyła?" => %w[P1346],
  "w którym roku urodziła się ta postać?" => %w[P569],
  "w którym roku się urodził?" => %w[P569],
  "w którym roku zmarł ten papież?" => %w[P570],
  "w którym roku ją wzniesiono?" => %w[P571],
  "w którym roku go zbudowano?" => %w[P571],
  "w którym roku założono tę uczelnię?" => %w[P571],
  "w którym roku założono to miasto?" => %w[P571],
  "w którym roku powstał ten dokument?" => %w[P571],
  "w którym roku to państwo powstało?" => %w[P571],
  "w którym roku to państwo upadło?" => %w[P576],
  "w którym roku ją stoczono?" => %w[P585 P580],
  "w którym roku stoczono tę bitwę?" => %w[P585 P580],
  "w którym roku do niego doszło?" => %w[P585 P580],
  "w którym roku tego dokonano?" => %w[P585 P571],
  "w którym roku wybuchło?" => %w[P580 P585],
  "w którym roku ta wojna wybuchła?" => %w[P580],
  "w którym roku ta wojna się skończyła?" => %w[P582],
  "w którym roku go zawarto?" => %w[P585 P580],
  "częścią jakiego konfliktu była ta bitwa?" => %w[P361]
}.freeze

def suffix_for(question, separator)
  question.fetch("prompt").split(separator, 2)[1].to_s.strip
end

patterns = questions.group_by { |question| suffix_for(question, separator) }.map do |suffix, rows|
  property_questions = Hash.new { |hash, key| hash[key] = {} }
  rows.each do |question|
    Array(matches[question.fetch("id")]).each do |match|
      property_questions[match.fetch("property")][question.fetch("id")] = true
    end
  end
  counts = property_questions.transform_values(&:length).sort_by { |property, count| [-count, property] }
  matched_questions = rows.count { |question| !Array(matches[question.fetch("id")]).empty? }
  top_count = counts.empty? ? 0 : counts.first[1]
  inferred = if top_count >= 2
    counts.select { |_property, count| count >= [2, (top_count * 0.25).ceil].max }
      .map(&:first)
  elsif top_count == 1 && rows.length <= 5
    [counts.first[0]]
  else
    []
  end
  expected = (Array(EXPLICIT_PROPERTIES[suffix]) + inferred).uniq
  {
    "suffix" => suffix,
    "question_count" => rows.length,
    "matched_question_count" => matched_questions,
    "expected_properties" => expected,
    "property_counts" => counts.to_h,
    "top_property_share_of_matched" => matched_questions.zero? ? 0.0 : (top_count.to_f / matched_questions).round(4)
  }
end.sort_by { |row| [-row.fetch("question_count"), row.fetch("suffix")] }

patterns_by_suffix = patterns.to_h { |row| [row.fetch("suffix"), row] }
decisions = questions.map do |question|
  id = question.fetch("id")
  suffix = suffix_for(question, separator)
  expected = patterns_by_suffix.fetch(suffix).fetch("expected_properties")
  rows = Array(matches[id])
  relevant = rows.select { |row| expected.include?(row.fetch("property")) }
  sourced = relevant.select { |row| row.fetch("reference_count", 0).to_i.positive? }
  status = if expected.empty?
    "unmapped_pattern"
  elsif !sourced.empty?
    "verified_referenced_claim"
  elsif !relevant.empty?
    "unreferenced_claim"
  elsif !rows.empty?
    "answer_matches_other_property"
  else
    "answer_not_found"
  end
  {
    "id" => id,
    "status" => status,
    "prompt" => question.fetch("prompt"),
    "correct" => question.fetch("correct"),
    "expected_properties" => expected,
    "evidence" => relevant,
    "other_matches" => rows.reject { |row| relevant.include?(row) }
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "input" => input_path,
  "question_count" => questions.length,
  "completed_label_count" => Array(evidence["completed_labels"]).length,
  "completed_subject_item_count" => Array(evidence["completed_subject_items"]).length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "patterns" => patterns,
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice(
  "question_count", "completed_label_count", "completed_subject_item_count", "summary"
))
