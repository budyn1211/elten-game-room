# encoding: UTF-8
require "cgi"
require "json"
require "net/http"
require "thread"
require "time"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
worker_count = [[Integer(ARGV[2] || 6), 1].max, 8].min
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
unresolved = analysis.fetch("decisions").reject do |row|
  row.fetch("status") == "verified_referenced_claim"
end.to_h { |row| [row.fetch("id"), row] }
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")
  .select { |question| unresolved.key?(question.fetch("id")) }

STOP_WORDS = %w[
  a aby albo ale ani bez bo być by była był było były co czy dla do gdzie go i ich jak jaka
  jakie jaki jakiego jakim jaką jest jego jej którą który kto ma miał miała może na nad nie
  nim o od oraz po pod przez się ta ten tego tej temu to tu w we według z za ze został została
  należał należała osoba państwo kraju miasta roku którym której którego
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d)[,.](?=\d)/, "")
    .gsub(/[’‘]/, "'").gsub(/[^\p{L}\p{N}%+'-]+/u, " ").gsub(/\s+/, " ").strip
end

def content_tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| token.length < 2 || STOP_WORDS.include?(token) }
end

def query_for(question)
  subject = question.fetch("prompt").split(/\s+—\s+/, 2).first
  subject = subject.sub(/\A(?:pierwiastek|minerał|związek|lek|piłkarz|siatkarz|koszykarz|skoczek narciarski)\s+/i, "")
  answer = question.fetch("correct")
  (content_tokens(subject).first(6) + content_tokens(answer).first(6)).uniq.join(" ")
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
        open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
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
      warn "Polish Wikipedia request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Polish Wikipedia search failed after retries"
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
    "endpoint" => "https://pl.wikipedia.org/w/api.php",
    "question_count" => questions.length,
    "worker_count" => worker_count,
    "completed_ids" => [],
    "searches" => {},
    "errors" => {}
  }
end

completed = payload.fetch("completed_ids").to_h { |id| [id, true] }
remaining = questions.reject { |question| completed.key?(question.fetch("id")) }
endpoint = URI(payload.fetch("endpoint"))
remaining.each_slice(40).with_index do |batch, batch_index|
  queue = Queue.new
  batch.each { |question| queue << question }
  worker_count.times { queue << nil }
  mutex = Mutex.new
  threads = worker_count.times.map do
    Thread.new do
      while (question = queue.pop)
        id = question.fetch("id")
        begin
          query = query_for(question)
          response = fetch_search(endpoint, query)
          row = {
            "prompt" => question.fetch("prompt"),
            "correct" => question.fetch("correct"),
            "wrong" => question.fetch("wrong"),
            "source_links" => Array(question["source_links"]),
            "wikidata_status" => unresolved.fetch(id).fetch("status"),
            "query" => query,
            "total_hits" => response.dig("query", "searchinfo", "totalhits").to_i,
            "results" => Array(response.dig("query", "search")).map do |result|
              {
                "pageid" => result["pageid"],
                "title" => result["title"],
                "url" => "https://pl.wikipedia.org/?curid=#{result['pageid']}",
                "snippet" => clean_snippet(result["snippet"]),
                "wordcount" => result["wordcount"],
                "timestamp" => result["timestamp"]
              }
            end
          }
          mutex.synchronize { payload.fetch("searches")[id] = row }
        rescue StandardError => error
          mutex.synchronize { payload.fetch("errors")[id] = "#{error.class}: #{error.message}" }
        ensure
          mutex.synchronize { completed[id] = true }
          sleep(0.2)
        end
      end
    end
  end
  threads.each(&:join)
  payload["completed_ids"] = completed.keys
  save(output_path, payload)
  done = questions.length - remaining.length + ((batch_index + 1) * 40)
  warn "Polish Wikipedia evidence: #{[done, questions.length].min}/#{questions.length}"
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
