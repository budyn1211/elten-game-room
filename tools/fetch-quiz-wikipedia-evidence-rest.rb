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
remaining_limit = ARGV[2] && Integer(ARGV[2])
questions = GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions")

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
    .gsub(/(?<=\d),(?=\d)/, "").gsub(/[’‘]/, "'")
    .gsub(/[^\p{L}\p{N}%+'-]+/u, " ").gsub(/\s+/, " ").strip
end

def content_tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
    .reject { |token| (token.length < 3 && !token.match?(/\A\d+\z/)) || STOP_WORDS.include?(token) }
end

token_df = Hash.new(0)
questions.each do |question|
  content_tokens(question.fetch("prompt")).uniq.each { |token| token_df[token] += 1 }
end

def search_query(question, answer, token_df, question_count)
  answer_tokens = content_tokens(answer)
  prompt_tokens = content_tokens(question.fetch("prompt")).uniq - answer_tokens
  subject_tokens = prompt_tokens.sort_by do |token|
    [token_df.fetch(token, question_count), prompt_tokens.index(token), -token.length]
  end.first(2)
  parts = answer_tokens.first(5)
  parts << normalized(answer) if parts.empty? && !normalized(answer).empty?
  parts.concat(subject_tokens).uniq.join(" ")
end

def clean_excerpt(value)
  CGI.unescapeHTML(value.to_s.gsub(/<[^>]+>/, " ")).gsub(/\s+/, " ").strip
end

def rest_search(question, answer, token_df, question_count)
  query = search_query(question, answer, token_df, question_count)
  endpoint = URI("https://en.wikipedia.org/w/rest.php/v1/search/page")
  endpoint.query = URI.encode_www_form("q" => query, "limit" => "8")
  7.times do |attempt|
    request = Net::HTTP::Get.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/json"
    begin
      http = Thread.current[:quiz_wikipedia_rest_http]
      unless http&.started?
        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = true
        http.open_timeout = 20
        http.read_timeout = 60
        http.start
        Thread.current[:quiz_wikipedia_rest_http] = http
      end
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        return {
          "answer" => answer,
          "query" => query,
          "total_hits" => Array(body["pages"]).length,
          "results" => Array(body["pages"]).map do |row|
            {
              "pageid" => row["id"],
              "title" => row["title"],
              "url" => "https://en.wikipedia.org/?curid=#{row['id']}",
              "snippet" => clean_excerpt([row["description"], row["excerpt"]].compact.join(" ")),
              "wordcount" => nil,
              "timestamp" => nil,
              "search_api" => "MediaWiki REST search"
            }
          end
        }
      end
      retry_after = response["retry-after"].to_i
      raise "Wikipedia REST search returned HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      warn "Wikipedia REST search returned HTTP #{response.code}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      begin
        Thread.current[:quiz_wikipedia_rest_http]&.finish
      rescue IOError, SystemCallError
        nil
      ensure
        Thread.current[:quiz_wikipedia_rest_http] = nil
      end
      warn "Wikipedia REST search failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia REST search failed after retries"
end

payload = JSON.parse(File.read(output_path, encoding: "UTF-8"))
completed = payload.fetch("completed_ids").select { |id| payload.fetch("searches").key?(id) }.to_h { |id| [id, true] }
remaining = questions.reject { |question| completed.key?(question.fetch("id")) }
remaining = remaining.first(remaining_limit) if remaining_limit
queue = Queue.new
remaining.each { |question| queue << question }
worker_count.times { queue << nil }
mutex = Mutex.new
processed = 0

threads = worker_count.times.map do
  Thread.new do
    begin
      while (question = queue.pop)
        id = question.fetch("id")
        begin
          correct = question.fetch("correct")
          answers = if correct.match?(BOOLEAN_ANSWERS) || correct.match?(NEGATIVE_GENERIC_ANSWERS)
            []
          elsif correct.match?(GENERIC_ANSWERS)
            question.fetch("wrong")
          else
            [correct]
          end
          result = {
            "prompt" => question.fetch("prompt"),
            "correct" => correct,
            "wrong" => question.fetch("wrong"),
            "generic_answer" => correct.match?(GENERIC_ANSWERS),
            "skipped_reason" => answers.empty? ? "answer form cannot be proven by positive token search" : nil,
            "checks" => answers.map { |answer| rest_search(question, answer, token_df, questions.length) }
          }
          mutex.synchronize do
            payload.fetch("searches")[id] = result
            payload.fetch("errors").delete(id)
            completed[id] = true
            processed += 1
            if (processed % 100).zero?
              payload["completed_ids"] = completed.keys
              payload["updated"] = Time.now.utc.iso8601
              File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
              warn "Wikipedia REST evidence: #{completed.length}/#{questions.length}"
            end
          end
        rescue StandardError => error
          mutex.synchronize { payload.fetch("errors")[id] = "#{error.class}: #{error.message}" }
        end
      end
    ensure
      Thread.current[:quiz_wikipedia_rest_http]&.finish if Thread.current[:quiz_wikipedia_rest_http]&.started?
    end
  end
end
threads.each(&:join)

payload["completed_ids"] = completed.keys
payload["updated"] = Time.now.utc.iso8601
payload["finished"] = Time.now.utc.iso8601 if completed.length == questions.length
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts output_path
