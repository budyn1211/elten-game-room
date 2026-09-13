# encoding: UTF-8
require "fileutils"
require "digest"
require "json"
require "set"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")

prior_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
wiki_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
output_dir = ARGV[2] == nil ? nil : File.expand_path(ARGV[2], Dir.pwd)
runtime_data_path = ARGV[3] == nil ? nil : File.expand_path(ARGV[3], Dir.pwd)

questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
prior_rows = JSON.parse(File.read(prior_path, encoding: "UTF-8")).fetch("questions")
prior = prior_rows.to_h { |row| [row.fetch("id"), row] }
wiki = JSON.parse(File.read(wiki_path, encoding: "UTF-8")).fetch("titles")

raise "question/map count mismatch" unless questions.length == prior.length
raise "duplicate question ids" unless questions.map { |question| question.fetch("id") }.uniq.length == questions.length
raise "map ids do not match the pack" unless questions.map { |question| question.fetch("id") }.sort == prior.keys.sort

MEDIA_LABELS = { "g" => "gry", "b" => "książki", "s" => "ekranizacje" }.freeze
DETAIL_SET_LABELS = {
  "g" => "Wiedźmin — gry",
  "b" => "Wiedźmin — książki i ekranizacje",
  "s" => "Wiedźmin — książki i ekranizacje"
}.freeze
CAST_OVERRIDES = {
  "2249d6cc4686" => ["g", "rola głosowa w grze zweryfikowana osobno"],
  "b331b1152434" => ["s", "rola w ekranizacji zweryfikowana osobno"],
  "d4208cd6207f" => ["s", "dubbing serialu zweryfikowany osobno"],
  "24fc3ba2b640" => ["s", "dubbing serialu zweryfikowany osobno"],
  "66104f2c95d0" => ["s", "rola w serialu zweryfikowana osobno"]
}.freeze
PROMPT_SUBJECT_CORRECTIONS = {
  "21751434e7bf" => "Agata Gawrońska-Bauman",
  "326fd96dd378" => "Anna Kerth",
  "a3e9724ecd2b" => "Rochelle Rose",
  "d4208cd6207f" => "Paweł Ciołkosz"
}.freeze

BOOK_CATEGORY = Regexp.union(
  /książ/i,
  /literatur/i,
  /komiks/i,
  /notatek sapkowskiego/i,
  /postacie z (?:rozdroża kruków|pani jeziora|wieży jaskółki|czasu pogardy|chrztu ognia|krwi elfów|miecz przeznaczenia|ostatnie życzenie|sezonu burz|coś się kończy, coś się zaczyna|szponów i kłów)/i
)
SCREEN_CATEGORY = Regexp.union(
  /filmu i serialu/i,
  /wiedźmina netflixa/i,
  /postacie z the witcher\z/i,
  /serial/i,
  /netflix/i,
  /zmora wilka/i,
  /syreny z głębin/i,
  /ekranizac/i
)
GAME_CATEGORY = Regexp.union(
  /\bw grze\b/i,
  /\bz gry\b/i,
  /wiedźmin 2/i,
  /wiedźmin 3/i,
  /krwi i winie/i,
  /sercach z kamienia/i,
  /gwint/i,
  /wojna krwi/i,
  /pogromca potworów/i,
  /battle arena/i,
  /ceny neutralności/i,
  /efektu ubocznego/i,
  /córki płomienia/i,
  /gra przygodowa/i,
  /gry wyobraźni/i,
  /gry fabularnej/i,
  /modyfikacji/i,
  /akt (?:pierwszy|drugi|trzeci)/i
)

def split_prompt(prompt)
  subject, detail = prompt.to_s.split(" — ", 2)
  [subject.to_s.strip, detail.to_s.strip]
end

def prior_medium(row)
  case row.fetch("category")
  when "gry" then "g"
  when "ekranizacje" then "s"
  else "b"
  end
end

def category_media(record)
  categories = Array(record && record["categories"])
  media = Set.new
  categories.each do |category|
    name = category.sub(/\AKategoria:/i, "")
    media << "s" if SCREEN_CATEGORY.match?(name)
    media << "b" if BOOK_CATEGORY.match?(name)
    media << "g" if GAME_CATEGORY.match?(name)
    media << "g" if name.casecmp?("Postacie z Wiedźmin")
  end
  media
end

def direct_medium(question, prior_row)
  override = CAST_OVERRIDES[question.fetch("id")]
  return override if override != nil
  text = question.fetch("prompt").downcase
  return ["s", "jawne odniesienie do ekranizacji w pytaniu"] if text.match?(/serial|netflix|film|ekranizac/)
  return ["b", "jawne odniesienie do książki lub nagrania książki w pytaniu"] if text.match?(/książ|opowiad|powieś|słuchowisk|audiobook/)
  return ["g", "jawne odniesienie do gry w pytaniu"] if text.match?(/\bgrze\b|\bgier\b|\bgrach\b|\bgry\b|grow(?:a|e|y|ego|ej)|gwint/)
  return ["g", "pytanie o mechanikę growego bestiariusza"] if text.match?(/do jakiej klasy potworów|co jest skuteczne w walce|jaką ingrediencję pozyskuje/)

  if text.include?("zagrała lub dubbingowała") || text.include?("zagrał lub dubbingował")
    reason = prior_row.fetch("reason", "").downcase
    return ["g", "zweryfikowana rola głosowa w grze"] if reason.include?("wersją gry")
    return ["s", "zweryfikowana obsada ekranizacji"] if reason.include?("obsady ekranizacji")
    return ["b", "zweryfikowana obsada audiobooka lub słuchowiska"] if reason.include?("słuchowiskiem")
    return [prior_medium(prior_row), "obsada przypisana po kontroli medium roli"]
  end
  nil
end

def explicit_context?(prompt)
  prompt.downcase.match?(/serial|netflix|film|ekranizac|książ|opowiad|powieś|słuchowisk|audiobook|\bgrze\b|\bgier\b|\bgrach\b|\bgry\b|grow(?:a|e|y|ego|ej)|gwint/)
end

def clarify_prompt(prompt, medium, basis)
  return prompt if explicit_context?(prompt)
  subject, detail = split_prompt(prompt)
  return prompt if detail.empty?

  if detail.match?(/\Aktórą postać .*zagrała lub dubbingowała|\Aktórą postać .*zagrał lub dubbingował/i)
    detail = case medium
    when "g"
      "którą postać z gier z serii Wiedźmin dubbingowała ta osoba?"
    when "s"
      "którą postać w ekranizacjach Wiedźmina zagrała ta osoba?"
    else
      phrase = basis.include?("audiobook") ? "w audiobookach lub słuchowiskach Wiedźmina" : "w książkowym uniwersum Wiedźmina"
      "którą postać #{phrase} dubbingowała ta osoba?"
    end
    return "#{subject} — #{detail}"
  end

  qualifier = case medium
  when "g" then "w grach z serii Wiedźmin"
  when "s" then "w ekranizacjach Wiedźmina"
  else "w książkach z cyklu Wiedźmin"
  end
  if detail.end_with?("?")
    "#{subject} — #{detail[0...-1]} #{qualifier}?"
  else
    "#{subject} — #{detail} #{qualifier}"
  end
end

review = questions.map do |question|
  id = question.fetch("id")
  original_prompt = question.fetch("prompt")
  prompt = original_prompt
  corrected_subject = PROMPT_SUBJECT_CORRECTIONS[id]
  if corrected_subject != nil
    _old_subject, detail = split_prompt(prompt)
    prompt = "#{corrected_subject} — #{detail}"
  end
  subject, = split_prompt(prompt)
  correct = question.fetch("correct").to_s.strip
  prior_row = prior.fetch(id)
  prior_code = prior_medium(prior_row)
  subject_record = wiki[subject]
  correct_record = wiki[correct]
  subject_media = category_media(subject_record)
  correct_media = category_media(correct_record)
  direct = direct_medium(question, prior_row)

  if direct != nil
    medium, basis = direct
  elsif subject_media.length == 1
    medium = subject_media.first
    basis = "jednoznaczne kategorie źródłowe podmiotu"
  elsif correct_media.length == 1 && subject_media.empty?
    medium = correct_media.first
    basis = "jednoznaczne medium poprawnej odpowiedzi"
  elsif subject_media.length > 1 && correct_media.length == 1 && prompt.match?(/z którą|która postać|kto z poniższych osób/i)
    medium = correct_media.first
    basis = "fakt rozstrzygnięty przez medium poprawnej odpowiedzi przy podmiocie wspólnym"
  elsif subject_media.include?(prior_code)
    medium = prior_code
    basis = "mapa pomocnicza zgodna z kategoriami źródłowymi podmiotu"
  elsif correct_media.include?(prior_code)
    medium = prior_code
    basis = "mapa pomocnicza zgodna z kategoriami źródłowymi odpowiedzi"
  elsif !subject_media.empty?
    medium = subject_media.include?("b") ? "b" : subject_media.first
    basis = "ogólny fakt o podmiocie wielomedialnym; pierwszeństwo kanonu książkowego"
  elsif !correct_media.empty?
    medium = correct_media.include?("b") ? "b" : correct_media.first
    basis = "medium ustalone z kategorii źródłowych poprawnej odpowiedzi"
  else
    medium = prior_code
    basis = "mapa pomocnicza po kontroli treści i braku rozstrzygających kategorii źródłowych"
  end

  reviewed_prompt = clarify_prompt(prompt, medium, basis)
  {
    "id" => id,
    "medium" => MEDIA_LABELS.fetch(medium),
    "medium_code" => medium,
    "detailed_set" => DETAIL_SET_LABELS.fetch(medium),
    "basis" => basis,
    "prior_medium" => prior_row.fetch("category"),
    "prior_confidence" => prior_row.fetch("confidence"),
    "classification_changed" => medium != prior_code,
    "original_prompt" => original_prompt,
    "reviewed_prompt" => reviewed_prompt,
    "prompt_changed" => reviewed_prompt != prompt,
    "correct" => question.fetch("correct"),
    "subject_wiki_title" => subject_record && subject_record["title"],
    "correct_wiki_title" => correct_record && correct_record["title"]
  }
end

by_id = review.to_h { |row| [row.fetch("id"), row] }
raise "audit omitted questions" unless by_id.length == questions.length
raise "audit produced an invalid medium" unless review.all? { |row| MEDIA_LABELS.key?(row.fetch("medium_code")) }

medium_data = {
  "version" => 2,
  "source_question_count" => questions.length,
  "media" => review.to_h { |row| [row.fetch("id"), row.fetch("medium_code")] },
  "prompts" => review.filter_map do |row|
    next if !row.fetch("prompt_changed")
    [row.fetch("id"), row.fetch("reviewed_prompt")]
  end.to_h
}

summary = {
  "generated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "scope" => "classification and prompt disambiguation; answers were not fully fact-checked",
  "questions" => questions.length,
  "by_medium" => review.map { |row| row.fetch("medium") }.tally,
  "by_detailed_set" => review.map { |row| row.fetch("detailed_set") }.tally,
  "by_basis" => review.map { |row| row.fetch("basis") }.tally,
  "classification_changes_from_supplied_map" => review.count { |row| row.fetch("classification_changed") },
  "clarified_prompts" => review.count { |row| row.fetch("prompt_changed") },
  "unchanged_prompts" => review.count { |row| !row.fetch("prompt_changed") },
  "wiki_titles_checked" => wiki.length,
  "wiki_titles_found" => wiki.count { |_title, record| !record.fetch("missing") },
  "wiki_titles_missing" => wiki.count { |_title, record| record.fetch("missing") }
}

puts JSON.pretty_generate(summary)

if output_dir != nil
  FileUtils.mkdir_p(output_dir)
  File.write(File.join(output_dir, "SUMMARY.json"), JSON.pretty_generate(summary) + "\n", encoding: "UTF-8")
  File.write(File.join(output_dir, "ALL_DECISIONS.json"), JSON.pretty_generate({
    "summary" => summary,
    "source_map" => prior_path,
    "wiki_metadata" => wiki_path,
    "questions" => review.map { |row| row.reject { |key, _value| key == "medium_code" } }
  }) + "\n", encoding: "UTF-8")
  File.write(File.join(output_dir, "CHANGES_FROM_SUPPLIED_MAP.json"), JSON.pretty_generate({
    "summary" => {
      "count" => review.count { |row| row.fetch("classification_changed") },
      "from_to" => review.select { |row| row.fetch("classification_changed") }
        .map { |row| "#{row.fetch('prior_medium')} -> #{row.fetch('medium')}" }.tally
    },
    "questions" => review.select { |row| row.fetch("classification_changed") }
      .map { |row| row.reject { |key, _value| key == "medium_code" } }
  }) + "\n", encoding: "UTF-8")
  File.write(File.join(output_dir, "witcher-medium-data.json"), JSON.generate(medium_data), encoding: "UTF-8")
end

if runtime_data_path != nil
  payload = JSON.pretty_generate(medium_data)
  digest = Digest::SHA256.hexdigest(payload)
  delimiter = "WITCHER_MEDIUM_DATA_#{digest}"
  ruby_source = <<~RUBY
    # encoding: UTF-8
    # Generated by tools/audit-witcher-medium-split.rb; do not edit by hand.
    require "json"
    module GameRoomContent
      module WitcherPolishMediumData
        def self.load
          JSON.parse(<<'#{delimiter}')
    #{payload}
    #{delimiter}
        end
      end
    end
  RUBY
  FileUtils.mkdir_p(File.dirname(runtime_data_path))
  File.write(runtime_data_path, ruby_source, encoding: "UTF-8")
end
