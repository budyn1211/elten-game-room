# encoding: UTF-8
require "cgi"
require "fileutils"
require "json"
require "time"

audit_root = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_root = File.expand_path(ARGV.fetch(1), Dir.pwd)
loose_path = File.join(output_root, "ALL_RECHECK_DECISIONS.json")

def read_json(path)
  JSON.parse(File.read(path, encoding: "UTF-8"))
end

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/[’‘`]/, "'").gsub(/[-‐‑‒–—]/u, "-")
    .gsub(/\s+/, " ").strip
end

def answer_words(value)
  normalized(value).gsub(/[^\p{L}\p{N}]+/u, " ").gsub(/\s+/, " ").strip
end

def answer_parts(value)
  normalized(value).split(/\s*(?:,|;|\/|&|\band\b|\bor\b|\bi\b|\blub\b|\boraz\b)\s*/i)
    .map { |part| answer_words(part) }.reject(&:empty?).uniq
end

def semantic_answer_overlap?(question)
  left = question.fetch("correct")
  question.fetch("wrong").any? do |right|
    left_words = answer_words(left)
    right_words = answer_words(right)
    phrase_overlap = if left_words.length <= right_words.length
      right_words.match?(/(?:\A| )#{Regexp.escape(left_words)}(?: |\z)/)
    else
      left_words.match?(/(?:\A| )#{Regexp.escape(right_words)}(?: |\z)/)
    end
    left_parts = answer_parts(left)
    right_parts = answer_parts(right)
    component_overlap = left_parts.length > 1 || right_parts.length > 1 ?
      ((left_parts - right_parts).empty? || (right_parts - left_parts).empty?) : false
    phrase_overlap || component_overlap
  end
end

english = read_json(File.join(audit_root, "ENGLISH_FINAL_DECISIONS.json"))
polish = read_json(File.join(audit_root, "POLISH_FINAL_DECISIONS_MERGED.json"))
witcher = read_json(File.join(audit_root, "WITCHER_FINAL_DECISIONS.json"))
loose = File.exist?(loose_path) ? read_json(loose_path) : { "decisions" => [] }
loose_by_key = loose.fetch("decisions", []).to_h do |row|
  [[row.fetch("pack_id"), row.fetch("id")], row]
end

# These questions were inspected individually after the broad second pass. The
# allow-list is intentionally conservative: a plausible answer or a keyword
# match is not enough to bring a question back into the playable data.
ENGLISH_REVISION_EVIDENCE_IDS = %w[
  ee8b2333ba2f 7254fd3e68e9 a533fdd6f1b1 a69e58c8d27d 7e784680c3c8
  89a0b0117bb6 d6d015aab2f8 e256c22e9f02 876090cbb8bd 83473da7cbef
  a5c78221b878 40a42a28e5ee b85f52cb66b6 c054f686fd5d fdd9bb159fec
  de1925cef8c3 67ce66fc837d 09675b738acc 12bb08fc7ba1 71b8dbd05ea9
  c078c31d774c 290b66fb4ebf 0079162fd166 2c4b864d772f 4cb30f825904
  b2be925d605d bfd04fd7b2e6 2e3cc0c70ee3 aaaf844bf311 d2532095eab0
  c3f03b5e0358 2f1186ba2221 0281ef663f97 030e3c7fed35 06f1a7269a9c
  395e99aa1699 5132dc29a05d 6e9e0757d55f 53b5c53b6395 0784df4cc911
  ddda6fe042a8 d5dad6d6158f 9693118decb2 7c46f150db38 346047f3622c
  3d80fda21cec 79f76f220e08 29e1fc47e003 6c8f0f9307c5 c2d69b143e73
  7a14cfb0137d 56ce657db182 cbbdabf9785a f88932960813 c8d86a0fe467
  fe078ecbfc1b 06f53ae71d6e
].freeze

ENGLISH_MANUAL_EVIDENCE = {
  "853278fef320" => {
    "kind" => "deterministic calculation",
    "source" => "12 × 2 + (6 ÷ 4)²",
    "result" => "26.25"
  },
  "375a54045635" => {
    "kind" => "official geographic definition",
    "url" => "https://www.census.gov/programs-surveys/popest/about/glossary/geo-terms.html",
    "statement" => "The Census Pacific division contains Alaska, California, Hawaii, Oregon and Washington."
  },
  "c8adec7daa0c" => {
    "kind" => "biographical source",
    "url" => "https://en.wikipedia.org/wiki/Che_Guevara",
    "statement" => "Che Guevara was born in Rosario, Argentina."
  },
  "9631d425b22a" => {
    "kind" => "official European Union history",
    "url" => "https://enlargement.ec.europa.eu/enlargement-policy/history-enlargement-6-27-members_en",
    "statement" => "The six founding countries were Belgium, France, Germany, Italy, Luxembourg and the Netherlands."
  },
  "83c7f5309b44" => {
    "kind" => "museum artist profile",
    "url" => "https://www.nga.gov/artists/1219-edgar-degas",
    "statement" => "The National Gallery of Art profile identifies Edgar Degas and his dancers and ballet subjects."
  },
  "447ba265f48c" => {
    "kind" => "official South Carolina state page",
    "url" => "https://www.scstatehouse.gov/studentpage/coolstuff/colors.shtml",
    "statement" => "South Carolina's official state color is indigo blue."
  },
  "76f283b9cffd" => {
    "kind" => "Arkansas Geological Survey",
    "url" => "https://geology.arkansas.gov/minerals/industrial/gemstone.html",
    "statement" => "Diamond is the official state gem of Arkansas."
  },
  "b51ba13bc2b2" => {
    "kind" => "United States National Archives",
    "url" => "https://prologue.blogs.archives.gov/2016/04/11/a-record-setting-amendment/",
    "statement" => "The Twenty-Seventh Amendment was ratified in 1992."
  },
  "390f91fb13f0" => {
    "kind" => "official Beatles catalogue",
    "url" => "https://www.thebeatles.com/please-please-me",
    "statement" => "Please Please Me is a Beatles album."
  },
  "3c3c496bb5d5" => {
    "kind" => "official Eurovision history",
    "url" => "https://eurovision.tv/event/lugano-1956",
    "statement" => "The first Eurovision Song Contest was held in Lugano, Switzerland, in 1956."
  },
  "f19062ac460f" => {
    "kind" => "United Nations history",
    "url" => "https://www.un.org/en/about-us/history-of-the-un",
    "statement" => "The United Nations officially came into existence in 1945."
  }
}.freeze

ENGLISH_PROMPTS = {
  "de1925cef8c3" => "In what month of 1941 did Nazi Germany's invasion of the Soviet Union start?",
  "12bb08fc7ba1" => "What is Alan Rickman's birth date?",
  "0079162fd166" => "Complete the title of Gwen Stefani's song from The Sweet Escape: ____ in the Morning.",
  "b2be925d605d" => "Which group released the album Californication?",
  "2e3cc0c70ee3" => "In what year was Sublime's first studio album released?",
  "aaaf844bf311" => "Which Beatle wrote Yesterday?",
  "c3f03b5e0358" => "Which group recorded the song Wannabe?",
  "030e3c7fed35" => "What type of motion is described by y = A sin(ωt)?",
  "06f1a7269a9c" => "When was the first intercollegiate women's basketball game played?",
  "f88932960813" => "What is Wyoming's state dinosaur?",
  "fe078ecbfc1b" => "Why did the American Frederic Tudor become known as the Ice King?",
  "06f53ae71d6e" => "Which U.S. state has the official nickname The Silver State?",
  "390f91fb13f0" => "Who recorded the album Please Please Me?"
}.freeze

POLISH_PERSON_PROMPTS = {
  "d4ca51440ba6" => "Która z poniższych osób była doktorantem Bernarda Houssaya?",
  "ee056f5298c6" => "Z odkryciem której witaminy jest związany Edward Adelbert Doisy?",
  "382d227cfbf2" => "Z opracowaniem jakiego urządzenia jest związany Frits Zernike?",
  "93919729b3e1" => "Jaki materiał wynalazł Leo Baekeland?",
  "9368247a2830" => "Z którą dziedziną jest związany Samuel Hahnemann?",
  "da123c3d6d62" => "Z leczeniem jakiej choroby jest związana praca Alice Augusty Ball?",
  "d7270586f994" => "Z odkryciem jakiej substancji jest związany Anselme Payen?",
  "39a3390014c0" => "Z założeniem której firmy jest związany Georges Claude?",
  "79cc505fc9b6" => "Z pierwszą syntezą jakiej substancji jest związany Julius Wilbrand?",
  "4853288b28e5" => "Z założeniem której firmy jest związany Paul Delorme?",
  "33c5c39e05fa" => "Odkrycie jakiego rodzaju promieniowania przypisuje się Paulowi Villardowi?",
  "204ac5423b57" => "Ze sformułowaniem którego prawa jest związany Peter Waage?",
  "b947e1ea2aa8" => "Z opracowaniem czego jest związany Satori Kato?",
  "fb349829f660" => "Z opracowaniem którego leku jest związany Stewart Adams?"
}.freeze

POLISH_DIRECT_STATUSES = %w[
  verified_wikidata_and_wikipedia verified_wikipedia verified_full_wikipedia
].freeze
POLISH_SCHEMA_PREFIX = "chemia:nieprecyzyjny_lub_niejednorodny_schemat_"
POLISH_GENERIC_CLASSES = [
  "związek chemiczny", "utleniacz", "butan"
].freeze

WITCHER_SAFE_IDS = %w[
  94a52c67899c 45c6fef8e049 be4f9af04397 1276ff39fe71 62f33efb1934
  0f53890abf59 ade2370330ec 6ec1b3e449a5 7ade45ce9ff6 0d662c81b7b5
  dece1e09eafd 1473a501702f 35b3c6c98d82 311d865379b6 a65561ada190
  2d4ff3cdef32 932f787c0e2f 64241237c505 faeaef23844a 3e286a6b683b
  77b9e978247b c430ff23eca8 fb214b93c860 45f775e4de90 2085b3d3dd29
  4bae81d1c42d 5eef2b3618b4 cf0686681a15 d912cbf07caa 0d164a42ee80
  459c7c7d9038 ce7d9136fcd4 ac1b106b350c 72d3e98cd543 726d0aaf2dfe
  3949b2f6f3fa 1cd43cef4af1 628004c51073 939b454f5176 1739ab3d9a59
  456fc5c10119 2dc0cffc19f6 1337459b12c5 e995228fdc06 794ffbd2f150
  8b86af6ebe9f cdd8965e446e dbf3b7bf3f4b 9f18ed2cc8bd 4c631a6a430a
  4d0bdf64c210 69e146603108 73ffc9609e94 5458a878a3db 366fa5758b3a
  61e02d20f761 577716107ff8 0bd424b5dce3 9c63cc5cb233 74ca04e0cbe4
  d76df0febb36 7d5e6e0f3607 6d45c3201d2a 9596238dfcd2 eab175e7a5e2
  96c2732efd73 4993c151ca6f 9c7a50086d40
].freeze

WITCHER_PROMPTS = {
  "61e02d20f761" => "Kto był właścicielem Rocamory i używał jej jako bazy?",
  "74ca04e0cbe4" => "Kto stacjonował w zamku Tuzla i nadzorował tam dostawy?",
  "d76df0febb36" => "Kto był mężem Vulpii z Brugge?",
  "eab175e7a5e2" => "Czyim synem był Audoen?"
}.freeze

def loose_evidence(loose_by_key, pack_id, id, fallback)
  row = loose_by_key[[pack_id, id]]
  evidence = row && row["decision"] == "restore" ? Array(row["evidence"]) : []
  evidence.empty? ? Array(fallback) : evidence
end

def polish_schema_only?(row)
  reasons = Array(row["balteam_reasons"])
  !reasons.empty? && reasons.all? { |reason| reason.start_with?(POLISH_SCHEMA_PREFIX) }
end

def hardness_interval(row)
  values = []
  Array(row["evidence"]).each do |evidence|
    if evidence["property"] == "P1088" && evidence["value"].to_s.match?(/\A\d+(?:[.,]\d+)?\z/)
      values << evidence["value"].tr(",", ".").to_f
    end
    [evidence["excerpt"], evidence["text"], evidence["context"]].compact.each do |text|
      match = normalized(text).match(/twardość w skali mohsa\s+([^a-ząćęłńóśźż]{1,30})/i)
      next if match == nil
      segment = match[1].split(/\b(?:s|stron\w*|data|przełam|łupliwość)\b/i, 2).first
      values.concat(segment.scan(/(?:\A|\s)(10|[0-9](?:[.,][0-9]+)?)(?=\s|\z|-)/).flatten.map { |value| value.tr(",", ".").to_f })
    end
  end
  values.uniq!
  values.empty? ? nil : [values.min, values.max]
end

def safe_hardness?(row)
  interval = hardness_interval(row)
  return false if interval == nil
  answer = Float(row.fetch("original").fetch("correct").tr(",", ".")) rescue nil
  return false if answer == nil || answer < interval[0] || answer > interval[1]
  wrong = row.fetch("original").fetch("wrong").filter_map do |value|
    Float(value.tr(",", ".")) rescue nil
  end
  wrong.none? { |value| value >= interval[0] && value <= interval[1] }
end

def polish_review(row)
  question = row.fetch("original")
  prompt = question.fetch("prompt")
  return [false, nil, "the independent Polish evidence does not confirm the exact relation"] unless
    POLISH_DIRECT_STATUSES.include?(row.fetch("source_status")) && polish_schema_only?(row)

  if POLISH_PERSON_PROMPTS.key?(row.fetch("id"))
    return [true, question.merge("prompt" => POLISH_PERSON_PROMPTS.fetch(row.fetch("id"))),
      "the named person's exact achievement, field or academic relation is directly supported"]
  end

  if prompt.match?(/wzór (?:sumaryczny|chemiczny)/)
    return [true, question, "the exact chemical formula is directly supported"]
  end

  if prompt.start_with?("Minerał ") && prompt.match?(/klasy/)
    reviewed = question.merge("prompt" => prompt.sub("do jakiej klasy należy?", "do której z poniższych klas jest zaliczany?"))
    return [true, reviewed, "the mineral family is supported and none of the alternatives overlaps it"]
  end

  if prompt.start_with?("Związek ") && prompt.match?(/klasy/)
    answers = [question.fetch("correct"), *question.fetch("wrong")].map { |value| normalized(value) }
    correct = answers.shift
    safe = !POLISH_GENERIC_CLASSES.include?(correct) && !answers.include?("związek chemiczny")
    return [false, nil, "the proposed chemical class remains generic, functional, or overlaps another answer"] unless safe
    reviewed = question.merge("prompt" => prompt.sub("do jakiej klasy należy?", "do której z poniższych klas jest zaliczany?"))
    return [true, reviewed, "a specific chemical class is supported and the alternatives are non-overlapping"]
  end

  if prompt.match?(/do czego się go stosuje/)
    reviewed = question.merge("prompt" => prompt.sub("do czego się go stosuje?", "które z poniższych jest jednym z jego zastosowań?"))
    return [true, reviewed, "the stated use is directly supported; the wording no longer implies exclusivity"]
  end

  if prompt.match?(/twardość w skali Mohsa/)
    return [false, nil, "the documented Mohs interval is missing or makes another answer valid"] unless safe_hardness?(row)
    interval = hardness_interval(row)
    reviewed_prompt = if interval[0] == interval[1]
      prompt
    else
      prompt.sub("jaką ma twardość", "która z poniższych wartości mieści się w podawanym zakresie twardości")
        .sub("twardość twardość", "twardość")
    end
    return [true, question.merge("prompt" => reviewed_prompt),
      "the documented Mohs value or range contains only the stated answer among the choices"]
  end

  [false, nil, "the schema or wording remains insufficiently precise for restoration"]
end

rechecks = []

english.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  id = row.fetch("id")
  question = row.fetch("original")
  manual = ENGLISH_MANUAL_EVIDENCE[id]
  revision_evidence = ENGLISH_REVISION_EVIDENCE_IDS.include?(id) ?
    loose_evidence(loose_by_key, "quiz.general.en", id, row["evidence"]) : []
  restore = manual != nil || (!revision_evidence.empty? && ENGLISH_REVISION_EVIDENCE_IDS.include?(id))
  reviewed = restore ? question.merge("prompt" => ENGLISH_PROMPTS.fetch(id, question.fetch("prompt"))) : nil
  evidence = manual ? [manual] : revision_evidence
  rechecks << {
    "pack_id" => "quiz.general.en", "id" => id,
    "decision" => restore ? "restore" : "remain_removed",
    "reason" => if restore
      manual ? "the exact asked fact was confirmed independently" :
        "a revision-pinned passage confirms the exact subject-answer relation and the alternatives remain false"
    else
      "the available evidence still does not prove the exact relation, a stable time frame, or one uniquely correct answer"
    end,
    "previous_reason" => row.fetch("reason"), "original" => question,
    "reviewed" => reviewed, "evidence" => evidence.empty? ? Array(row["evidence"]) : evidence
  }
end

polish.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  restore, reviewed, reason = polish_review(row)
  rechecks << {
    "pack_id" => "quiz.wikidata.pl", "id" => row.fetch("id"),
    "decision" => restore ? "restore" : "remain_removed",
    "reason" => reason, "previous_reason" => row.fetch("reason"),
    "original" => row.fetch("original"), "reviewed" => reviewed,
    "evidence" => Array(row["evidence"])
  }
end

witcher.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  id = row.fetch("id")
  restore = WITCHER_SAFE_IDS.include?(id)
  question = row.fetch("original")
  reviewed = restore ? question.merge("prompt" => WITCHER_PROMPTS.fetch(id, question.fetch("prompt"))) : nil
  evidence = loose_evidence(loose_by_key, "quiz.witcher.pl", id, row["evidence"])
  rechecks << {
    "pack_id" => "quiz.witcher.pl", "id" => id,
    "decision" => restore ? "restore" : "remain_removed",
    "reason" => if restore
      "the evidence directly supports the fact in the assigned game/book/screen medium and no alternative is supported"
    else
      "the exact fact, assigned medium, or uniqueness of the answer remains insufficiently established"
    end,
    "previous_reason" => row.fetch("reason"), "medium" => row.fetch("medium"),
    "original" => question, "reviewed" => reviewed,
    "evidence" => evidence
  }
end

# Textual containment is only a review signal, never a verdict by itself.  A
# correct answer such as "brother and sister" may legitimately coexist with the
# distractor "brother" when the question and its evidence require both people;
# the reverse can also be valid when only the brother did the stated thing.
# Quarantine only answer relations whose ambiguity was established for that
# exact question and its declared correct answer.
AMBIGUOUS_ANSWER_RELATIONS = {
  "aaaf844bf311" => "the wording does not distinguish sole composition from the formal Lennon-McCartney credit"
}.freeze

rechecks.each do |row|
  next unless row.fetch("decision") == "restore"
  next unless AMBIGUOUS_ANSWER_RELATIONS.key?(row.fetch("id"))
  next unless semantic_answer_overlap?(row.fetch("reviewed"))

  row["decision"] = "remain_removed"
  row["reason"] = AMBIGUOUS_ANSWER_RELATIONS.fetch(row.fetch("id"))
  row["reviewed"] = nil
end

expected = english.fetch("decisions").count { |row| row.fetch("decision") == "remove" } +
  polish.fetch("decisions").count { |row| row.fetch("decision") == "remove" } +
  witcher.fetch("decisions").count { |row| row.fetch("decision") == "remove" }
raise "recheck coverage mismatch" unless rechecks.length == expected
keys = rechecks.map { |row| [row.fetch("pack_id"), row.fetch("id")] }
raise "duplicate recheck IDs" unless keys.uniq.length == keys.length
raise "restored question without reviewed data" if rechecks.any? { |row| row["decision"] == "restore" && row["reviewed"] == nil }

summary = rechecks.group_by { |row| row.fetch("pack_id") }.transform_values do |rows|
  rows.group_by { |row| row.fetch("decision") }.transform_values(&:length)
end
methods = rechecks.select { |row| row.fetch("decision") == "restore" }
  .group_by { |row| [row.fetch("pack_id"), row.fetch("reason")] }
  .transform_values(&:length)
generated = Time.now.utc.iso8601
payload = {
  "generated" => generated,
  "source_audit" => audit_root,
  "review_policy" => "restore only after exact fact, medium where applicable, and unique-answer verification",
  "question_count" => rechecks.length,
  "summary" => summary,
  "restoration_methods" => methods.map { |(pack_id, reason), count| { "pack_id" => pack_id, "reason" => reason, "count" => count } },
  "decisions" => rechecks
}

FileUtils.mkdir_p(output_root)
File.write(File.join(output_root, "ALL_RECHECK_DECISIONS.json"), JSON.generate(payload) + "\n", encoding: "UTF-8")
File.write(File.join(output_root, "RESTORED.json"), JSON.pretty_generate(
  "generated" => generated,
  "questions" => rechecks.select { |row| row.fetch("decision") == "restore" }
) + "\n", encoding: "UTF-8")

lines = [
  "# Drugi audyt odrzuconych pytań po buildzie 221",
  "",
  "Ponownie rozpatrzono każde z #{rechecks.length} pytań odrzuconych w audycie builda 220.",
  "Pytanie przywracano wyłącznie po potwierdzeniu dokładnej relacji, właściwego medium",
  "(dla Wiedźmina) i jednoznaczności całego zestawu odpowiedzi.",
  "Relacje część–całość oceniano względem odpowiedzi oznaczonej jako poprawna;",
  "samo zawieranie jednego wariantu w drugim nie było automatycznym powodem odrzucenia.",
  "",
  "| Zestaw | Przywrócone | Nadal odrzucone |",
  "|---|---:|---:|"
]
summary.each do |pack_id, counts|
  lines << "| #{pack_id} | #{counts.fetch('restore', 0)} | #{counts.fetch('remain_removed', 0)} |"
end
lines.concat([
  "",
  "Pełny rejestr decyzji i dowodów znajduje się w `ALL_RECHECK_DECISIONS.json`.",
  "Lista przywróconych pytań znajduje się w `RESTORED.json`.",
  "",
  "Szerokie wysłanie wszystkich angielskich pytań do zewnętrznej wyszukiwarki nie zostało",
  "wykonane. Brak nowego dowodu nie był traktowany jako dowód poprawności: takie pytania",
  "pozostały odrzucone. Dodatkowo zweryfikowano ręcznie tylko kandydatów spełniających",
  "rygorystyczne warunki przywrócenia.",
  ""
])
File.write(File.join(output_root, "REPORT.md"), lines.join("\n"), encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary", "restoration_methods"))
