# encoding: UTF-8
require "cgi"
require "json"
require "time"

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
search_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(3), Dir.pwd)
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
searches = JSON.parse(File.read(search_path, encoding: "UTF-8")).fetch("searches")
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")

BOOK_TITLES = /ostatnie życzenie|miecz przeznaczenia|krew elfów|czas pogardy|chrzest ognia|wieża jaskółki|pani jeziora|sezon burz|rozdroże kruków|przypis książka/i
GAME_TITLES = /wiedźmin\s*(?:\(gra|[123]\b)|zabójcy królów|dziki gon|serca z kamienia|krew i wino|gwint|wojna krwi|thronebreaker/i
SCREEN_TITLES = /netflix|serial|film|the witcher|zmora wilka|syreny z głębin/i

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/\{\{[^{}]*\|([^{}|]+)\}\}/, '\\1')
    .gsub(/<[^>]+>/, " ").gsub(/[^\p{L}\p{N}]+/u, " ").gsub(/\s+/, " ").strip
end

def medium_signal?(text, medium)
  case medium
  when "g" then text.match?(GAME_TITLES)
  when "b" then text.match?(BOOK_TITLES)
  when "s" then text.match?(SCREEN_TITLES)
  else false
  end
end

def named_references(wikitext)
  wikitext.to_s.scan(/<ref\b[^>]*\bname\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s\/>]+))[^>]*>(.*?)<\/ref>/im)
    .to_h do |double, single, bare, body|
      [double || single || bare, body.to_s.gsub(/\s+/, " ").strip]
    end
end

def occurrence_contexts(page, subject, answer)
  wikitext = page.fetch("wikitext", "")
  refs = named_references(wikitext)
  lines = wikitext.lines
  subject_norm = normalized(subject)
  answer_norm = normalized(answer)
  title_norm = normalized(page["title"])
  subject_page = title_norm == subject_norm
  answer_page = title_norm == normalized(answer)
  lines.each_with_index.filter_map do |line, index|
    line_norm = normalized(line)
    related = if subject_page
      !answer_norm.empty? && line_norm.include?(answer_norm)
    elsif answer_page
      !subject_norm.empty? && line_norm.include?(subject_norm)
    else
      !subject_norm.empty? && !answer_norm.empty? && line_norm.include?(subject_norm) && line_norm.include?(answer_norm)
    end
    next unless related

    context = lines[[index - 1, 0].max, 3].to_a.join(" ").strip
    referenced = line.scan(/<ref\b[^>]*\bname\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s\/>]+))[^>]*\/>/i)
      .map { |double, single, bare| refs[double || single || bare] }.compact
    context = ([context] + referenced).join(" ")
    { "line" => index + 1, "context" => context[0, 1800] }
  end
end

decisions = analysis.fetch("decisions").reject { |row| row.fetch("status") == "verified_candidate" }.map do |row|
  search = searches[row.fetch("id")]
  evidence = Array(search && search["results"]).first(3).flat_map do |result|
    page = pages[result["title"]]
    next [] if page.nil? || page["missing"]

    occurrence_contexts(page, row.fetch("subject_wiki_title"), row.fetch("correct_wiki_title")).map do |hit|
      media = %w[g b s].select { |medium| medium_signal?(hit.fetch("context"), medium) }
      hit.merge(
        "title" => page["title"],
        "pageid" => page["pageid"],
        "revision_id" => page["revision_id"],
        "revision_timestamp" => page["revision_timestamp"],
        "url" => result["url"],
        "media" => media
      )
    end
  end
  target = row.fetch("medium")
  matching = evidence.select { |hit| hit.fetch("media").include?(target) }
  alternatives = evidence.flat_map { |hit| hit.fetch("media") }.uniq - [target]
  status = if !matching.empty?
    "verified_fallback_candidate"
  elsif alternatives.length == 1
    "other_medium_candidate"
  else
    "not_proven"
  end
  {
    "id" => row.fetch("id"),
    "status" => status,
    "prompt" => row.fetch("prompt"),
    "correct" => row.fetch("correct"),
    "medium" => target,
    "alternative_media" => alternatives,
    "evidence" => (matching.empty? ? evidence : matching).first(8)
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
