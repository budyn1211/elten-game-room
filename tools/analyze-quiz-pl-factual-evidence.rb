# encoding: UTF-8
require "cgi"
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

wikidata_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
search_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(3), Dir.pwd)
wikidata = JSON.parse(File.read(wikidata_path, encoding: "UTF-8"))
searches = JSON.parse(File.read(search_path, encoding: "UTF-8")).fetch("searches")
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")
questions_by_id = questions.to_h { |question| [question.fetch("id"), question] }

PREFIXES = %w[
  Minerał Pierwiastek Związek Lek Piłkarz Piłkarka Siatkarz Siatkarka Skoczek
  Skoczkini Tenisista Tenisistka Koszykarz Koszykarka Hokeista Hokeistka
  Kierowca Biskup Papież Rabin Misjonarz Teolog Klub Stadion Turniej Konkurs
  Bitwa Katedra Rzeka Szczyt Zamek Port Bazylika Skocznia Meczet Kościół
  Wojna Wulkan Wodospad Synagoga Opactwo Park Wyspa Królestwo Cieśnina
  Pustynia Kanał Sobór Klasztor Oblężenie Traktat Kaplica Powstanie
  Uniwersytet Góry Dynastia Morze Cesarstwo Republika Wyspy Archidiecezja
  Cerkiew Order Imperium Zatoka Świątynia Pałac
].freeze

STOP_WORDS = %w[
  a aby albo ale ani bez bo być by była był było były co czy dla do gdzie go i ich jak jaka
  jakie jaki jakiego jakim jaką jest jego jej którą który kto ma miał miała może na nad nie
  nim o od oraz po pod przez się ta ten tego tej temu to tu w we według z za ze został została
  należał należała osoba państwo kraju miasta roku którym której którego
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d)[,.](?=\d)/, "").gsub(/[’‘`]/, "'")
    .gsub(/[^\p{L}\p{N}%+'-]+/u, " ").gsub(/\s+/, " ").strip
end

def tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| token.length < 2 || STOP_WORDS.include?(token) }
end

def answer_present?(text, answer)
  haystack = normalized(text)
  needle = normalized(answer)
  return false if needle.empty?
  return true if haystack.include?(needle)

  parts = tokens(answer)
  !parts.empty? && parts.all? { |token| haystack.split.include?(token) }
end

def subject_for(prompt)
  subject = prompt.to_s.split(/\s+—\s+/, 2).first.to_s.strip
  prefix, rest = subject.split(" ", 2)
  PREFIXES.include?(prefix) && rest ? rest : subject
end

def subject_present?(text, prompt)
  haystack = normalized(text)
  subject = normalized(subject_for(prompt))
  return true if !subject.empty? && haystack.include?(subject)

  parts = tokens(subject)
  !parts.empty? && parts.all? { |token| haystack.split.include?(token) }
end

def wikipedia_evidence(search, pages, answer)
  return [] if search.nil?

  Array(search["results"]).filter_map do |result|
    page = pages[result.fetch("pageid").to_s] || {}
    text = [result["title"], result["snippet"], page["extract"]].join(" ")
    next unless subject_present?(text, search.fetch("prompt")) && answer_present?(text, answer)

    {
      "pageid" => result["pageid"],
      "title" => result["title"],
      "url" => page["url"] || result["url"],
      "revision_id" => page["revision_id"],
      "revision_timestamp" => page["revision_timestamp"],
      "snippet" => result["snippet"],
      "extract_excerpt" => page["extract"].to_s[0, 1200]
    }
  end
end

decisions = wikidata.fetch("decisions").map do |row|
  id = row.fetch("id")
  question = questions_by_id.fetch(id)
  search = searches[id]
  wikipedia = wikipedia_evidence(search, pages, question.fetch("correct"))
  alternatives = Array(question["wrong"]).map do |answer|
    { "answer" => answer, "evidence" => wikipedia_evidence(search, pages, answer).first(5) }
  end
  supported_alternatives = alternatives.reject { |candidate| candidate.fetch("evidence").empty? }
  links = Array(question["source_links"])
  status = case row.fetch("status")
  when "verified_referenced_claim"
    "verified_wikidata_referenced"
  when "unreferenced_claim"
    wikipedia.empty? ? "verified_wikidata_unreferenced" : "verified_wikidata_and_wikipedia"
  else
    if !wikipedia.empty?
      "verified_wikipedia"
    elsif supported_alternatives.length == 1
      "correction_candidate_wikipedia"
    elsif !links.empty?
      "provided_source_requires_final_check"
    else
      "not_proven"
    end
  end
  {
    "id" => id,
    "status" => status,
    "prompt" => row.fetch("prompt"),
    "correct" => row.fetch("correct"),
    "wikidata_status" => row.fetch("status"),
    "wikidata_evidence" => row.fetch("evidence"),
    "wikipedia_evidence" => wikipedia.first(5),
    "provided_source_links" => links,
    "suggested_correct" => supported_alternatives.length == 1 ? supported_alternatives.first.fetch("answer") : nil,
    "alternative_evidence" => supported_alternatives
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "wikidata_source" => wikidata_path,
  "wikipedia_search_source" => search_path,
  "wikipedia_page_source" => pages_path,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
