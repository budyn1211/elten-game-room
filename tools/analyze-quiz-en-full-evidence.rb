# encoding: UTF-8
require "cgi"
require "json"
require "time"

initial_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
search_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(3), Dir.pwd)

initial = JSON.parse(File.read(initial_path, encoding: "UTF-8"))
searches = JSON.parse(File.read(search_path, encoding: "UTF-8")).fetch("searches")
pages = JSON.parse(File.read(pages_path, encoding: "UTF-8")).fetch("pages")

STOP_WORDS = %w[
  about after again against all also among and are because been before being between both
  could did does doing during each few for from further had has have having her here hers
  herself him himself his how into its itself more most other our ours ourselves out over
  same she should some such than that the their theirs them themselves then there these they
  this those through too under until very was were what when where which while who whom why
  will with would you your yours yourself yourselves following name called known many much
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/\[\[([^\]|]+)\|([^\]]+)\]\]/, '\\2')
    .gsub(/\[\[([^\]]+)\]\]/, '\\1')
    .gsub(/\{\{[^{}]*\|([^{}|]+)\}\}/, '\\1')
    .gsub(/<[^>]+>/, " ").gsub(/(?<=\d),(?=\d)/, "")
    .gsub(/[’‘`]/, "'").gsub(/[-‐‑‒–—]/u, " ")
    .gsub(/[^\p{L}\p{N}%+']+/u, " ").gsub(/\s+/, " ").strip
end

def tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| (token.length < 3 && !token.match?(/\A\d+\z/)) || STOP_WORDS.include?(token) }
end

def comparable_token(value)
  value.to_s.sub(/'s\z/, "").sub(/(?:es|s)\z/, "")
end

def same_token?(left, right)
  left == right || (
    left.length >= 3 && right.length >= 3 &&
    comparable_token(left) == comparable_token(right)
  )
end

def answer_present?(text, answer)
  haystack = normalized(text)
  needle = normalized(answer)
  return false if needle.empty?
  # Match the complete normalized answer, not an arbitrary substring. Without
  # token boundaries an answer such as "100" was incorrectly accepted when a
  # source contained only "1000".
  return true if " #{haystack} ".include?(" #{needle} ")
  # A quantity with a unit must occur as one actual phrase. Otherwise a page
  # number or citation can be accidentally joined to an unrelated unit later
  # in the same source segment.
  return false if needle.match?(/\d/) && needle.match?(/\p{L}/u)

  parts = tokens(answer)
  return false if parts.empty?

  words = haystack.split
  # Try every occurrence of the first token. A greedy match can choose an
  # earlier unrelated occurrence and miss the compact phrase that follows.
  words.each_index.any? do |start|
    next false unless same_token?(words[start], parts.first)

    positions = [start]
    cursor = start + 1
    matched = parts.drop(1).all? do |part|
      relative = words[cursor..]&.index { |word| same_token?(word, part) }
      next false if relative == nil
      index = cursor + relative
      positions << index
      cursor = index + 1
      true
    end
    # Search snippets and wiki markup can insert a short qualifier, but a
    # multi-word answer is not proved by unrelated words scattered throughout
    # one paragraph.
    matched && positions.last - positions.first <= parts.length + 2
  end
end

def strong_context?(text, prompt, answer)
  haystack = normalized(text).split
  prompt_tokens = (tokens(prompt) - tokens(answer)).uniq
  distinctive = prompt_tokens.reject do |token|
    %w[years year people person country city state song movie film book album group actor author].include?(token)
  end
  candidates = distinctive.empty? ? prompt_tokens : distinctive
  required = [candidates.length, normalized(answer).match?(/\A\d+(?:\.\d+)?\z/) ? 3 : 2].min
  required.positive? && candidates.count do |token|
    haystack.any? { |word| same_token?(word, token) }
  end >= required
end

def evidence_segments(wikitext)
  wikitext.to_s.lines.flat_map do |line|
    line.split(/(?<=[.!?])\s+(?=(?:\[\[|\{\{)?[A-Z0-9])/)
  end.map(&:strip).reject(&:empty?)
end

def evidence_for(search, prompt, answer, pages)
  checks = Array(search["checks"])
  result = checks.find { |check| check["answer"].to_s == answer.to_s } || checks.first || {}
  Array(result["results"]).first(5).filter_map do |candidate|
    page = pages[candidate.fetch("pageid").to_s]

    search_segments = evidence_segments(candidate["snippet"].to_s)
    title = page&.fetch("title", nil) || candidate["title"]
    window_length = answer.to_s.match?(/\d/) ? 1 : 2
    find_match = lambda do |segments|
      segments.each_index.find do |index|
        window = segments[index, window_length].join(" ")
        (answer_present?(window, answer) || answer_present?(title, answer)) &&
          strong_context?(window, prompt, answer)
      end
    end

    evidence_kind = "search_excerpt"
    segments = search_segments
    match_index = find_match.call(segments)
    unless match_index
      # The search result normally contains the matching body sentence. Only
      # fall back to a bounded lead extract when that sentence is insufficient;
      # repeatedly splitting very long articles adds no evidentiary value.
      lead_text = page && (page["text"] || page.fetch("wikitext", ""))
      segments = evidence_segments(lead_text.to_s[0, 8_000])
      match_index = find_match.call(segments)
      evidence_kind = "lead_extract"
    end
    next unless match_index

    excerpt = segments[match_index, window_length].join(" ").gsub(/\s+/, " ").strip
    {
      "pageid" => page&.fetch("pageid", nil) || candidate["pageid"],
      "title" => title,
      "url" => page&.fetch("url", nil) || candidate["url"],
      "revision_id" => page&.fetch("revision_id", nil),
      "revision_timestamp" => page&.fetch("revision_timestamp", nil) || candidate["timestamp"],
      "evidence_kind" => evidence_kind,
      "segment" => match_index + 1,
      "excerpt" => excerpt[0, 1200]
    }
  end
end

decisions = initial.fetch("decisions").map do |row|
  search = searches[row.fetch("id")] || {}
  if row.fetch("status") == "negative_generic_unverifiable"
    row
  elsif row["checks"]
    checked = row.fetch("checks").map do |check|
      evidence = evidence_for(search, row.fetch("prompt"), check.fetch("answer"), pages)
      check.merge("full_wikipedia_evidence" => evidence)
    end
    supported = checked.count { |check| !check.fetch("full_wikipedia_evidence").empty? }
    row.merge(
      "status" => supported == checked.length && !checked.empty? ? "verified_full_wikipedia" : "generic_options_not_all_proven",
      "supported_option_count" => supported,
      "checks" => checked
    )
  else
    evidence = evidence_for(search, row.fetch("prompt"), row.fetch("correct"), pages)
    row.merge(
      "status" => evidence.empty? ? "not_proven" : "verified_full_wikipedia",
      "full_wikipedia_evidence" => evidence
    )
  end
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
