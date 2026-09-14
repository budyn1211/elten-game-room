# encoding: UTF-8
require "cgi"
require "json"
require "net/http"
require "thread"
require "time"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_general_en_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
worker_count = [[Integer(ARGV[1] || 4), 1].max, 8].min
question_limit = ARGV[2] == nil ? nil : Integer(ARGV[2])
all_questions = GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions")
questions = question_limit ? all_questions.first(question_limit) : all_questions

STOP_WORDS = %w[
  about after again against all also among and are because been before being between both
  could did does doing during each few for from further had has have having her here hers
  herself him himself his how into its itself more most other our ours ourselves out over
  same she should some such than that the their theirs them themselves then there these they
  this those through too under until very was were what when where which while who whom why
  will with would you your yours yourself yourselves following name called known many much
  able according approximately around became become born coming defend die does earth extinct
  find fully gave gives giving happen happened happens hours icon including itself latest less
  literally long marketing needs nights one popular protected row said says science specialist
  tells these thing things translates used using want wanted wants word years except untypical
  aint arent cant couldnt didnt doesnt dont hasnt havent isnt shouldnt wasnt werent wont wouldnt
].freeze

GENERIC_ANSWERS = /\A(?:all|none|both|neither|any) of (?:these|the above)\z/i
NEGATIVE_GENERIC_ANSWERS = /\A(?:none|neither) of (?:these|the above)\z/i
BOOLEAN_ANSWERS = /\A(?:true|false|yes|no)\z/i

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d),(?=\d)/, "")
    .gsub(/[’‘]/, "'").gsub(/[^\p{L}\p{N}%+'-]+/u, " ").gsub(/\s+/, " ").strip
end

def content_tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| (token.length < 3 && !token.match?(/\A\d+\z/)) || STOP_WORDS.include?(token) }
end

TOKEN_DF = begin
  counts = Hash.new(0)
  all_questions.each do |question|
    content_tokens(question.fetch("prompt")).uniq.each { |token| counts[token] += 1 }
  end
  counts.freeze
end
QUESTION_COUNT = all_questions.length

def search_query(question, answer)
  answer_tokens = content_tokens(answer)
  prompt_tokens = content_tokens(question.fetch("prompt")).uniq - answer_tokens
  subject_tokens = prompt_tokens.sort_by do |token|
    [TOKEN_DF.fetch(token, QUESTION_COUNT), prompt_tokens.index(token), -token.length]
  end.first(2)
  parts = answer_tokens.first(5)
  parts << normalized(answer) if parts.empty? && !normalized(answer).empty?
  parts.concat(subject_tokens)
  parts.uniq.join(" ")
end

def fetch_search(endpoint, question, answer)
  body = URI.encode_www_form(
    "action" => "query",
    "list" => "search",
    "srsearch" => search_query(question, answer),
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
      http = Thread.current[:quiz_wikipedia_http]
      unless http&.started?
        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = true
        http.open_timeout = 20
        http.read_timeout = 60
        http.start
        Thread.current[:quiz_wikipedia_http] = http
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
      detail = response.body.to_s.gsub(/\s+/, " ")[0, 500]
      if response.code.to_i >= 400 && response.code.to_i < 500 && response.code.to_i != 429
        raise "Wikipedia returned HTTP #{response.code}: #{detail}"
      end
      warn "Wikipedia returned HTTP #{response.code}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      begin
        Thread.current[:quiz_wikipedia_http]&.finish
      rescue IOError, SystemCallError
        nil
      ensure
        Thread.current[:quiz_wikipedia_http] = nil
      end
      warn "Wikipedia request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia search failed after retries"
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
    "endpoint" => "https://en.wikipedia.org/w/api.php",
    "question_count" => questions.length,
    "worker_count" => worker_count,
    "completed_ids" => [],
    "searches" => {},
    "errors" => {}
  }
end

completed = payload.fetch("completed_ids").select { |id| payload.fetch("searches").key?(id) }.to_h { |id| [id, true] }
remaining = questions.reject { |question| completed.key?(question.fetch("id")) }
endpoint = URI(payload.fetch("endpoint"))
remaining.each_slice(40).with_index do |batch, batch_index|
  queue = Queue.new
  batch.each { |question| queue << question }
  worker_count.times { queue << nil }
  mutex = Mutex.new
  threads = worker_count.times.map do
    Thread.new do
      begin
        while (question = queue.pop)
          id = question.fetch("id")
          succeeded = false
          begin
          answers = if question.fetch("correct").match?(BOOLEAN_ANSWERS) ||
              question.fetch("correct").match?(NEGATIVE_GENERIC_ANSWERS)
            []
          elsif question.fetch("correct").match?(GENERIC_ANSWERS)
            question.fetch("wrong")
          else
            [question.fetch("correct")]
          end
          result = {
            "prompt" => question.fetch("prompt"),
            "correct" => question.fetch("correct"),
            "wrong" => question.fetch("wrong"),
            "generic_answer" => question.fetch("correct").match?(GENERIC_ANSWERS),
            "skipped_reason" => if question.fetch("correct").match?(BOOLEAN_ANSWERS)
              "boolean answer cannot be independently verified by an answer-token search"
            elsif question.fetch("correct").match?(NEGATIVE_GENERIC_ANSWERS)
              "negative combined answer cannot be proven by positive search results"
            end,
            "checks" => answers.map do |answer|
              response = fetch_search(endpoint, question, answer)
              {
                "answer" => answer,
                "query" => search_query(question, answer),
                "total_hits" => response.dig("query", "searchinfo", "totalhits").to_i,
                "results" => Array(response.dig("query", "search")).map do |row|
                  {
                    "pageid" => row["pageid"],
                    "title" => row["title"],
                    "url" => "https://en.wikipedia.org/?curid=#{row['pageid']}",
                    "snippet" => clean_snippet(row["snippet"]),
                    "wordcount" => row["wordcount"],
                    "timestamp" => row["timestamp"]
                  }
                end
              }
            end
          }
          mutex.synchronize do
            payload.fetch("searches")[id] = result
            payload.fetch("errors").delete(id)
            succeeded = true
          end
          rescue StandardError => error
            mutex.synchronize do
              payload.fetch("errors")[id] = "#{error.class}: #{error.message}"
            end
          ensure
            mutex.synchronize { completed[id] = true if succeeded }
            sleep(0.2)
          end
        end
      ensure
        Thread.current[:quiz_wikipedia_http]&.finish if Thread.current[:quiz_wikipedia_http]&.started?
      end
    end
  end
  threads.each(&:join)
  payload["completed_ids"] = completed.keys
  save(output_path, payload)
  done = questions.length - remaining.length + ((batch_index + 1) * 40)
  warn "Wikipedia evidence: #{[done, questions.length].min}/#{questions.length}"
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
