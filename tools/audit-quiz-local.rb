# encoding: UTF-8
require "json"
require "fileutils"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_general_en_data")
require File.join(root, "content", "quiz_pl_wikidata_data")
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)

packs = {
  "quiz.general.en" => GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions"),
  "quiz.wikidata.pl" => GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions"),
  "quiz.witcher.pl" => GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
}

witcher_prompts = GameRoomContent::WitcherPolishMediumData.load.fetch("prompts")

ENGLISH_MISSING_APOSTROPHE = /\b(?:aint|arent|cant|couldnt|didnt|doesnt|dont|hasnt|havent|isnt|shouldnt|wasnt|werent|wont|wouldnt|youll|youre|youve)\b/i
# Historical wording such as "in this year" or "the head coach who preceded"
# is stable. Flag only wording whose answer can change as time passes.
ENGLISH_TEMPORAL = /\b(?:currently|today|presently|latest|current world record|current record holder|current head coach|current president|current prime minister|current ceo)\b/i
POLISH_TEMPORAL = /\b(?:obecnie|aktualnie|teraz)\b|— (?:jaki klub prowadzi|w jakim klubie (?:gra|trenuje)|jaki kraj reprezentuje)\?/i
DEPENDENT = /\b(?:previous|preceding|above|earlier) question\b|\bpoprzedni(?:e|ego|m)? pytani/i
SOURCE_ARTIFACT = /\{\{|\}\}|\|serial\)|\A\([^)]*serial[^)]*—/i
MISSING_MEDIA = /\b(?:sound clip|audio clip|listen to the audio|song (?:featured|heard) in the (?:sound|audio) clip|pictured (?:here|above|below)|shown (?:here|above|below)|this (?:picture|image|photograph))\b/i
CONTEXTLESS_PROMPT = /\A(?:name|identify) (?:the )?(?:composer|artist|performer|person|actor|actress|song|film|movie|animal|object|place|country|city)\.?\z/i

def normalized(text)
  text.to_s.unicode_normalize(:nfkc).downcase.gsub(/[[:punct:]\s]+/, " ").strip
end

def normalized_answer(text)
  text.to_s.unicode_normalize(:nfkc).downcase.gsub(/\s+/, " ").strip
end

def issue(type, question, detail = nil)
  row = {
    "type" => type,
    "id" => question.fetch("id"),
    "prompt" => question.fetch("prompt"),
    "correct" => question.fetch("correct")
  }
  row["detail"] = detail if detail
  row
end

results = {}
packs.each do |pack_id, questions|
  ids = Hash.new { |hash, key| hash[key] = [] }
  prompts = Hash.new { |hash, key| hash[key] = [] }
  findings = []

  questions.each do |source_question|
    question = source_question
    if pack_id == "quiz.witcher.pl" && witcher_prompts.key?(question.fetch("id"))
      question = question.merge("prompt" => witcher_prompts.fetch(question.fetch("id")))
    end
    id = question.fetch("id")
    prompt = question.fetch("prompt").to_s
    correct = question.fetch("correct").to_s
    wrong = Array(question["wrong"]).map(&:to_s)
    ids[id] << question
    prompts[normalized(prompt)] << question

    findings << issue("invalid_id", question) if id !~ /\A[0-9a-f]{12}\z/
    findings << issue("empty_prompt", question) if prompt.strip.empty?
    findings << issue("empty_correct", question) if correct.strip.empty?
    findings << issue("wrong_answer_count", question, wrong.length) if wrong.length != 3
    options = [correct] + wrong
    normalized_options = options.map { |answer| normalized_answer(answer) }
    if normalized_options.uniq.length != normalized_options.length
      findings << issue("duplicate_answer", question, options)
    end
    if prompt.count("[") != prompt.count("]") || prompt.count("(") != prompt.count(")")
      findings << issue("unbalanced_delimiter", question)
    end
    findings << issue("source_markup", question) if SOURCE_ARTIFACT.match?(prompt) || SOURCE_ARTIFACT.match?(correct)
    findings << issue("dependent_question", question) if DEPENDENT.match?(prompt)
    findings << issue("missing_required_media", question) if MISSING_MEDIA.match?(prompt)
    findings << issue("contextless_prompt", question) if CONTEXTLESS_PROMPT.match?(prompt)

    if pack_id == "quiz.general.en"
      findings << issue("english_missing_apostrophe", question) if ENGLISH_MISSING_APOSTROPHE.match?(prompt)
      findings << issue("temporally_unstable", question) if ENGLISH_TEMPORAL.match?(prompt)
      findings << issue("english_known_typo", question, "Brodway -> Broadway") if prompt.match?(/\bBrodway\b/i)
      findings << issue("english_known_grammar", question, "Where is its natural habitat of -> What is the natural habitat of") if prompt.match?(/\AWhere is its natural habitat of\b/i)
    else
      findings << issue("temporally_unstable", question) if POLISH_TEMPORAL.match?(prompt)
      findings << issue("polish_known_typo", question, "wznieśiono -> wzniesiono") if prompt.include?("wznieśiono")
      findings << issue("polish_awkward_template", question, "obywatelstwo phrased as a current attribute") if prompt.match?(/— jakie (?:ma obywatelstwo|obywatelstwo ma ta osoba)\?\z/i)
    end
  end

  ids.each_value do |rows|
    rows.each { |question| findings << issue("duplicate_id", question, rows.length) } if rows.length > 1
  end
  prompts.each_value do |rows|
    rows.each { |question| findings << issue("duplicate_prompt", question, rows.map { |row| row.fetch("id") }) } if rows.length > 1
  end

  results[pack_id] = {
    "question_count" => questions.length,
    "finding_count" => findings.length,
    "by_type" => findings.map { |row| row.fetch("type") }.tally.sort.to_h,
    "findings" => findings.sort_by { |row| [row.fetch("type"), row.fetch("id")] }
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "scope" => "local structural, temporal-stability and deterministic language checks; factual evidence is handled separately",
  "packs" => results
}
FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(results.transform_values { |row| row.reject { |key, _| key == "findings" } })
