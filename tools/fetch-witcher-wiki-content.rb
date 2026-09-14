# encoding: UTF-8
require "json"
require "net/http"
require "time"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_witcher_pl_data")
require File.join(root, "content", "quiz_witcher_pl_medium_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
batch_size = Integer(ARGV[1] || 8)
decisions_path = ARGV[2] && File.expand_path(ARGV[2], Dir.pwd)
search_path = ARGV[3] && File.expand_path(ARGV[3], Dir.pwd)
questions = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load.fetch("questions")
prompt_overrides = GameRoomContent::WitcherPolishMediumData.load.fetch("prompts")
titles = if decisions_path
  audit = JSON.parse(File.read(decisions_path, encoding: "UTF-8"))
  audit.fetch("questions").flat_map do |row|
    [row["subject_wiki_title"], row["correct_wiki_title"]]
  end
else
  questions.map do |question|
    prompt = prompt_overrides.fetch(question.fetch("id"), question.fetch("prompt"))
    prompt.split(" — ", 2).first.to_s.strip
  end
end
if search_path && File.file?(search_path)
  search_data = JSON.parse(File.read(search_path, encoding: "UTF-8"))
  titles.concat(search_data.fetch("searches", {}).values.flat_map do |row|
    Array(row["results"]).first(3).map { |candidate| candidate["title"] }
  end)
end
titles = titles.reject(&:nil?).map(&:strip).reject(&:empty?).uniq.sort

def fetch(endpoint, titles)
  body = URI.encode_www_form(
    "action" => "query",
    "format" => "json",
    "formatversion" => "2",
    "redirects" => "1",
    "prop" => "revisions|categories",
    "rvprop" => "ids|timestamp|content",
    "rvslots" => "main",
    "cllimit" => "max",
    "titles" => titles.join("|")
  )
  7.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request.body = body
    begin
      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true,
        open_timeout: 20, read_timeout: 120) { |http| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      retry_after = response["retry-after"].to_i
      warn "Wiedźmińska Wiki returned HTTP #{response.code}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wiedźmińska Wiki request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wiedźmińska Wiki request failed after retries"
end

payload = if File.file?(output_path)
  JSON.parse(File.read(output_path, encoding: "UTF-8"))
else
  {
    "started" => Time.now.utc.iso8601,
    "endpoint" => "https://wiedzmin.fandom.com/api.php",
    "title_count" => titles.length,
    "batch_size" => batch_size,
    "pages" => {}
  }
end

endpoint = URI(payload.fetch("endpoint"))
payload["title_count"] = titles.length
remaining = titles.reject { |title| payload.fetch("pages").key?(title) }
remaining.each_slice(batch_size).with_index do |batch, index|
  response = fetch(endpoint, batch)
  query = response.fetch("query")
  aliases = {}
  Array(query["normalized"]).each { |row| aliases[row.fetch("from")] = row.fetch("to") }
  Array(query["redirects"]).each { |row| aliases[row.fetch("from")] = row.fetch("to") }
  pages = Array(query.fetch("pages")).to_h { |page| [page.fetch("title"), page] }

  batch.each do |requested|
    resolved = requested
    8.times do
      replacement = aliases[resolved]
      break if replacement == nil || replacement == resolved
      resolved = replacement
    end
    page = pages[resolved] || pages.values.find { |candidate| candidate.fetch("title").casecmp?(resolved) }
    revision = page && Array(page["revisions"]).first
    content = revision && revision.dig("slots", "main", "content")
    content ||= revision && revision["content"]
    payload.fetch("pages")[requested] = {
      "title" => page == nil ? resolved : page.fetch("title"),
      "pageid" => page && page["pageid"],
      "missing" => page == nil || page.key?("missing"),
      "revision_id" => revision && revision["revid"],
      "revision_timestamp" => revision && revision["timestamp"],
      "categories" => page == nil ? [] : Array(page["categories"]).map { |row| row.fetch("title") }.sort,
      "wikitext" => content.to_s
    }
  end
  payload["updated"] = Time.now.utc.iso8601
  File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
  done = titles.length - remaining.length + ((index + 1) * batch_size)
  warn "Witcher source pages: #{[done, titles.length].min}/#{titles.length}"
end

payload["finished"] = Time.now.utc.iso8601
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts output_path
