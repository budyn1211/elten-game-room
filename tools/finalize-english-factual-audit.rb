# encoding: UTF-8
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_general_en_data")

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
local_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(2), Dir.pwd)

analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
analysis_by_id = analysis.fetch("decisions").to_h { |row| [row.fetch("id"), row] }
local = JSON.parse(File.read(local_path, encoding: "UTF-8"))
local_findings = local.fetch("packs").fetch("quiz.general.en").fetch("findings")
findings_by_id = local_findings.group_by { |row| row.fetch("id") }
questions = GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions")

FORCED_REMOVALS = {
  "1c82ba98ada3" => "the prompt does not identify the work whose composer is requested",
  "3987136d5c27" => "the prompt does not identify the song",
  "eeee19350368" => "the prompt does not identify the work whose composer is requested",
  "2009881c24e2" => "duplicate of the retained Robert Frost question",
  "5de4f74ee822" => "the undated statistical claim about wolf deaths is unstable",
  "aef0d1cf93d0" => "the undated estimate of spoken languages is unstable",
  "b206c1be8e57" => "the undated estimate of written languages is unstable"
}.freeze

PROMPT_CORRECTIONS = {
  "f86cb6a7f060" => "What is the natural habitat of the smallest bird on the planet, the Bee Hummingbird?",
  "fbf3fb51d02e" => "The plot of the famous Broadway musical West Side Story is based on which source?",
  "05e891b29c57" => "Nike launched its \"Just Do It\" campaign in what year?",
  "1e66b22cf6b6" => "What scale measures sexual orientation from 0 (exclusively heterosexual) to 6 (exclusively homosexual)?",
  "4723fdd1c74c" => "Arthur's Theme (Best That You Can Do) was a U.S. number-one hit for which singer in 1981?",
  "5350fe817791" => "(Sittin' On) The Dock of the Bay was a posthumous U.S. number-one hit for which singer in 1968?",
  "1cd5a76834b8" => "What was Stalingrad renamed in 1961?",
  "7b2fdd445d48" => "As of 2026, how many living elephant species are recognized?",
  "ce85a060e44d" => "Which two founding NFL clubs survived into the 21st century, and what were their original names?",
  "ec1a094f2d54" => "What is the present-day name of the first college established in the Bronx in 1884?",
  "f37cbc3149dc" => "As of 2026, Belgrade is the capital of which country?",
  "1445f1734473" => "As of 2026, which country has never been a member of the Commonwealth of Nations?",
  "ab073991c3c7" => "Which city hosted the 1968 Olympics, where high altitude and rarefied air contributed to many track-and-field records?",
  "a42dcdf7b954" => "How many items are in a baker's dozen?",
  "63b8f0800c36" => "How many people were at the dinner table before Professor Trelawney joined them?",
  "222d1297cb50" => "How many individual muscles are in an elephant's trunk?",
  "296f7005980d" => "How many pleats are on a traditional chef's hat (the Grand Toque)?",
  "f0e3c57e7328" => "In how many countries was the Hägar the Horrible comic strip distributed?",
  "4a66c3d67042" => "Shortly after its creation, to how many newspapers worldwide was the Hägar the Horrible comic strip distributed?",
  "42a94a718aa6" => "On the morning of Elvis's funeral, how many vans were needed to move the flowers from Graceland to the cemetery?",
  "44ede9aee63f" => "What was Lenny Bruce's salary for his first comedy job?",
  "acea8b13534a" => "What is the body length of an average mature sloth from head to tail?",
  "d7820250b783" => "What unique feature do the fingers of the koala possess?",
  "141296319ae2" => "What characters did John Wayne portray in the movies In Harm's Way, The Wings of Eagles and Hatari!?",
  "de150de478a7" => "What piece of furniture did Frank Welker play in the Oscar-nominated Disney film Beauty and the Beast?",
  "4edffcda42f3" => "Which of these is a rational fear according to the book The Wide Window by Lemony Snicket?",
  "5be413ead4b2" => "What was written on the girl's bathroom mirror according to the popular urban legend The Licked Hand?",
  "da7d57908567" => "Which ancient language is often referred to as the mother of all languages?",
  "2140bbce6785" => "Which brand of paper is called the Quilted Quicker Picker-Upper?",
  "b76e0e026806" => "Which of the following is the odd one?",
  "6fbd5dfda357" => "Which of these is the odd one?",
  "5532c56d3ee1" => "What is the Rio Grande called in Mexico?",
  "d755e8484ef0" => "Which of the following is not a step in brewing beer?",
  "de4e6dbb5095" => "Which novel, set during the Great Depression, won the Pulitzer Prize in 1940?",
  "bffe139a0dd3" => "In the movie Constantine, why does Constantine use a cat while transporting himself to Hell?",
  "9752cb739819" => "In The Fellowship of the Ring movie, what is the name of Sam's crush?",
  "61de3f6a359f" => "Which actor starred as Che in the 1996 movie Evita?",
  "c8f496c0e614" => "Which famous supermodel did Leonardo DiCaprio date from 2001 to 2005?",
  "2befb7aae9d5" => "When did the war drama The Longest Day come out?",
  "95c89e782b49" => "Who turned down the role of Shug Avery in the movie The Color Purple?",
  "a8fed2948f99" => "In the Cats logo, what can be seen in each pupil of the cat's eyes?",
  "21adaf165650" => "Which of these is a 2006 hit from Jesse McCartney's second album?",
  "429aaf87270c" => "In 1931, the province of Hunan, China, banned which book?"
}.freeze

ANSWER_CORRECTIONS = {
  "fbf3fb51d02e" => "Shakespeare's Romeo and Juliet",
  "429aaf87270c" => "Alice's Adventures in Wonderland"
}.freeze

MANUAL_FACT_CORRECTIONS = {
  "9aced15b2ee4" => {
    "prompt" => "Approximately how many years ago did non-avian dinosaurs become extinct?",
    "correct" => "66 million",
    "evidence" => [{
      "title" => "Cretaceous–Paleogene extinction event",
      "url" => "https://en.wikipedia.org/?curid=44503418",
      "excerpt" => "The event occurred around 66 million years ago and caused the extinction of all non-avian dinosaurs."
    }]
  }
}.freeze

CONTRACTIONS = {
  "aint" => "ain't", "arent" => "aren't", "cant" => "can't",
  "couldnt" => "couldn't", "didnt" => "didn't", "doesnt" => "doesn't",
  "dont" => "don't", "hasnt" => "hasn't", "havent" => "haven't",
  "isnt" => "isn't", "shouldnt" => "shouldn't", "wasnt" => "wasn't",
  "werent" => "weren't", "wont" => "won't", "wouldnt" => "wouldn't",
  "youll" => "you'll", "youre" => "you're", "youve" => "you've"
}.freeze

EXPANDED_GENERIC = /\A(?:all|both|none|neither)(?:\s+(?:of\s+)?(?:these|them|the\s+above|the\s+answers|three\s+answers))?[.!]?\z/i

def repair_contractions(text)
  output = text.to_s.dup
  CONTRACTIONS.each do |plain, corrected|
    output.gsub!(/\b#{Regexp.escape(plain)}\b/i) do |found|
      found == found.upcase ? corrected.upcase : (found[0] == found[0].upcase ? corrected.sub(/\A./, corrected[0].upcase) : corrected)
    end
  end
  output
end

def corrected_question(question, prompt, answer, repair_contraction: false)
  output = question.dup
  output["prompt"] = prompt || question.fetch("prompt")
  if repair_contraction
    output["prompt"] = repair_contractions(output.fetch("prompt"))
    output["correct"] = repair_contractions(question.fetch("correct"))
    output["wrong"] = question.fetch("wrong").map { |candidate| repair_contractions(candidate) }
  end
  return output unless answer && !answer.casecmp?(output.fetch("correct"))

  old_correct = output.fetch("correct")
  wrong = output.fetch("wrong").dup
  replacement_index = wrong.index { |candidate| candidate.casecmp?(answer) }
  wrong[replacement_index] = old_correct if replacement_index
  wrong = wrong.reject { |candidate| candidate.casecmp?(answer) }.uniq
  output["correct"] = answer
  output["wrong"] = wrong.first(3)
  output
end

def evidence_for(row)
  direct = Array(row["evidence"]) + Array(row["full_wikipedia_evidence"])
  checks = Array(row["checks"]).flat_map do |check|
    Array(check["evidence"]) + Array(check["full_wikipedia_evidence"])
  end
  (direct + checks).uniq
end

decisions = questions.map do |question|
  id = question.fetch("id")
  row = analysis_by_id.fetch(id)
  manual_correction = MANUAL_FACT_CORRECTIONS[id]
  findings = findings_by_id.fetch(id, [])
  forced_removal = FORCED_REMOVALS[id]
  missing_media = findings.any? { |finding| finding.fetch("type") == "missing_required_media" }
  expanded_generic = question.fetch("correct").match?(EXPANDED_GENERIC) && row.fetch("status") != "verified_candidate"
  supported = ["verified_candidate", "verified_full_wikipedia"].include?(row.fetch("status")) || manual_correction
  remove_reason = if forced_removal
    forced_removal
  elsif missing_media
    "the question requires sound or an image that is not included in the quiz"
  elsif expanded_generic
    "the combined all/both/none answer was not verified option by option"
  elsif !supported
    "the stated correct answer could not be confirmed in the checked sources"
  end

  if remove_reason
    {
      "id" => id,
      "decision" => "remove",
      "reason" => remove_reason,
      "source_status" => row.fetch("status"),
      "original" => question,
      "reviewed" => nil,
      "evidence" => evidence_for(row)
    }
  else
    reviewed = corrected_question(
      question,
      manual_correction&.fetch("prompt", nil) || PROMPT_CORRECTIONS[id],
      manual_correction&.fetch("correct", nil) || ANSWER_CORRECTIONS[id],
      # Apply the safe closed contraction map to the complete retained record,
      # including distractors; the local language scan originally reported
      # only prompt findings.
      repair_contraction: true
    )
    changed = reviewed != question
    {
      "id" => id,
      "decision" => changed ? "correct" : "keep",
      "reason" => changed ? "language, wording, or the answer was corrected from checked source evidence" : "the answer is supported by the checked source",
      "source_status" => row.fetch("status"),
      "original" => question,
      "reviewed" => reviewed,
      "evidence" => evidence_for(row) + Array(manual_correction&.fetch("evidence", nil))
    }
  end
end

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
