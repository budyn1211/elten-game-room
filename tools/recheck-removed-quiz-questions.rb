# encoding: UTF-8
require "cgi"
require "fileutils"
require "json"
require "time"

audit_root = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_root = File.expand_path(ARGV.fetch(1), Dir.pwd)

def read_json(path)
  JSON.parse(File.read(path, encoding: "UTF-8"))
end

english = read_json(File.join(audit_root, "ENGLISH_FINAL_DECISIONS.json"))
polish = read_json(File.join(audit_root, "POLISH_FINAL_DECISIONS_MERGED.json"))
witcher = read_json(File.join(audit_root, "WITCHER_FINAL_DECISIONS.json"))
english_search = read_json(File.join(audit_root, "WIKIPEDIA_EN_SEARCH_V2.json")).fetch("searches")
english_pages = read_json(File.join(audit_root, "WIKIPEDIA_EN_TEXT.json")).fetch("pages")

ENGLISH_UNCONFIRMED = "the stated correct answer could not be confirmed in the checked sources"
POLISH_SAFE_SCHEMA = /\Achemia:nieprecyzyjny_lub_niejednorodny_schemat_/
POLISH_DIRECT_STATUSES = %w[
  verified_wikidata_and_wikipedia verified_wikipedia verified_full_wikipedia
].freeze

STOP_WORDS = %w[
  a an about according after again against all also am among and any are as at be because
  been before being between both but by can could did do does doing during each few for from
  further had has have having he her here hers herself him himself his how i if in into is it
  its itself known made make many me more most my myself no nor not of off on once one only or
  other our ours ourselves out over own same she should so some such than that the their theirs
  them themselves then there these they this those through to too under until up very was we
  were what when where which while who whom whose why will with would you your yours yourself
  yourselves approximately following
].freeze

RELATION_GROUPS = [
  [/\b(?:born|birth|birthplace)\b/, /\b(?:born|birth|birthplace)\b/],
  [/\b(?:died|death|killed|murdered)\b/, /\b(?:died|death|killed|murdered)\b/],
  [/\b(?:founded|formed|established|created|opened)\b/, /\b(?:founded|formed|established|created|opened)\b/],
  [/\b(?:first appearance|first appear|debut)\b/, /\b(?:first appearance|first appeared|debut)\b/],
  [/\b(?:played|portrayed|voiced|starred|role)\b/, /\b(?:played|portrayed|voiced|starred|role)\b/],
  [/\b(?:wrote|written|author)\b/, /\b(?:wrote|written|author)\b/],
  [/\b(?:directed|director)\b/, /\b(?:directed|director)\b/],
  [/\b(?:won|winner|award|champion)\b/, /\b(?:won|winner|awarded|award|champion)\b/],
  [/\b(?:capital)\b/, /\bcapital\b/],
  [/\b(?:means|translate|translated|meaning)\b/, /\b(?:means|translate|translated|meaning)\b/],
  [/\b(?:largest|smallest|highest|lowest|longest|shortest|oldest|youngest)\b/, /\b(?:largest|smallest|highest|lowest|longest|shortest|oldest|youngest)\b/],
  [/\b(?:invented|inventor|discovered|discoverer)\b/, /\b(?:invented|inventor|discovered|discoverer)\b/],
  [/\b(?:released|album|song|single|recorded)\b/, /\b(?:released|album|song|single|recorded)\b/],
  [/\b(?:located|country|city|state|where)\b/, /\b(?:located|country|city|state|province|region|in)\b/],
  [/\b(?:called|named|title|known as)\b/, /\b(?:called|named|title|known as)\b/],
  [/\b(?:feed|eat|diet)\b/, /\b(?:feed|feeds|eat|eats|diet)\b/],
  [/\b(?:how many|number of|times|year)\b/, /\b(?:number|times|year|years|season|seasons|episode|episodes)\b/]
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d),(?=\d)/, "").gsub(/[’‘`]/, "'")
    .gsub(/[-‐‑‒–—]/u, " ").gsub(/[^\p{L}\p{N}%+']+/u, " ")
    .gsub(/\s+/, " ").strip
end

def words(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
end

def fuzzy_include?(haystack_words, needle)
  return haystack_words.include?(needle) if needle.length < 6
  stem = needle[0, 6]
  haystack_words.any? { |word| word.start_with?(stem) }
end

all_english_questions = english.fetch("decisions").map { |row| row.fetch("original") }
token_df = Hash.new(0)
all_english_questions.each do |question|
  words(question.fetch("prompt")).uniq.each do |word|
    token_df[word] += 1 unless STOP_WORDS.include?(word)
  end
end

def arithmetic_result(prompt)
  match = prompt.to_s.match(/\A\s*([0-9\s()+\-*\/xX^.]+?)\s+(?:equals|=)\s+(?:what|which).*[?]?\s*\z/i)
  return nil unless match
  expression = match[1].tr("xX", "**").gsub("^", "**")
  return nil unless expression.match?(/\A[0-9\s()+\-*\/.]+\z/)
  Float(eval(expression, binding, __FILE__, __LINE__))
rescue StandardError, SyntaxError
  nil
end

def numeric_answer(value)
  Float(value.to_s.delete(","))
rescue ArgumentError, TypeError
  nil
end

def english_relation_pattern(prompt)
  normalized_prompt = normalized(prompt)
  row = RELATION_GROUPS.find { |question_pattern, _evidence_pattern| normalized_prompt.match?(question_pattern) }
  row && row[1]
end

def proper_anchor_words(prompt)
  sequences = prompt.to_s.scan(/(?:\b[A-Z][\p{L}'’-]*\b(?:\s+(?:of|the|and|with|in|on|[A-Z][\p{L}'’-]*)\b)*)/u)
  ignored = %w[
    according adult approximately during he how i if in it name out the these this what when
    where which who whose
  ]
  sequences.reverse_each do |sequence|
    candidate = words(sequence).reject { |word| ignored.include?(word) || STOP_WORDS.include?(word) }
    return candidate if candidate.any?
  end
  []
end

def numeric_question?(question)
  !numeric_answer(question.fetch("correct")).nil?
end

def numeric_relation_supported?(sentence, question)
  answer = normalized(question.fetch("correct"))
  compact = normalized(sentence)
  return false unless compact.match?(/(?:\A|\s)#{Regexp.escape(answer)}(?:\s|\z)/)
  return false if compact.match?(/\b(?:number|no)\s+#{Regexp.escape(answer)}\b/)
  prompt = normalized(question.fetch("prompt"))
  return true if prompt.match?(/\b(?:in what year|what year|when did|when was)\b/) && answer.match?(/\A\d{3,4}\z/)

  target_words = words(question.fetch("prompt")).reject do |word|
    STOP_WORDS.include?(word) || %w[approximately around many much number].include?(word)
  end
  sentence_words = words(sentence)
  target_words.count { |word| fuzzy_include?(sentence_words, word) } >= 2
end

def english_evidence_for(question, search_row, pages, token_df)
  answer_words = words(question.fetch("correct")).reject { |word| STOP_WORDS.include?(word) }
  return nil if answer_words.empty?
  prompt_words = words(question.fetch("prompt")).reject { |word| STOP_WORDS.include?(word) }
  subject_words = (prompt_words - answer_words).uniq.sort_by do |word|
    [token_df.fetch(word, 1_000_000), prompt_words.index(word), -word.length]
  end.first(8)
  relation_pattern = english_relation_pattern(question.fetch("prompt"))
  anchor_words = proper_anchor_words(question.fetch("prompt"))
  wrong_answers = question.fetch("wrong").map { |answer| words(answer).reject { |word| STOP_WORDS.include?(word) } }
  pageids = Array(search_row && search_row["checks"]).flat_map do |check|
    Array(check["results"]).map { |result| result["pageid"].to_s }
  end.uniq
  best = nil
  pageids.each do |pageid|
    page = pages[pageid]
    next unless page && page["content_fetched"]
    text = page.fetch("text", "").gsub(/\s+/, " ")
    sentences = text.split(/(?<=[.!?])\s+(?=[A-Z0-9])/)
    title_words = words(page.fetch("title", ""))
    sentences.each_with_index do |sentence, index|
      sentence_words = words(sentence)
      next unless answer_words.all? { |word| fuzzy_include?(sentence_words, word) }
      context = sentences[[index - 1, 0].max, 3].to_a.join(" ").gsub(/\s+/, " ").strip
      context_words = words(context)
      title_or_sentence_words = title_words + sentence_words
      next if anchor_words.any? && !anchor_words.all? { |word| fuzzy_include?(title_or_sentence_words, word) }
      next if numeric_question?(question) && !numeric_relation_supported?(sentence, question)
      wrong_present = wrong_answers.any? do |candidate|
        !candidate.empty? && candidate.all? { |word| fuzzy_include?(context_words, word) }
      end
      next if wrong_present
      overlap = subject_words.count { |word| fuzzy_include?(sentence_words, word) }
      title_overlap = subject_words.count { |word| fuzzy_include?(title_words, word) }
      relation = relation_pattern && normalized(sentence).match?(relation_pattern)
      exact = normalized(sentence).include?(normalized(question.fetch("correct")))
      score = 4 + [overlap, 4].min + [title_overlap, 1].min + (relation ? 2 : 0) + (exact ? 1 : 0)
      next if overlap < 2
      next if relation_pattern && !relation
      next if !relation_pattern && score < 10
      candidate = {
        "kind" => "English Wikipedia article text",
        "url" => page.fetch("url"), "title" => page.fetch("title"),
        "revision_id" => page["revision_id"], "revision_timestamp" => page["revision_timestamp"],
        "score" => score, "matched_sentence" => sentence[0, 900], "excerpt" => context[0, 1_200]
      }
      best = candidate if best.nil? || candidate.fetch("score") > best.fetch("score")
    end
  end
  best
end

def corrected_polish_prompt(prompt)
  prompt.to_s
    .sub(/ — do czego się go stosuje\?\z/, " — które z poniższych jest jednym z jego zastosowań?")
    .sub(/ — do jakiej klasy należy\?\z/, " — do której z poniższych klas jest zaliczany?")
    .sub(/ — z czego jest znana ta osoba\?\z/, " — z którym z poniższych osiągnięć jest związana ta osoba?")
    .sub(/ — kto był doktorantem tej osoby\?\z/, " — która z poniższych osób była doktorantem tej osoby?")
    .sub(/ — jaką dziedziną zajmowała się ta osoba\?\z/, " — którą z poniższych dziedzin zajmowała się ta osoba?")
end

def witcher_direct_relation?(prompt, evidence)
  text = normalized([evidence["field"], evidence["text"], evidence["context"]].join(" "))
  case prompt
  when /jakim rodzajem osady/
    text.match?(/\btyp\b|\b(?:wieś|miasto|osada|uczelnia|zamek|fort|port)\b/)
  when /gdzie znajduje się|gdzie mieści się siedziba|gdzie mieściła się siedziba/
    text.match?(/\bpołożenie\b|\bznajduje\b|\bleży\b|\bmieści\b/)
  when /gdzie mieszkała|w jakim państwie mieszkała/
    text.match?(/\bmiejsce zamieszkania\b|\bmieszka\w*\b|\bzamieszkiwa\w*\b/)
  when /czym zajmowała się|którym z poniższych zajęć/
    text.match?(/\bprofesja\b|\bzajmowa\w*\b|\bpracowa\w*\b/)
  when /jakiej rasy/
    text.match?(/\brasa\b|\b(?:człowiek|elf|elfka|krasnolud|krasnoludka|gnom|driada|wampir|smok)\w*\b/)
  when /w której .*książ|w którym .*opowiadaniu/
    text.match?(/\bwystępowanie\b|\bksiążk\w*\b|\bopowiadani\w*\b/)
  when /w której .*grze|w której grze/
    text.match?(/\bwystępowanie\b|\bgr[ayę]\b|\bwiedźmin\s*[1234]\b|\bgwint\b/)
  when /z którą .*postacią .*powiązana|kto był (?:kochankiem|ojcem|matką|bratem|siostrą|synem|córką)/
    text.match?(/\brelacje\b|\b(?:ojciec|matka|brat|siostra|syn|córka|kochanek|kochanka|krewn)\w*\b/)
  when /z jakiej szkoły wiedźmińskiej/
    text.match?(/\bszkoł\w*\b|\bwiedźmin\w*\b/)
  when /grup czarodziejów/
    text.match?(/\b(?:czarodziej|czarodziejka|mag|loża|kapituła|rada)\w*\b/)
  when /kto zarządzał|kto przewodził|kto władał|jakim państwem władała|ostatnim władcą/
    text.match?(/\b(?:zarządca|władca|król|królowa|książę|przywódca|dowódca)\w*\b/)
  when /jaki tytuł|który z poniższych tytułów/
    text.match?(/\btytuł\w*\b|\b(?:król|królowa|książę|księżna|hrabia|cesarz|cesarzowa)\w*\b/)
  when /jaki przydomek|przezwisk|przezwisko/
    text.match?(/\bpseudonim\w*\b|\bprzydomek\b|\bprzezwisk\w*\b|\binne nazwy\b/)
  when /z jakiego państwa pochodziła|jakiego kraju czarodziejem/
    text.match?(/\b(?:pochodzenie|narodowość|nilfgaardz|temersk|redańsk|kovirsk|aedirn)\w*\b/)
  when /do jakiej klasy potworów/
    text.match?(/\bklasyfikacja\b|\bklas\w*\b/)
  when /co jest skuteczne w walce/
    text.match?(/\bpodatnoś\w*\b|\bskuteczn\w*\b/)
  when /jak zginęła|gdzie zginęła|kto zabił/
    text.match?(/\b(?:śmierć|zgin|zabi|zamord|poleg)\w*\b/)
  when /gdzie urodziła|urodziła się w tym miejscu/
    text.match?(/\burodz\w*\b/)
  when /którą postać .*zagrała|dubbingowała/
    text.match?(/\baktor\w*\b|\bdubbing\w*\b|\bzagra\w*\b/)
  when /kto założył/
    text.match?(/\b(?:założyciel|twórca|założył)\w*\b/)
  when /jakie miasto jest stolicą/
    text.match?(/\bstolica\b/)
  else
    false
  end
end

def witcher_reviewed_question(question)
  prompt = question.fetch("prompt")
  revised = prompt.sub(/ — jakim rodzajem osady jest ta miejscowość\?\z/,
    " — jakiego rodzaju miejscem lub obiektem jest ta lokacja?")
  revised == prompt ? question : question.merge("prompt" => revised)
end

rechecks = []

english.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  question = row.fetch("original")
  restored = nil
  evidence = []
  method = nil
  if row.fetch("reason") == ENGLISH_UNCONFIRMED
    calculated = arithmetic_result(question.fetch("prompt"))
    expected = numeric_answer(question.fetch("correct"))
    if calculated && expected && (calculated - expected).abs < 1e-9
      restored = question
      method = "deterministic arithmetic verification"
      evidence << { "kind" => "deterministic calculation", "expression" => question.fetch("prompt"), "result" => calculated }
    else
      direct = english_evidence_for(question, english_search[row.fetch("id")], english_pages, token_df)
      if direct && direct.fetch("score") >= 9
        restored = question
        method = "direct relation confirmed in a revision-pinned English Wikipedia passage"
        evidence << direct
      end
    end
  end
  rechecks << {
    "pack_id" => "quiz.general.en", "id" => row.fetch("id"),
    "decision" => restored ? "restore" : "remain_removed",
    "reason" => restored ? method : "the second pass did not establish the exact asked relation with sufficient confidence",
    "previous_reason" => row.fetch("reason"), "original" => question, "reviewed" => restored,
    "evidence" => evidence.empty? ? Array(row["evidence"]) : evidence
  }
end

polish.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  question = row.fetch("original")
  reasons = Array(row["balteam_reasons"])
  direct = POLISH_DIRECT_STATUSES.include?(row.fetch("source_status"))
  schema_only = !reasons.empty? && reasons.all? { |reason| reason.match?(POLISH_SAFE_SCHEMA) }
  restore = question.fetch("category") == "chemia" && direct && schema_only
  reviewed = restore ? question.merge("prompt" => corrected_polish_prompt(question.fetch("prompt"))) : nil
  rechecks << {
    "pack_id" => "quiz.wikidata.pl", "id" => row.fetch("id"),
    "decision" => restore ? "restore" : "remain_removed",
    "reason" => if restore
      "the exact chemistry relation is confirmed independently by structured data and article text; non-exclusive wording is used where needed"
    else
      "the schema, answer set, time reference, entity type, or exact relation remains unsafe after the second review"
    end,
    "previous_reason" => row.fetch("reason"), "original" => question, "reviewed" => reviewed,
    "evidence" => Array(row["evidence"])
  }
end

witcher.fetch("decisions").select { |row| row.fetch("decision") == "remove" }.each do |row|
  question = row.fetch("original")
  supporting = Array(row["evidence"]).select do |item|
    Array(item["source_media"]).include?(row.fetch("medium")) &&
      witcher_direct_relation?(question.fetch("prompt"), item)
  end
  evidence_text = normalized(supporting.flat_map { |item| [item["text"], item["context"]] }.join(" "))
  wrong_supported = question.fetch("wrong").any? do |answer|
    answer_words = words(answer)
    !answer_words.empty? && answer_words.all? { |word| words(evidence_text).include?(word) }
  end
  restore = row.fetch("source_status") == "answer_in_other_context" && !supporting.empty? && !wrong_supported
  reviewed = restore ? witcher_reviewed_question(question) : nil
  rechecks << {
    "pack_id" => "quiz.witcher.pl", "id" => row.fetch("id"),
    "decision" => restore ? "restore" : "remain_removed",
    "reason" => if restore
      "the source for the assigned medium states the answer in direct relation to the subject and no distractor is supported by the same passage"
    else
      "the exact relation, medium, or uniqueness of the answer remains insufficiently established after the second review"
    end,
    "previous_reason" => row.fetch("reason"), "medium" => row.fetch("medium"),
    "original" => question, "reviewed" => reviewed,
    "evidence" => restore ? supporting : Array(row["evidence"])
  }
end

expected = english.fetch("decisions").count { |row| row.fetch("decision") == "remove" } +
  polish.fetch("decisions").count { |row| row.fetch("decision") == "remove" } +
  witcher.fetch("decisions").count { |row| row.fetch("decision") == "remove" }
raise "recheck coverage mismatch" unless rechecks.length == expected
raise "duplicate recheck IDs" unless rechecks.map { |row| [row.fetch("pack_id"), row.fetch("id")] }.uniq.length == rechecks.length

summary = rechecks.group_by { |row| row.fetch("pack_id") }.transform_values do |rows|
  rows.group_by { |row| row.fetch("decision") }.transform_values(&:length)
end
payload = {
  "generated" => Time.now.utc.iso8601, "source_audit" => audit_root,
  "question_count" => rechecks.length, "summary" => summary, "decisions" => rechecks
}
FileUtils.mkdir_p(output_root)
File.write(File.join(output_root, "ALL_RECHECK_DECISIONS.json"), JSON.generate(payload) + "\n", encoding: "UTF-8")
File.write(File.join(output_root, "RESTORED.json"), JSON.pretty_generate(
  "generated" => payload.fetch("generated"), "questions" => rechecks.select { |row| row.fetch("decision") == "restore" }
) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
