# encoding: UTF-8
require "cgi"
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
medium_audit_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
profession_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
relation_path = File.expand_path(ARGV.fetch(3), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(4), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(5), Dir.pwd)

questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
medium_data = GameRoomContent::WitcherPolishMediumData.load
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
analysis_by_id = analysis.fetch("decisions").to_h { |row| [row.fetch("id"), row] }
old_medium = JSON.parse(File.read(medium_audit_path, encoding: "UTF-8")).fetch("questions")
  .to_h { |row| [row.fetch("id"), row] }
professions = JSON.parse(File.read(profession_path, encoding: "UTF-8")).fetch("questions")
  .to_h { |row| [row.fetch("id"), row] }
relations = JSON.parse(File.read(relation_path, encoding: "UTF-8")).fetch("decisions")
  .to_h { |row| [row.fetch("id"), row] }
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")

# These replacements are limited to values stated directly in the cited
# infobox relation. Two homonymous subjects and one non-occupation are removed
# instead of being guessed.
ANSWER_CORRECTIONS = {
  "085c49e4b888" => "Rience",
  "9c7b8388f64e" => "Shiadhal",
  "e98370a085cf" => "Auberon Muircetach",
  "a39c0a19a939" => "Carezza Charbonneau",
  "2de700bee2d2" => "Radowid V Srogi",
  "f7b346b40353" => "Hedwig z Malleore",
  "1d7b60b0c608" => "Vizimir II Sprawiedliwy",
  "fe543f4d1536" => "Dalimira z Redanii",
  "75385d5ee320" => "Rochelle Rose",
  "24fc3ba2b640" => "Mahesh Jadu",
  "70fe93aef9bb" => "zwierzchnik Flotsam",
  "68c376fd5937" => "palatyn",
  "eccc2121758a" => "kupiec",
  "f655a42c4cdf" => "łowca głów",
  "9e4e851dbbea" => "oficer wywiadu",
  "7a1d1ceeb74c" => "łowca czarownic",
  "c14b3f114496" => "wielki inkwizytor kultu Wiecznego Ognia",
  "9d51fa0f6182" => "prostytutka",
  "2de09c92389a" => "płatny morderca",
  "79e702b63bb4" => "strażnik miejski",
  "17318dc44e14" => "łowca czarownic",
  "297bcf1c019d" => "żołnierz",
  "d979ec19f72e" => "szpieg",
  "c8f5ac964a4e" => "łowca czarownic",
  "70844a08f91d" => "adwokat",
  "5320e459aae5" => "herszt hanzy",
  "3b153e624b96" => "łowca magów",
  "35ddff833de5" => "wykładowca teologii w Akademii Oxenfurckiej",
  "a906c0806313" => "profesor astronomii w Akademii Oxenfurckiej",
  "b6a7026211a5" => "ochroniarz Pyrala Pratta",
  "ef1b97a6418b" => "myśliwy",
  "58e7a4cd85c0" => "prostytutka",
  "18525d90069e" => "prostytutka",
  "4c8c329fd55b" => "prostytutka",
  "69cc852c5daa" => "łowca czarownic",
  "916c21aad2df" => "łowca czarownic",
  "9c0e7fb39f9d" => "drobny złodziejaszek",
  "0fddf2e612c5" => "radca miejski w Oxenfurcie",
  "ce46e91581e3" => "prostytutka",
  "925f5575a045" => "prostytutka",
  "78231c07b912" => "prostytutka",
  "2ef86f57506c" => "prostytutka",
  "200840b05799" => "prostytutka",
  "83e93c8103a3" => "łowca czarownic",
  "311f840b79f6" => "prostytutka",
  "4c5e5c8c7d8f" => "prostytutka",
  "e3d755599d88" => "prostytutka",
  "504a7c9b2917" => "prostytutka"
}.freeze

PROMPT_CORRECTIONS = {
  "029abfc40637" => "Kaer Morhen — która postać była magiem-rezydentem w tej warowni w grach z serii Wiedźmin?",
  "2bfa04703bad" => "Hengfors — która postać była magiem-rezydentem w tym mieście w grach z serii Wiedźmin?"
}.freeze

FORCED_REMOVALS = {
  "c5972049936b" => "niejednoznaczna strona Cedrica dotyczy innej postaci",
  "0e9e94f63a06" => "niejednoznaczna strona Cerbina dotyczy innej postaci",
  "3c6147151f2e" => "pole profesji opisuje typ Vildkaar, a nie zajęcie"
}.freeze

LANGUAGE_VALUE_CORRECTIONS = {
  "boatwright's Apprentice" => "uczeń szkutnika",
  "farmer" => "rolnik",
  "soldier" => "żołnierz"
}.freeze

UNSUPPORTED_MEDIUM_BASES = [
  "mapa pomocnicza po kontroli treści i braku rozstrzygających kategorii źródłowych",
  "ogólny fakt o podmiocie wielomedialnym; pierwszeństwo kanonu książkowego"
].freeze

def wiki_url(title)
  "https://wiedzmin.fandom.com/pl/wiki/#{CGI.escape(title.to_s).tr('+', '_')}"
end

def evidence_for(row, profession, relation, pages)
  evidence = Array(row["field_evidence"]) + Array(row["medium_evidence"])
  evidence = Array(row["other_occurrences"]) if evidence.empty?
  result = evidence.first(5).map do |item|
    item.merge("url" => wiki_url(item["source_title"]))
  end
  if result.empty? && profession
    result << {
      "source_title" => profession["page_title"],
      "source_revision_id" => profession["revision_id"],
      "url" => wiki_url(profession["page_title"]),
      "field" => "profesja",
      "text" => profession["profession"]
    }
  end
  if result.empty? && relation
    result << {
      "source_title" => relation["page_title"],
      "source_revision_id" => relation["revision_id"],
      "url" => wiki_url(relation["page_title"]),
      "field" => "relacje",
      "text" => relation["field"]
    }
  end
  if result.empty? && row.fetch("id") == "24fc3ba2b640"
    page = pages.fetch("Vilgefortz z Roggeveen")
    result << {
      "source_title" => page["title"],
      "source_revision_id" => page["revision_id"],
      "url" => wiki_url(page["title"]),
      "field" => "aktor",
      "text" => "Mahesh Jadu (serial, 2019)"
    }
  end
  result
end

def corrected_question(question, prompt, answer)
  output = question.dup
  output["prompt"] = prompt if prompt
  if answer && answer != question.fetch("correct")
    old_correct = question.fetch("correct")
    wrong = question.fetch("wrong").dup
    replacement_index = wrong.index { |candidate| candidate.casecmp?(answer) }
    if replacement_index
      wrong[replacement_index] = old_correct
    end
    wrong = wrong.reject { |candidate| candidate.casecmp?(answer) }.uniq
    wrong << old_correct unless wrong.any? { |candidate| candidate.casecmp?(old_correct) }
    output["correct"] = answer
    output["wrong"] = wrong.first(3)
  end
  output["correct"] = LANGUAGE_VALUE_CORRECTIONS.fetch(output.fetch("correct"), output.fetch("correct"))
  output["wrong"] = output.fetch("wrong").map { |candidate| LANGUAGE_VALUE_CORRECTIONS.fetch(candidate, candidate) }
  output
end

decisions = questions.map do |question|
  id = question.fetch("id")
  row = analysis_by_id.fetch(id)
  medium_row = old_medium.fetch(id)
  profession = professions[id]
  relation = relations[id]
  forced_answer = ANSWER_CORRECTIONS[id]
  forced_removal = FORCED_REMOVALS[id]
  status = row.fetch("status")
  retain = if forced_removal
    false
  elsif forced_answer
    true
  elsif status == "verified_candidate"
    true
  elsif status == "medium_not_proven"
    !UNSUPPORTED_MEDIUM_BASES.include?(medium_row.fetch("basis"))
  else
    false
  end
  reviewed_prompt = PROMPT_CORRECTIONS[id] || medium_data.fetch("prompts")[id] || question.fetch("prompt")
  reviewed = retain ? corrected_question(question, reviewed_prompt, forced_answer) : nil
  reason = if forced_removal
    forced_removal
  elsif forced_answer
    "poprawiono odpowiedź na podstawie jednoznacznego pola źródłowego"
  elsif status == "verified_candidate"
    "relacja i medium potwierdzone w źródle"
  elsif retain
    "relacja potwierdzona; medium zachowane na podstawie wcześniejszego audytu źródłowego"
  elsif status == "medium_not_proven"
    "medium niepotwierdzone niezależnie od pomocniczej mapy"
  else
    "brak wystarczającego potwierdzenia relacji i poprawnej odpowiedzi"
  end
  {
    "id" => id,
    "decision" => retain ? (reviewed != question ? "correct" : "keep") : "remove",
    "reason" => reason,
    "medium" => medium_data.fetch("media").fetch(id),
    "source_status" => status,
    "old_medium_basis" => medium_row.fetch("basis"),
    "original" => question,
    "reviewed" => reviewed,
    "evidence" => evidence_for(row, profession, relation, pages)
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "scope" => "Witcher question factual, medium and language audit",
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("decision") }.transform_values(&:length),
  "retained_by_medium" => decisions.select { |row| row.fetch("reviewed") }.group_by { |row| row.fetch("medium") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary", "retained_by_medium"))
