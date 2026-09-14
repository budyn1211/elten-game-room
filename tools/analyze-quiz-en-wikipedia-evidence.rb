# encoding: UTF-8
require "cgi"
require "json"
require "time"

search_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
pages_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
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
    .gsub(/(?<=\d),(?=\d)/, "").gsub(/[’‘`]/, "'")
    .gsub(/[-‐‑‒–—]/u, " ").gsub(/[^\p{L}\p{N}%+']+/u, " ")
    .gsub(/\s+/, " ").strip
end

def tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| (token.length < 3 && !token.match?(/\A\d+\z/)) || STOP_WORDS.include?(token) }
end

def answer_present?(text, answer)
  haystack = normalized(text)
  needle = normalized(answer)
  return false if needle.empty?
  return true if " #{haystack} ".include?(" #{needle} ")

  answer_tokens = tokens(answer)
  !answer_tokens.empty? && answer_tokens.all? { |token| haystack.split.include?(token) }
end

def context_present?(text, prompt, answer)
  haystack_tokens = normalized(text).split
  prompt_tokens = tokens(prompt) - tokens(answer)
  distinctive = prompt_tokens.reject { |token| %w[years year people person country city state song movie film book].include?(token) }
  candidates = distinctive.empty? ? prompt_tokens : distinctive
  required = [candidates.length, 2].min
  required.positive? && candidates.count { |token| haystack_tokens.include?(token) } >= required
end

def evidence_for(check, prompt, answer, pages)
  Array(check["results"]).filter_map do |result|
    page = pages[result.fetch("pageid").to_s] || {}
    text = [result["title"], result["snippet"], page["extract"]].join(" ")
    next unless answer_present?(text, answer) && context_present?(text, prompt, answer)

    {
      "pageid" => result["pageid"],
      "title" => result["title"],
      "url" => page["url"] || result["url"],
      "revision_id" => page["revision_id"],
      "revision_timestamp" => page["revision_timestamp"],
      "snippet" => result["snippet"],
      "extract_excerpt" => page["extract"].to_s[0, 1200]
    }
  end
end

decisions = searches.map do |id, row|
  checks = Array(row["checks"])
  if row["generic_answer"]
    negative = row.fetch("correct").match?(/\A(?:none|neither)/i)
    check_evidence = checks.map do |check|
      evidence = evidence_for(check, row.fetch("prompt"), check.fetch("answer"), pages)
      { "answer" => check.fetch("answer"), "evidence" => evidence.first(3) }
    end
    supported = check_evidence.count { |check| !check.fetch("evidence").empty? }
    status = if negative
      "negative_generic_unverifiable"
    elsif supported == checks.length && !checks.empty?
      "verified_candidate"
    else
      "generic_options_not_all_proven"
    end
    {
      "id" => id,
      "status" => status,
      "prompt" => row.fetch("prompt"),
      "correct" => row.fetch("correct"),
      "supported_option_count" => supported,
      "option_count" => checks.length,
      "checks" => check_evidence
    }
  else
    check = checks.first || {}
    evidence = evidence_for(check, row.fetch("prompt"), row.fetch("correct"), pages)
    alternatives = Array(row["wrong"]).map do |answer|
      {
        "answer" => answer,
        "evidence" => evidence_for(check, row.fetch("prompt"), answer, pages).first(5)
      }
    end
    supported_alternatives = alternatives.reject { |candidate| candidate.fetch("evidence").empty? }
    status = if !evidence.empty?
      "verified_candidate"
    elsif supported_alternatives.length == 1
      "correction_candidate"
    else
      "not_proven"
    end
    {
      "id" => id,
      "status" => status,
      "prompt" => row.fetch("prompt"),
      "correct" => row.fetch("correct"),
      "query" => check["query"],
      "evidence" => evidence.first(5),
      "suggested_correct" => supported_alternatives.length == 1 ? supported_alternatives.first.fetch("answer") : nil,
      "alternative_evidence" => supported_alternatives
    }
  end
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "search_source" => search_path,
  "page_source" => pages_path,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
