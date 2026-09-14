# encoding: UTF-8
require "json"
require "net/http"
require "time"
require "uri"

search_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
language = ARGV.fetch(2)
top_count = Integer(ARGV[3] || 3)
batch_size = [[Integer(ARGV[4] || 20), 1].max, 50].min
searches = JSON.parse(File.read(search_path, encoding: "UTF-8")).fetch("searches")
pageids = searches.values.flat_map do |question|
  Array(question["checks"] || [question]).flat_map do |check|
    Array(check["results"]).first(top_count).map { |row| row["pageid"] }
  end
end.compact.map(&:to_i).uniq.sort

def fetch_pages(endpoint, ids)
  body = URI.encode_www_form(
    "action" => "query",
    "pageids" => ids.join("|"),
    "prop" => "extracts|info|revisions",
    "explaintext" => "1",
    "exintro" => "1",
    "exlimit" => "max",
    "inprop" => "url",
    "rvprop" => "ids|timestamp",
    "format" => "json",
    "formatversion" => "2",
    "maxlag" => "5"
  )
  7.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request.body = body
    begin
      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true,
        open_timeout: 20, read_timeout: 90) { |http| http.request(request) }
      if response.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(response.body)
        if parsed["error"] && parsed.dig("error", "code") == "maxlag"
          sleep([2**attempt, 30].min)
          next
        end
        return parsed
      end
      retry_after = response["retry-after"].to_i
      raise "HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikipedia page request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia page request failed after retries"
end

def save(path, payload)
  payload["updated"] = Time.now.utc.iso8601
  File.write(path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
end

payload = if File.file?(output_path)
  JSON.parse(File.read(output_path, encoding: "UTF-8"))
else
  {
    "started" => Time.now.utc.iso8601,
    "language" => language,
    "search_source" => search_path,
    "requested_page_count" => pageids.length,
    "top_results_per_check" => top_count,
    "pages" => {},
    "errors" => {}
  }
end
payload["requested_page_count"] = pageids.length
completed = payload.fetch("pages").keys.map(&:to_i).to_h { |id| [id, true] }
remaining = pageids.reject { |id| completed.key?(id) }
endpoint = URI("https://#{language}.wikipedia.org/w/api.php")
remaining.each_slice(batch_size).with_index do |batch, index|
  begin
    response = fetch_pages(endpoint, batch)
    returned = Array(response.dig("query", "pages")).to_h { |row| [row["pageid"].to_i, row] }
    batch.each do |id|
      row = returned[id]
      revision = row && Array(row["revisions"]).first
      payload.fetch("pages")[id.to_s] = {
        "pageid" => id,
        "title" => row && row["title"],
        "url" => row && row["fullurl"],
        "revision_id" => revision && revision["revid"],
        "revision_timestamp" => revision && revision["timestamp"],
        "extract" => row && row["extract"].to_s
      }
    end
  rescue StandardError => error
    batch.each { |id| payload.fetch("errors")[id.to_s] = "#{error.class}: #{error.message}" }
  end
  save(output_path, payload) if (index % 10).zero?
  done = pageids.length - remaining.length + ((index + 1) * batch_size)
  warn "Wikipedia page intros: #{[done, pageids.length].min}/#{pageids.length}" if (index % 10).zero?
  sleep(0.25)
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
