# encoding: UTF-8
require "cgi"
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

pages_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")
questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
prompts = GameRoomContent::WitcherPolishMediumData.load.fetch("prompts")

ROLE_PATTERNS = {
  /kto był ojcem/ => %w[ojciec],
  /kto był matką/ => %w[matka],
  /kto był bratem/ => %w[brat],
  /kto był siostrą/ => %w[siostra],
  /kto był córką/ => %w[córka],
  /kto był synem/ => %w[syn],
  /kto był uczniem/ => %w[uczeń uczen],
  /kto był uczennicą/ => %w[uczennica],
  /kto był mistrzem/ => %w[mistrz mentor],
  /kto był mentorką/ => %w[mentorka mistrzyni],
  /kto był kochankiem/ => %w[kochanek],
  /kto był kochanką/ => %w[kochanka],
  /kto był przyjacielem/ => %w[przyjaciel],
  /kto był przyjaciółką/ => %w[przyjaciółka]
}.freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/<[^>]+>/, " ").gsub(/[^\p{L}\p{N}]+/u, " ").gsub(/\s+/, " ").strip
end

def infobox_field(wikitext, name)
  match = wikitext.to_s.match(/^\s*\|\s*#{Regexp.escape(name)}\s*=\s*(.*?)(?=^\s*\|[^=]+=|^\s*\}\})/mi)
  match && match[1].to_s.strip
end

def relation_entries(value)
  value.to_s.gsub(/<br\s*\/?>/i, "\n").lines.flat_map do |line|
    links = line.scan(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/)
    links.map.with_index do |(target, display), index|
      start = line.index("[[#{target}") || 0
      tail = line[(start + target.length)..].to_s
      role = tail[/\(([^)]+)\)/, 1].to_s
      {
        "target" => target.strip,
        "display" => (display || target).strip,
        "role" => normalized(role),
        "source_fragment" => line.strip[0, 500],
        "ordinal" => index
      }
    end
  end
end

decisions = questions.filter_map do |question|
  prompt = prompts.fetch(question.fetch("id"), question.fetch("prompt"))
  role_row = ROLE_PATTERNS.find { |pattern, _roles| normalized(prompt).match?(pattern) }
  next if role_row.nil?

  requested_roles = role_row[1]
  title = prompt.split(" — ", 2).first.to_s.strip
  page = pages[title]
  field = page && !page["missing"] ? infobox_field(page.fetch("wikitext", ""), "relacje") : nil
  entries = relation_entries(field)
  answer = normalized(question.fetch("correct"))
  current = entries.select do |entry|
    [entry.fetch("target"), entry.fetch("display")].any? { |name| normalized(name) == answer }
  end
  matching = entries.select do |entry|
    requested_roles.any? { |role| entry.fetch("role").include?(normalized(role)) }
  end
  status = if field.nil? || entries.empty?
    "no_structured_relation_source"
  elsif current.any? { |entry| matching.include?(entry) }
    "verified"
  elsif matching.length == 1
    "correction_unique"
  elsif matching.length > 1
    "correction_ambiguous"
  else
    "role_not_found"
  end
  {
    "id" => question.fetch("id"),
    "status" => status,
    "prompt" => prompt,
    "correct" => question.fetch("correct"),
    "requested_roles" => requested_roles,
    "page_title" => page && page["title"],
    "pageid" => page && page["pageid"],
    "revision_id" => page && page["revision_id"],
    "current_entries" => current,
    "matching_entries" => matching,
    "field" => field
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
