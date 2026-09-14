# encoding: UTF-8
require "cgi"
require "fileutils"
require "json"
require "net/http"
require "thread"
require "time"
require "uri"

removed_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
worker_count = [[Integer(ARGV[2] || 4), 1].max, 6].min

removed = JSON.parse(File.read(removed_path, encoding: "UTF-8")).fetch("questions")
questions = removed.select { |row| row.fetch("pack_id") == "quiz.general.en" }
  .map { |row| row.fetch("original") }

STOP_WORDS = %w[
  a an about according after again against all also am among and any are as at be became
  because been before being between both but by called can could did do does doing during
  each for from further had has have having he her here hers herself him himself his how i
  if in into is it its itself known made make many me more most my myself name named no nor
  not of off on once one only or other our ours ourselves out over own same she should so
  some such than that the their theirs them themselves then there these they this those
  through to too under until up very was we were what when where which while who whom whose
  why will with would you your yours yourself yourselves approximately following
].freeze

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d),(?=\d)/, "").gsub(/[’‘`]/, "'")
    .gsub(/[-‐‑‒–—]/u, " ").gsub(/[^\p{L}\p{N}%+'#]+/u, " ")
    .gsub(/\s+/, " ").strip
end

def tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
end

TOKEN_DF = begin
  counts = Hash.new(0)
  questions.each do |question|
    tokens(question.fetch("prompt")).uniq.each { |token| counts[token] += 1 unless STOP_WORDS.include?(token) }
  end
  counts.freeze
end

def quoted(value)
  value.to_s.gsub('"', "").strip
end

def query_for(question)
  answer = quoted(question.fetch("correct"))
  answer_tokens = tokens(answer)
  prompt_tokens = tokens(question.fetch("prompt")).reject { |token| STOP_WORDS.include?(token) }
  candidates = (prompt_tokens - answer_tokens).uniq.sort_by do |token|
    [TOKEN_DF.fetch(token, questions.length), prompt_tokens.index(token), -token.length]
  end
  subject = candidates.first(4)
  answer_term = if answer.match?(/\A[\d\s.,%+\-\/]+\z/) || answer.length < 4
    answer
  else
    %Q{"#{answer}"}
  end
  ([answer_term] + subject).reject(&:empty?).join(" ")
end

def request_json(endpoint, form)
  body = URI.encode_www_form(form)
  7.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Recovery-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request.body = body
    begin
      http = Thread.current[:quiz_recovery_http]
      unless http&.started?
        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = true
        http.open_timeout = 20
        http.read_timeout = 60
        http.start
        Thread.current[:quiz_recovery_http] = http
      end
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(response.body)
        if parsed["error"] && parsed.dig("error", "code") == "maxlag"
          sleep([2**attempt, 30].min)
          next
        end
        return parsed
      end
      retry_after = response["retry-after"].to_i
      raise "Wikipedia returned HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError
      begin
        Thread.current[:quiz_recovery_http]&.finish
      rescue IOError, SystemCallError
        nil
      ensure
        Thread.current[:quiz_recovery_http] = nil
      end
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia request failed after retries"
end

def fetch_pages(endpoint, query)
  response = request_json(endpoint,
    "action" => "query", "generator" => "search", "gsrsearch" => query,
    "gsrnamespace" => "0", "gsrlimit" => "6", "prop" => "extracts|revisions|info",
    "explaintext" => "1", "exsectionformat" => "plain", "exchars" => "24000",
    "rvprop" => "ids|timestamp", "inprop" => "url", "redirects" => "1",
    "format" => "json", "formatversion" => "2", "maxlag" => "5")
  Array(response.dig("query", "pages")).map do |page|
    revision = Array(page["revisions"]).first || {}
    {
      "pageid" => page["pageid"], "title" => page["title"], "url" => page["fullurl"],
      "revision_id" => revision["revid"], "revision_timestamp" => revision["timestamp"],
      "text" => page.fetch("extract", "")
    }
  end
end

def save(path, payload)
  FileUtils.mkdir_p(File.dirname(path))
  payload["updated"] = Time.now.utc.iso8601
  File.write(path, JSON.generate(payload) + "\n", encoding: "UTF-8")
end

payload = if File.file?(output_path)
  JSON.parse(File.read(output_path, encoding: "UTF-8"))
else
  {
    "started" => Time.now.utc.iso8601,
    "source" => removed_path,
    "endpoint" => "https://en.wikipedia.org/w/api.php",
    "question_count" => questions.length,
    "completed_ids" => [], "questions" => {}, "errors" => {}
  }
end

completed = payload.fetch("completed_ids").to_h { |id| [id, true] }
remaining = questions.reject { |question| completed.key?(question.fetch("id")) }
endpoint = URI(payload.fetch("endpoint"))

remaining.each_slice(30).with_index do |batch, batch_index|
  queue = Queue.new
  batch.each { |question| queue << question }
  worker_count.times { queue << nil }
  mutex = Mutex.new
  workers = worker_count.times.map do
    Thread.new do
      begin
        while (question = queue.pop)
          id = question.fetch("id")
          begin
            query = query_for(question)
            pages = fetch_pages(endpoint, query)
            mutex.synchronize do
              payload.fetch("questions")[id] = {
                "prompt" => question.fetch("prompt"), "correct" => question.fetch("correct"),
                "wrong" => question.fetch("wrong"), "query" => query, "pages" => pages
              }
              payload.fetch("errors").delete(id)
              completed[id] = true
            end
          rescue StandardError => error
            mutex.synchronize { payload.fetch("errors")[id] = "#{error.class}: #{error.message}" }
          ensure
            sleep(0.15)
          end
        end
      ensure
        Thread.current[:quiz_recovery_http]&.finish if Thread.current[:quiz_recovery_http]&.started?
      end
    end
  end
  workers.each(&:join)
  payload["completed_ids"] = completed.keys
  save(output_path, payload)
  done = questions.length - remaining.length + ((batch_index + 1) * 30)
  warn "removed English evidence: #{[done, questions.length].min}/#{questions.length}"
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
