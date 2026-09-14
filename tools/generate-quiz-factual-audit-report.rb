# encoding: UTF-8
require "json"
require "time"

audit_root = File.expand_path(ARGV.fetch(0), Dir.pwd)

packs = {
  "quiz.general.en" => "ENGLISH_FINAL_DECISIONS.json",
  "quiz.wikidata.pl" => "POLISH_FINAL_DECISIONS_MERGED.json",
  "quiz.witcher.pl" => "WITCHER_FINAL_DECISIONS.json"
}.transform_values do |filename|
  JSON.parse(File.read(File.join(audit_root, filename), encoding: "UTF-8"))
end

all = packs.flat_map do |pack_id, payload|
  payload.fetch("decisions").map { |row| row.merge("pack_id" => pack_id) }
end

raise "duplicate question IDs across audited packs" if all.map { |row| row.fetch("id") }.uniq.length != all.length

removed = all.select { |row| row.fetch("decision") == "remove" }
corrected = all.select { |row| row.fetch("decision") == "correct" }
kept = all.select { |row| row.fetch("decision") == "keep" }

summary = packs.transform_values do |payload|
  decisions = payload.fetch("decisions")
  {
    "input" => decisions.length,
    "kept_unchanged" => decisions.count { |row| row.fetch("decision") == "keep" },
    "corrected" => decisions.count { |row| row.fetch("decision") == "correct" },
    "removed" => decisions.count { |row| row.fetch("decision") == "remove" },
    "semantic_safety_removals" => decisions.count { |row| row["semantic_safety_removal"] == true },
    "retained" => decisions.count { |row| row.fetch("decision") != "remove" }
  }
end

File.write(
  File.join(audit_root, "ALL_DECISIONS.json"),
  JSON.generate("generated" => Time.now.utc.iso8601, "summary" => summary, "decisions" => all) + "\n",
  encoding: "UTF-8"
)
File.write(
  File.join(audit_root, "REMOVED.json"),
  JSON.generate("generated" => Time.now.utc.iso8601, "count" => removed.length, "questions" => removed) + "\n",
  encoding: "UTF-8"
)
File.write(
  File.join(audit_root, "CORRECTED.json"),
  JSON.generate("generated" => Time.now.utc.iso8601, "count" => corrected.length, "questions" => corrected) + "\n",
  encoding: "UTF-8"
)

comparison = packs.fetch("quiz.wikidata.pl").fetch("comparison")
report = <<~MARKDOWN
  # Quiz Party — audyt merytoryczny i językowy

  Wygenerowano: #{Time.now.utc.iso8601}

  ## Zakres i reguła decyzji

  Audyt obejmuje każde pytanie istniejące przed tą zmianą w angielskim zestawie
  ogólnym, polskim zestawie ogólnym i polskim zestawie Wiedźmina. Pytanie
  pozostaje tylko wtedy, gdy wskazana poprawna odpowiedź jest poparta zapisanym
  dowodem. Pytania, których nie udało się potwierdzić, zostały usunięte. Raport
  nie twierdzi, że dystraktory wyczerpują wszystkie możliwe fakty; kontroluje ich
  jednoznaczność względem przyjętej odpowiedzi i zapisuje znalezione wady treści.

  ## Wyniki

  | Zestaw | Przed | Bez zmian | Poprawiono | Usunięto | Po audycie |
  |---|---:|---:|---:|---:|---:|
  #{summary.map { |id, row| "| `#{id}` | #{row.fetch('input')} | #{row.fetch('kept_unchanged')} | #{row.fetch('corrected')} | #{row.fetch('removed')} | #{row.fetch('retained')} |" }.join("\n")}

  Łącznie przed audytem: #{all.length}. Pozostawiono: #{kept.length + corrected.length}.
  Poprawiono: #{corrected.length}. Usunięto: #{removed.length}.

  Spośród usuniętych #{summary.values.sum { |row| row.fetch('semantic_safety_removals') }}
  przeszło pierwszy test dowodów, ale odpadło w końcowej kontroli
  niejednoznaczności, przeczeń, nakładających się odpowiedzi lub trwałości faktu.

  ## Porównanie z niezależnym audytem polskiego zestawu

  Audyt Balteama z commita `9be74abfa6968270bfc04312833767bd83833ac3`
  porównano po stabilnych identyfikatorach pytań, zamiast kopiować go bez
  sprawdzenia. Przyjęto #{comparison.fetch('balteam_removals')} usunięć opartych
  na schemacie źródłowym i #{comparison.fetch('balteam_edits')} poprawionych
  rekordów. #{comparison.fetch('balteam_removals_overriding_our_retention')}
  usunięć wykryło wady relacji lub schematu niewidoczne w lokalnym wyszukiwaniu
  tekstowym. Z kolei #{comparison.fetch('balteam_retention_overriding_our_false_negative')}
  pytań odrzuconych przez lokalne wyszukiwanie przywrócono, ponieważ niezależny
  audyt strukturalny dostarczył mocniejszego dowodu. Każda poprawka zachowuje
  oryginalny identyfikator pytania.

  ## Odtwarzalność

  `ALL_DECISIONS.json` zawiera dokładnie jedną decyzję dla każdego oryginalnego
  pytania. `REMOVED.json` i `CORRECTED.json` są osobnymi widokami. Przy każdym
  rekordzie zapisano przyczynę decyzji i adresy dowodów. `SOURCES.md` opisuje
  wykorzystane usługi danych i rewizję niezależnego audytu.
MARKDOWN
File.write(File.join(audit_root, "REPORT.md"), report, encoding: "UTF-8")

sources = <<~MARKDOWN
  # Źródła użyte w audycie Quiz Party

  - Wikidata item statements and references: https://www.wikidata.org/
  - English Wikipedia search and article text: https://en.wikipedia.org/
  - Polish Wikipedia search and article text: https://pl.wikipedia.org/
  - Polish Witcher Wiki article revisions: https://wiedzmin.fandom.com/pl/wiki/Wied%C5%BAmin_Wiki
  - OpenTriviaQA source repository and original attribution: https://github.com/uberspot/OpenTriviaQA
  - Balteam Polish audit, pinned commit: https://github.com/budyn1211/elten-game-room/commit/9be74abfa6968270bfc04312833767bd83833ac3

  Adresy dowodów dla poszczególnych pytań są zapisane w rekordach
  `ALL_DECISIONS.json`.
MARKDOWN
File.write(File.join(audit_root, "SOURCES.md"), sources, encoding: "UTF-8")

puts JSON.pretty_generate(
  "question_count" => all.length,
  "kept" => kept.length,
  "corrected" => corrected.length,
  "removed" => removed.length,
  "summary" => summary
)
