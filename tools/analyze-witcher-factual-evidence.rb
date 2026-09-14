# encoding: UTF-8
require "cgi"
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

source_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
decisions_path = ARGV[2] && File.expand_path(ARGV[2], Dir.pwd)
fallback_search_path = ARGV[3] && File.expand_path(ARGV[3], Dir.pwd)
pages = JSON.parse(File.read(source_path, encoding: "UTF-8")).fetch("pages")
fallback_searches = if fallback_search_path
  JSON.parse(File.read(fallback_search_path, encoding: "UTF-8")).fetch("searches")
else
  {}
end
questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
medium_data = GameRoomContent::WitcherPolishMediumData.load
media = medium_data.fetch("media")
prompts = medium_data.fetch("prompts")
separator = " #{[0x2014].pack('U')} "
title_metadata = if decisions_path
  JSON.parse(File.read(decisions_path, encoding: "UTF-8")).fetch("questions")
    .to_h { |row| [row.fetch("id"), row] }
else
  {}
end

FIELD_RULES = [
  [/czym zajmowała się|którym .*zajęć/, %w[profesja działalność]],
  [/gdzie mieszkała|w jakim państwie mieszkała/, ["miejsce zamieszkania", "miejsca zamieszkania", "położenie"]],
  [/w której książce|w której z poniższych książek/, %w[książki opowiadania]],
  [/w którym .*opowiadaniu|w którym z poniższych opowiadań/, %w[opowiadania książki]],
  [/z którą .*postacią .*powiązana|z którą z poniższych postaci była powiązana/, %w[relacje relacja powiązanie]],
  [/jakiej rasy/, %w[rasa]],
  [/gdzie znajduje się .*lokacja|gdzie znajduje się .*warownia|gdzie mieści się siedziba/, ["położenie", "miejsce zamieszkania", "kwatera główna", "siedziba"]],
  [/jak zginęła/, ["okoliczności śmierci"]],
  [/do jakiej klasy potworów/, %w[klasyfikacja]],
  [/w której grze|w której z poniższych gier/, ["gry", "występowanie", "występowanie w grze"]],
  [/jaki tytuł nosiła|który z poniższych tytułów|która postać nosiła ten tytuł/, %w[tytuły tytuł postacie]],
  [/w jakim państwie leży .*miejscowość|w jakim państwie leży to miasto|na terenie jakiego państwa płynie/, %w[państwo zależne]],
  [/gdzie zginęła|w jakiej miejscowości .*zmarła|w którym roku zmarła/, ["data i miejsce śmierci"]],
  [/w jakim państwie zmarła|który czarodziej .*zmarła w tym miejscu/, ["data i miejsce śmierci"]],
  [/co jest skuteczne w walce/, %w[podatności]],
  [/kto zarządzał .*miejscowością/, %w[zarządca władca właściciel]],
  [/jakim rodzajem osady/, %w[typ rodzaj]],
  [/jaki przydomek|którym .*przezwisk|która postać .*przezwisko/, ["pseudonimy", "pseudonim", "inne nazwy", "postacie"]],
  [/jakim państwem władała|kto władał tym państwem|ostatnim władcą/, ["władca", "ostatni władca", "tytuły", "ważne postacie"]],
  [/do której .*grup czarodziejów/, %w[przynależność afiliacja relacje]],
  [/jaką ingrediencję/, %w[ingrediencje łup składniki]],
  [/z jakiego państwa pochodzi ten ród|z jakiego państwa pochodziła ta postać/, %w[państwo narodowość pochodzenie]],
  [/gdzie urodziła/, ["data i miejsce urodzenia"]],
  [/w jakim państwie urodziła|w jakiej miejscowości .*urodziła|który czarodziej .*urodziła się w tym miejscu/, ["data i miejsce urodzenia"]],
  [/z jakiej szkoły wiedźmińskiej/, %w[przynależność afiliacja profesja]],
  [/czym żywi się/, %w[odżywianie]],
  [/jaka moneta/, %w[moneta]],
  [/kto przewodził/, ["przywódca/przywódcy", "przywódca", "lider", "dowódca"]],
  [/gdzie występuje ta bestia/, ["miejsca występowania", "występowanie"]],
  [/jakiego kraju czarodziejem/, %w[narodowość pochodzenie państwo]],
  [/jaki ustrój/, %w[ustrój]],
  [/jakie miasto jest stolicą/, %w[stolica]],
  [/którą postać .*dubbingowała|którą postać .*zagrała/, %w[postacie aktor]],
  [/którą postać .*audiobookach|którą postać .*słuchowiskach/, %w[postacie aktor]],
  [/kto .*zagrał lub dubbingował/, %w[aktor]],
  [/jaką religię|jakiego wyznania/, %w[religia]],
  [/jakim językiem/, %w[język]],
  [/kto .*założył|kto był założycielem/, %w[założyciel twórca twórca\/twórcy]],
  [/kiedy .*założona|w którym roku .*założona/, ["data założenia", "założenie"]],
  [/jak nazywa się stolica/, %w[stolica]],
  [/jakiego rodzaju .*rzeka|jakim rodzajem .*rzeka/, %w[rodzaj]],
  [/do jakiej organizacji należała/, %w[przynależność afiliacja relacje]],
  [/jaki kolor włosów/, ["kolor włosów"]],
  [/jaki kolor oczu/, ["kolor oczu"]],
  [/kto zabił tę postać/, ["okoliczności śmierci"]],
  [/w jakim regionie leży/, %w[region położenie]],
  [/gdzie mieściła się siedziba .*szkoły|gdzie mieściła się siedziba .*organizacji/, ["kwatera główna", "siedziba", "położenie"]],
  [/który czarodziej .*mieszkała w tym miejscu/, ["miejsce zamieszkania", "miejsca zamieszkania"]],
  [/który czarodziej .*urodziła się w tym miejscu/, ["data i miejsce urodzenia"]],
  [/który czarodziej .*zmarła w tym miejscu/, ["data i miejsce śmierci"]],
  [/w którym roku urodziła/, ["data i miejsce urodzenia"]],
  [/w którym roku (?:powstała|założono)/, ["data założenia", "założenie", "powstanie"]],
  [/w którym roku rozwiązano/, ["data rozwiązania", "rozwiązanie"]],
  [/kto był (?:ojcem|matką|bratem|siostrą|córką|synem|uczniem|uczennicą|mistrzem|mentorką|kochankiem|kochanką|przyjacielem|przyjaciółką)/, ["relacje", "rodzina"]],
  [/w jakim państwie znajdowała się ta lokacja/, ["państwo", "położenie"]],
  [/w jakiej miejscowości lub lokacji mieszkała/, ["miejsce zamieszkania", "miejsca zamieszkania"]]
].freeze

MEDIUM_FIELDS = {
  "g" => ["gry", "występowanie w grze"],
  "b" => ["książki", "opowiadania"],
  "s" => ["filmy"]
}.freeze

BOOK_TITLES = /ostatnie życzenie|miecz przeznaczenia|krew elfów|czas pogardy|chrzest ognia|wieża jaskółki|pani jeziora|sezon burz|rozdroże kruków|przypis książka/i
GAME_TITLES = /wiedźmin\s*(?:\(gra|[123]\b)|zabójcy królów|dziki gon|serca z kamienia|krew i wino|gwint|wojna krwi|thronebreaker/i
SCREEN_TITLES = /netflix|serial|film|zmora wilka|syreny z głębin/i

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/\{\{[^{}]*\|([^{}|]+)\}\}/, '\\1')
    .gsub(/<[^>]+>/, " ").gsub(/[[:space:]]+/, " ").strip
end

def expected_fields(suffix)
  row = FIELD_RULES.find { |pattern, _fields| suffix.match?(pattern) }
  row ? row[1] : []
end

def parse_page(wikitext)
  named_refs = {}
  wikitext.to_s.scan(/<ref\b[^>]*\bname\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s\/>]+))[^>]*>(.*?)<\/ref>/im) do |double, single, bare, body|
    name = double || single || bare
    named_refs[name] = body.to_s.gsub(/\s+/, " ").strip unless name.to_s.empty?
  end
  heading = nil
  current_field = nil
  in_infobox = false
  template_depth = 0
  lines = wikitext.to_s.lines
  parsed = []
  lines.each_with_index do |line, index|
    if (heading_match = line.match(/^\s*={2,6}\s*(.+?)\s*={2,6}\s*$/))
      heading = heading_match[1]
      current_field = nil
    end
    if !in_infobox && line.match?(/\A\s*\{\{[^\n]*(?:infoboks|infobox)/i)
      in_infobox = true
      template_depth = 0
    end
    if in_infobox && (field_match = line.match(/^\s*\|\s*([^=|]+?)\s*=\s*(.*)$/)) && template_depth <= 1
      current_field = field_match[1].strip.downcase
    elsif !in_infobox
      current_field = nil
    end
    line_text = line.strip
    context = lines[[index - 1, 0].max, 3].to_a.join(" ").strip
    referenced = line_text.scan(/<ref\b[^>]*\bname\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s\/>]+))[^>]*\/>/i)
      .map { |double, single, bare| named_refs[double || single || bare] }.compact
    provenance = ([line_text] + referenced).join(" ")
    context = ([context] + referenced).join(" ") unless referenced.empty?
    parsed << {
      "line" => index + 1,
      "field" => current_field,
      "heading" => heading,
      "text" => line_text[0, 700],
      "provenance" => provenance[0, 1800],
      "context" => context[0, 1800]
    }
  ensure
    if in_infobox
      template_depth += line.scan(/\{\{/).length
      template_depth -= line.scan(/\}\}/).length
      if template_depth <= 0
        in_infobox = false
        current_field = nil
      end
    end
  end
  parsed
end

def page_medium_fields(parsed)
  present = []
  MEDIUM_FIELDS.each do |medium, names|
    present << medium if parsed.any? { |row| names.include?(row["field"]) && !normalized(row["text"]).empty? }
  end
  parsed.select { |row| row["field"] == "występowanie" }.each do |row|
    text = row["provenance"]
    present << "g" if text.match?(GAME_TITLES)
    present << "b" if text.match?(BOOK_TITLES)
    present << "s" if text.match?(SCREEN_TITLES)
  end
  present.uniq
end

def medium_signal?(text, medium)
  case medium
  when "g" then text.match?(GAME_TITLES)
  when "b" then text.match?(BOOK_TITLES)
  when "s" then text.match?(SCREEN_TITLES)
  else false
  end
end

decisions = questions.map do |question|
  id = question.fetch("id")
  prompt = prompts.fetch(id, question.fetch("prompt"))
  title, suffix = prompt.split(separator, 2)
  title = title.to_s.strip
  suffix = suffix.to_s.strip
  metadata = title_metadata[id] || {}
  subject_title = metadata.fetch("subject_wiki_title", title).to_s.strip
  answer_title = metadata.fetch("correct_wiki_title", question.fetch("correct")).to_s.strip
  medium = media.fetch(id)
  page = pages[subject_title] || pages[title]
  answer_page = pages[answer_title]
  malformed = question.fetch("correct").match?(/[\[\]]|dubbing\s*:\s*\)|\A\W*\z/i) || prompt.match?(/\A\(|[\[\]]/)
  fields = expected_fields(suffix)
  subject_page_missing = page.nil? || page["missing"]
  page_rows = []
  unless subject_page_missing
    parsed = parse_page(page.fetch("wikitext", ""))
    page_rows << ["subject", page, parsed, question.fetch("correct"), nil, page_medium_fields(parsed)]
  end
  if answer_page && !answer_page["missing"] && answer_title.casecmp?(subject_title) == false
    parsed = parse_page(answer_page.fetch("wikitext", ""))
    page_rows << ["answer", answer_page, parsed, subject_title, nil, page_medium_fields(parsed)]
  end
  existing_pages = page_rows.map { |_role, source_page, *_rest| source_page["pageid"] || source_page["title"] }.compact
  Array(fallback_searches.dig(id, "results")).first(3).each do |result|
    fallback_page = pages[result["title"]]
    next if fallback_page.nil? || fallback_page["missing"]
    identity = fallback_page["pageid"] || fallback_page["title"]
    next if existing_pages.include?(identity)

    fallback_title = normalized(fallback_page["title"])
    subject_norm = normalized(subject_title)
    answer_norm = normalized(answer_title)
    if !subject_norm.empty? && fallback_title.include?(subject_norm)
      sought = question.fetch("correct")
      required = nil
    elsif !answer_norm.empty? && fallback_title.include?(answer_norm)
      sought = subject_title
      required = nil
    else
      sought = question.fetch("correct")
      required = subject_title
    end
    parsed = parse_page(fallback_page.fetch("wikitext", ""))
    page_rows << ["fallback", fallback_page, parsed, sought, required, page_medium_fields(parsed)]
    existing_pages << identity
  end
  page_missing = page_rows.empty?
  occurrences = page_rows.flat_map do |role, source_page, parsed, sought, required, source_media|
    needle = normalized(sought)
    required_needle = normalized(required)
    parsed.select do |row|
      text = normalized([row.fetch("text"), row.fetch("provenance")].join(" "))
      !needle.empty? && text.include?(needle) && (required_needle.empty? || text.include?(required_needle))
    end.map do |row|
      row.merge(
        "source_role" => role,
        "source_title" => source_page["title"],
        "source_pageid" => source_page["pageid"],
        "source_revision_id" => source_page["revision_id"],
        "sought_value" => sought,
        "source_media" => source_media
      )
    end
  end
  medium_fields_present = page_rows.flat_map { |_role, _page, _parsed, _sought, _required, source_media| source_media }.uniq
  field_matches = occurrences.select { |row| fields.include?(row["field"]) }
  medium_occurrences = occurrences.select do |row|
    medium_signal?([row["heading"], row["provenance"]].compact.join(" "), medium)
  end
  exclusive_medium = field_matches.any? { |row| row.fetch("source_media") == [medium] }
  direct_medium_field = field_matches.any? { |row| MEDIUM_FIELDS.fetch(medium).include?(row["field"]) }
  same_occurrence_medium = field_matches.any? do |row|
    medium_signal?([row["heading"], row["provenance"]].compact.join(" "), medium)
  end
  relation_proven = !field_matches.empty?
  medium_proven = direct_medium_field || exclusive_medium || same_occurrence_medium
  proven_media = MEDIUM_FIELDS.keys.select do |candidate_medium|
    direct = field_matches.any? { |row| MEDIUM_FIELDS.fetch(candidate_medium).include?(row["field"]) }
    same = field_matches.any? do |row|
      medium_signal?([row["heading"], row["provenance"]].compact.join(" "), candidate_medium)
    end
    direct || same || field_matches.any? { |row| row.fetch("source_media") == [candidate_medium] }
  end
  alternative_field_evidence = if fields.any? { |field| %w[relacje relacja rodzina powiązanie postacie].include?(field) }
    []
  else
    Array(question["wrong"]).filter_map do |answer|
      needle = normalized(answer)
      matches = page_rows.flat_map do |role, source_page, parsed, _sought, _required, source_media|
        next [] unless role == "subject"
        parsed.select do |row|
          fields.include?(row["field"]) && normalized([row.fetch("text"), row.fetch("provenance")].join(" ")).include?(needle)
        end.map do |row|
          row.merge(
            "source_role" => role,
            "source_title" => source_page["title"],
            "source_pageid" => source_page["pageid"],
            "source_revision_id" => source_page["revision_id"],
            "sought_value" => answer,
            "source_media" => source_media
          )
        end
      end
      { "answer" => answer, "evidence" => matches.first(12) } unless matches.empty?
    end
  end
  status = if malformed
    "malformed"
  elsif page_missing
    "missing_page"
  elsif fields.empty?
    occurrences.empty? ? "answer_not_found" : "unmapped_relation"
  elsif occurrences.empty?
    alternative_field_evidence.length == 1 ? "correction_candidate" : "answer_not_found"
  elsif !relation_proven
    alternative_field_evidence.length == 1 ? "correction_candidate" : "answer_in_other_context"
  elsif !medium_proven
    "medium_not_proven"
  else
    "verified_candidate"
  end
  {
    "id" => id,
    "medium" => medium,
    "status" => status,
    "prompt" => prompt,
    "correct" => question.fetch("correct"),
    "requested_title" => title,
    "subject_wiki_title" => subject_title,
    "correct_wiki_title" => answer_title,
    "resolved_title" => page && page["title"],
    "pageid" => page && page["pageid"],
    "revision_id" => page && page["revision_id"],
    "revision_timestamp" => page && page["revision_timestamp"],
    "answer_pageid" => answer_page && answer_page["pageid"],
    "answer_revision_id" => answer_page && answer_page["revision_id"],
    "expected_fields" => fields,
    "medium_fields_present" => medium_fields_present,
    "exclusive_medium" => exclusive_medium,
    "proven_media" => proven_media,
    "suggested_correct" => alternative_field_evidence.length == 1 ? alternative_field_evidence.first.fetch("answer") : nil,
    "alternative_field_evidence" => alternative_field_evidence,
    "field_evidence" => field_matches.first(12),
    "medium_evidence" => medium_occurrences.first(12),
    "other_occurrences" => occurrences.reject { |row| field_matches.include?(row) || medium_occurrences.include?(row) }.first(12)
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "source" => source_path,
  "question_count" => questions.length,
  "summary" => decisions.group_by { |row| row.fetch("medium") }.transform_values do |rows|
    rows.group_by { |row| row.fetch("status") }.transform_values(&:length)
  end,
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
