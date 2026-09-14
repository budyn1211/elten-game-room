# encoding: UTF-8
require "cgi"
require "json"
require "time"

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
two_hop_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
search_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(3), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(4), Dir.pwd)

analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
two_hop = JSON.parse(File.read(two_hop_path, encoding: "UTF-8"))
searches = JSON.parse(File.read(search_path, encoding: "UTF-8")).fetch("searches")
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")
two_hop_by_id = two_hop.fetch("decisions").to_h { |row| [row.fetch("id"), row] }
separator = " #{[0x2014].pack('U')} "

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

RULES = [
  [/kogo zastąpił na tronie|po kim objął .*tron/, /poprzedni|poprzednik|zastąpił|objął tron po/],
  [/kto był jego następcą|kto objął polski tron po nim/, /następc|zastąpił go|tron po/],
  [/twardość w skali mohsa/, /twardość|mohs/],
  [/kto wygrał klasyfikację/, /zwycię|klasyfikac|pierwsze miejsce|1\. miejsce|triumf/],
  [/w jakim państwie leży|w jakim państwie płynie|najwyższy punkt jakiego państwa/, /państw|kraj|położenie|lokalizac|przepływa|najwyższy punkt/],
  [/z jakiego państwa pochodził|w jakim państwie sprawowała urząd/, /pochodzen|narodowość|urodz|państw|kraj|urząd|stanowisko/],
  [/w którym roku ją wzniesiono|w którym roku go zbudowano/, /wznies|zbud|budow|ukończ|konsekr/],
  [/jaki szczyt jest najwyższym punktem tego regionu/, /najwyższy punkt|najwyższy szczyt/],
  [/w jakim województwie leży to miasto/, /województw|podział administracyjny|położenie/],
  [/w którym roku powstał ten dokument|w którym roku tego dokonano/, /data|rok|powsta|podpis|ustanow|ogłosz/],
  [/do jakiego pasma górskiego należy/, /pasmo|łańcuch|masyw|góry/],
  [/w którym roku założono to miasto/, /założ|lokac|prawa miejskie|powsta/],
  [/na jakim kontynencie się znajduje/, /kontynent|położenie|znajduje się/],
  [/w którym roku ją stoczono/, /bitwa|stoczon|data/],
  [/częścią jakiego konfliktu była ta bitwa/, /konflikt|wojna|część/],
  [/w którym roku to państwo powstało|w którym roku to państwo upadło/, /powsta|założ|upad|rozpad|data/],
  [/w którym roku ta wojna wybuchła|w którym roku wybuchło/, /wybuch|rozpoczę|data/],
  [/w którym roku ta wojna się skończyła/, /zakończ|koniec|data/],
  [/w którym roku zmarł ten papież/, /zmarł|śmier|data/],
  [/w jakim mieście się znajduje/, /miasto|miejscowość|położenie|lokalizacja/],
  [/do jakiej rzeki wpada/, /uchodzi|dopływ|rzeka/],
  [/w którym roku ta osoba dostała nobla/, /nobel|nagrod|laureat/]
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/\{\{[^{}]*\|([^{}|]+)\}\}/, '\\1')
    .gsub(/<[^>]+>/, " ").gsub(/[^\p{L}\p{N}%+'.,-]+/u, " ")
    .gsub(/\s+/, " ").strip
end

def subject_for(prompt, separator)
  subject = prompt.to_s.split(separator, 2).first.to_s.strip
  prefix, rest = subject.split(" ", 2)
  PREFIXES.include?(prefix) && rest ? rest : subject
end

def page_matches_subject?(page, subject)
  title = normalized(page["title"])
  needle = normalized(subject)
  return false if title.empty? || needle.empty?
  title == needle || title.start_with?(needle + " ") || needle.start_with?(title + " ")
end

def value_pattern(answer)
  escaped = Regexp.escape(normalized(answer))
  if normalized(answer).match?(/\A\d+(?:[.,]\d+)?\z/)
    /(?<![\p{L}\p{N}])#{escaped}(?![\p{L}\p{N}])/u
  else
    /(?:\A|[^\p{L}\p{N}])#{escaped}(?:\z|[^\p{L}\p{N}])/u
  end
end

def relevant_evidence(page, suffix, answer)
  rule = RULES.find { |prompt_pattern, _context_pattern| normalized(suffix).match?(prompt_pattern) }
  return [] unless rule
  context_pattern = rule[1]
  answer_pattern = value_pattern(answer)
  lines = page.fetch("wikitext", "").lines.map { |line| normalized(line) }
  lines.each_index.filter_map do |index|
    window = lines[[index - 1, 0].max, 3].join(" ")
    next unless window.match?(context_pattern) && window.match?(answer_pattern)
    {
      "pageid" => page["pageid"],
      "title" => page["title"],
      "url" => page["url"],
      "revision_id" => page["revision_id"],
      "revision_timestamp" => page["revision_timestamp"],
      "line" => index + 1,
      "excerpt" => window[0, 1200]
    }
  end.first(5)
end

decisions = analysis.fetch("decisions").map do |row|
  id = row.fetch("id")
  suffix = row.fetch("prompt").split(separator, 2)[1].to_s
  search = searches[id] || {}
  candidate_pages = Array(search["results"]).first(3).filter_map do |result|
    page = pages[result.fetch("pageid").to_s]
    page if page && page_matches_subject?(page, subject_for(row.fetch("prompt"), separator))
  end
  correct_evidence = candidate_pages.flat_map { |page| relevant_evidence(page, suffix, row.fetch("correct")) }
  alternative_evidence = Array(row["alternative_evidence"]).map { |candidate| candidate["answer"] }.compact
  alternative_evidence |= Array(row["suggested_correct"])
  alternatives = alternative_evidence.uniq.to_h do |answer|
    [answer, candidate_pages.flat_map { |page| relevant_evidence(page, suffix, answer) }]
  end
  supported_alternatives = alternatives.reject { |_answer, evidence| evidence.empty? }
  hop = two_hop_by_id[id]
  status = if row.fetch("status").start_with?("verified_")
    row.fetch("status")
  elsif hop && hop.fetch("status") == "verified_two_hop"
    "verified_two_hop"
  elsif !correct_evidence.empty?
    "verified_full_wikipedia"
  elsif !row.fetch("provided_source_links", []).empty?
    "provided_source_requires_final_check"
  elsif supported_alternatives.length == 1
    "correction_candidate_full_wikipedia"
  else
    "not_proven"
  end
  row.merge(
    "status" => status,
    "full_wikipedia_evidence" => correct_evidence,
    "two_hop_evidence" => hop && hop.fetch("evidence", []),
    "full_wikipedia_suggested_correct" => supported_alternatives.length == 1 ? supported_alternatives.keys.first : nil,
    "full_wikipedia_alternative_evidence" => supported_alternatives
  )
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
