# encoding: UTF-8
require "cgi"
require "json"
require "net/http"
require "thread"
require "time"
require "uri"

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
worker_count = [[Integer(ARGV[2] || 2), 1].max, 4].min
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
questions = analysis.fetch("decisions").reject { |row| row.fetch("status") == "verified_candidate" }

def query_for(row)
  [row["subject_wiki_title"], row["correct_wiki_title"], row["correct"]]
    .map(&:to_s).map(&:strip).reject(&:empty?).uniq.join(" ")
end

def fetch_search(endpoint, query)
  body = URI.encode_www_form(
    "action" => "query",
    "list" => "search",
    "srsearch" => query,
    "srnamespace" => "0",
    "srlimit" => "8",
    "srprop" => "snippet|titlesnippet|wordcount|timestamp",
    "format" => "json",
    "formatversion" => "2"
  )
  7.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request.body = body
    begin
      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true,
        open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      retry_after = response["retry-after"].to_i
      raise "HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wiedźmińska Wiki search failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wiedźmińska Wiki search failed after retries"
end

def clean_snippet(value)
  CGI.unescapeHTML(value.to_s.gsub(/<[^>]+>/, " ")).gsub(/\s+/, " ").strip
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
    "endpoint" => "https://wiedzmin.fandom.com/api.php",
    "question_count" => questions.length,
    "worker_count" => worker_count,
    "completed_ids" => [],
    "searches" => {},
    "errors" => {}
  }
end
completed = payload.fetch("completed_ids").to_h { |id| [id, true] }
remaining = questions.reject { |row| completed.key?(row.fetch("id")) }
endpoint = URI(payload.fetch("endpoint"))
remaining.each_slice(40).with_index do |batch, batch_index|
  queue = Queue.new
  batch.each { |row| queue << row }
  worker_count.times { queue << nil }
  mutex = Mutex.new
  workers = worker_count.times.map do
    Thread.new do
      while (row = queue.pop)
        id = row.fetch("id")
        begin
          query = query_for(row)
          response = fetch_search(endpoint, query)
          result = {
            "prompt" => row.fetch("prompt"),
            "correct" => row.fetch("correct"),
            "medium" => row.fetch("medium"),
            "previous_status" => row.fetch("status"),
            "query" => query,
            "total_hits" => response.dig("query", "searchinfo", "totalhits").to_i,
            "results" => Array(response.dig("query", "search")).map do |candidate|
              {
                "pageid" => candidate["pageid"],
                "title" => candidate["title"],
                "url" => "https://wiedzmin.fandom.com/wiki?curid=#{candidate['pageid']}",
                "snippet" => clean_snippet(candidate["snippet"]),
                "wordcount" => candidate["wordcount"],
                "timestamp" => candidate["timestamp"]
              }
            end
          }
          mutex.synchronize { payload.fetch("searches")[id] = result }
        rescue StandardError => error
          mutex.synchronize { payload.fetch("errors")[id] = "#{error.class}: #{error.message}" }
        ensure
          mutex.synchronize { completed[id] = true }
          sleep(0.25)
        end
      end
    end
  end
  workers.each(&:join)
  payload["completed_ids"] = completed.keys
  save(output_path, payload)
  done = questions.length - remaining.length + ((batch_index + 1) * 40)
  warn "Witcher fallback searches: #{[done, questions.length].min}/#{questions.length}"
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
