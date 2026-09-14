# encoding: UTF-8
require "json"
require "net/http"
require "thread"
require "time"
require "uri"

search_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
language = ARGV.fetch(2, "en")
result_limit = Integer(ARGV.fetch(3, "3"))
id_path = ARGV[4] && File.expand_path(ARGV[4], Dir.pwd)
worker_count = [[Integer(ARGV[5] || 1), 1].max, 4].min

search_payload = JSON.parse(File.read(search_path, encoding: "UTF-8"))
searches = search_payload.fetch("searches")
selected_ids = if id_path
  selected = JSON.parse(File.read(id_path, encoding: "UTF-8"))
  rows = selected["decisions"] || selected["questions"] || selected
  Array(rows).filter_map do |row|
    next row if row.is_a?(String)
    next unless row.is_a?(Hash)
    row["id"]
  end
else
  searches.keys
end
selected_ids = selected_ids.uniq

def result_rows(search, result_limit)
  return [] unless search.is_a?(Hash)
  direct = search["results"]
  return Array(direct).first(result_limit) if direct

  # Combined answers such as "All of these" have an independent search for
  # every constituent option. Keep the requested number of candidates from
  # each check; taking it only after flattening silently inspected the first
  # option and left the remaining claims without their own source pages.
  Array(search["checks"]).flat_map do |check|
    Array(check["results"]).first(result_limit)
  end
end

page_ids = selected_ids.flat_map do |id|
  result_rows(searches[id], result_limit).map { |row| row["pageid"] }
end.compact.map(&:to_s).uniq

payload = if File.file?(output_path)
  JSON.parse(File.read(output_path, encoding: "UTF-8"))
else
  {
    "started" => Time.now.utc.iso8601,
    "language" => language,
    "search_source" => search_path,
    "result_limit" => result_limit,
    "requested_page_count" => page_ids.length,
    "completed_pageids" => [],
    "pages" => {},
    "errors" => {}
  }
end
payload["requested_page_count"] = page_ids.length
completed = payload.fetch("completed_pageids").select do |id|
  page = payload.fetch("pages")[id.to_s]
  (page && (!page["text"].to_s.empty? || page["content_fetched"] == true)) ||
    payload.fetch("errors")[id.to_s] == "page not returned by Wikipedia"
end.to_h { |id| [id.to_s, true] }
remaining = page_ids.reject { |id| completed.key?(id) }
endpoint = URI("https://#{language}.wikipedia.org/w/api.php")

def fetch_batch(endpoint, ids)
  body = URI.encode_www_form(
    "action" => "query",
    "pageids" => ids.join("|"),
    "prop" => "extracts|revisions|info",
    "explaintext" => "1",
    # MediaWiki returns multiple extracts only for lead-section requests.
    # Search excerpts supply the matching body context separately.
    "exintro" => "1",
    "exchars" => "1200",
    "exlimit" => "max",
    "exsectionformat" => "plain",
    "rvprop" => "ids|timestamp",
    "inprop" => "url",
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
        open_timeout: 20, read_timeout: 120) { |http| http.request(request) }
      if response.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(response.body)
        if parsed["error"] && parsed.dig("error", "code") == "maxlag"
          sleep([2**attempt, 30].min)
          next
        end
        return Array(parsed.dig("query", "pages"))
      end

      retry_after = response["retry-after"].to_i
      raise "HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      warn "Wikipedia page content returned HTTP #{response.code}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikipedia page content failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia page content failed after retries"
end

def save(path, payload)
  payload["updated"] = Time.now.utc.iso8601
  File.write(path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
end

queue = Queue.new
remaining.each_slice(20) { |batch| queue << batch }
worker_count.times { queue << nil }
mutex = Mutex.new
processed_batches = 0

workers = worker_count.times.map do
  Thread.new do
    while (batch = queue.pop)
      begin
        returned = fetch_batch(endpoint, batch)
        returned_ids = returned.map { |page| page.fetch("pageid").to_s }
        mutex.synchronize do
          returned.each do |page|
            revision = Array(page["revisions"]).first || {}
            payload.fetch("pages")[page.fetch("pageid").to_s] = {
              "pageid" => page["pageid"],
              "title" => page["title"],
              "url" => page["fullurl"],
              "revision_id" => revision["revid"],
              "parent_id" => revision["parentid"],
              "revision_timestamp" => revision["timestamp"],
              "text" => page["extract"].to_s,
              "content_fetched" => page.key?("extract")
            }
            payload.fetch("errors").delete(page.fetch("pageid").to_s)
          end
          batch.each do |id|
            if returned_ids.include?(id)
              completed[id] = true
            else
              payload.fetch("errors")[id] = "page not returned by Wikipedia"
              completed[id] = true
            end
          end
          processed_batches += 1
          if (processed_batches % 50).zero?
            payload["completed_pageids"] = completed.keys
            save(output_path, payload)
            warn "Wikipedia page content: #{[completed.length, page_ids.length].min}/#{page_ids.length}"
          end
        end
      rescue StandardError => error
        mutex.synchronize do
          batch.each { |id| payload.fetch("errors")[id] = "#{error.class}: #{error.message}" }
          processed_batches += 1
        end
      end
    end
  end
end
workers.each(&:join)

payload["finished"] = Time.now.utc.iso8601 if page_ids.all? { |id| completed.key?(id) }
payload["completed_pageids"] = completed.keys
save(output_path, payload)
puts output_path
