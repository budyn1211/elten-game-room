# encoding: UTF-8
require "cgi"
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

source_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
source = JSON.parse(File.read(source_path, encoding: "UTF-8"))
pages = source.fetch("pages")
questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
medium_data = GameRoomContent::WitcherPolishMediumData.load
media = medium_data.fetch("media")
prompts = medium_data.fetch("prompts")
separator = " #{[0x2014].pack("U")} "

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/[[:space:]]+/, " ").strip
end

def occurrences(wikitext, answer)
  needle = normalized(answer)
  return [] if needle.empty?

  heading = nil
  current_field = nil
  in_infobox = false
  template_depth = 0
  rows = []
  wikitext.to_s.lines.each_with_index do |line, index|
    heading_match = line.match(/^\s*={2,6}\s*(.+?)\s*={2,6}\s*$/)
    if heading_match
      heading = heading_match[1]
      current_field = nil
    end
    if !in_infobox && line.match?(/\A\s*\{\{[^\n]*(?:infoboks|infobox)/i)
      in_infobox = true
      template_depth = 0
    end
    if in_infobox
      field_match = line.match(/^\s*\|\s*([^=|]+?)\s*=\s*(.*)$/)
      current_field = field_match[1].strip if field_match && template_depth <= 1
    else
      current_field = nil
    end
    next if !normalized(line).include?(needle)

    rows << {
      "line" => index + 1,
      "field" => current_field,
      "heading" => heading,
      "text" => line.strip[0, 500]
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
  rows
end

def medium_signals(page)
  haystack = normalized(Array(page["categories"]).join(" ") + "\n" + page["wikitext"].to_s)
  {
    "g" => !!(haystack =~ /wiedźmin \(gra|wiedźmin [123]:|gwint|wojna krwi|gra komputerowa|postacie z wiedźmin/),
    "b" => !!(haystack =~ /przypis książka|postacie z (ostatniego życzenia|miecza przeznaczenia|krwi elfów|czasu pogardy|chrztu ognia|wieży jaskółki|pani jeziora|sezonu burz|rozdroża kruków)|\|książki\s*=/),
    "s" => !!(haystack =~ /netflix|serial|film|zmora wilka|postacie z wiedźmin \(serial/)
  }
end

decisions = questions.map do |question|
  id = question.fetch("id")
  prompt = prompts.fetch(id, question.fetch("prompt"))
  title = prompt.split(separator, 2).first.to_s.strip
  page = pages[title]
  page_missing = page == nil || page["missing"]
  evidence = page_missing ? [] : occurrences(page.fetch("wikitext", ""), question.fetch("correct"))
  signals = page_missing ? { "g" => false, "b" => false, "s" => false } : medium_signals(page)
  malformed = question.fetch("correct").match?(/[\[\]]|dubbing\s*:\s*\)|\A\W*\z/i) ||
    prompt.match?(/\A\(|[\[\]]/)
  status = if malformed
    "malformed"
  elsif page_missing
    "missing_page"
  elsif evidence.empty?
    "answer_not_found"
  elsif !signals.fetch(media.fetch(id))
    "medium_not_proven"
  else
    "source_candidate"
  end
  {
    "id" => id,
    "medium" => media.fetch(id),
    "status" => status,
    "prompt" => prompt,
    "correct" => question.fetch("correct"),
    "requested_title" => title,
    "resolved_title" => page && page["title"],
    "pageid" => page && page["pageid"],
    "revision_id" => page && page["revision_id"],
    "revision_timestamp" => page && page["revision_timestamp"],
    "medium_signals" => signals,
    "evidence" => evidence.first(12)
  }
end

summary = decisions.group_by { |row| row.fetch("medium") }.transform_values do |rows|
  rows.group_by { |row| row.fetch("status") }.transform_values(&:length)
end
payload = {
  "generated" => Time.now.utc.iso8601,
  "source" => source_path,
  "question_count" => questions.length,
  "summary" => summary,
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
