# encoding: UTF-8
require "cgi"
require "json"

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/[^\p{L}\p{N}]+/u, " ").gsub(/\s+/, " ").strip
end

def field_value(wikitext, field)
  match = wikitext.to_s.match(/\|\s*#{Regexp.escape(field)}\s*=\s*(.*?)(?=\|\s*[\p{L} _\/]+\s*=|\}\})/mi)
  match && match[1]
end

def clean_field(value)
  value.to_s
    .gsub(/<ref\b[^>]*>.*?<\/ref>|<ref\b[^>]*\/>/mi, "")
    .gsub(/<small>.*?<\/small>/mi, "")
    .gsub(/<br\s*\/?\s*>/i, "; ")
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/\{\{[^{}]*\|([^{}|]+)\}\}/, '\\1')
    .gsub(/[\r\n*]+/, " ").gsub(/''+/, "")
    .gsub(/\s*;\s*/, "; ").gsub(/\s+/, " ").strip
end

rows = analysis.fetch("decisions").filter_map do |row|
  next unless Array(row["expected_fields"]).include?("profesja")
  page = pages[row["subject_wiki_title"]] || pages[row["requested_title"]]
  next unless page && !page["missing"]
  raw = field_value(page["wikitext"], "profesja")
  clean = clean_field(raw)
  next if clean.empty?
  current = normalized(row.fetch("correct"))
  exact = clean.split(";").map { |part| normalized(part) }.include?(current)
  contains = normalized(clean).include?(current)
  {
    "id" => row.fetch("id"),
    "prompt" => row.fetch("prompt"),
    "current_correct" => row.fetch("correct"),
    "profession" => clean,
    "exact" => exact,
    "contains" => contains,
    "page_title" => page["title"],
    "pageid" => page["pageid"],
    "revision_id" => page["revision_id"]
  }
end

payload = {
  "question_count" => rows.length,
  "not_exact_count" => rows.count { |row| !row.fetch("exact") },
  "not_contained_count" => rows.count { |row| !row.fetch("contains") },
  "questions" => rows
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.reject { |key, _value| key == "questions" })
