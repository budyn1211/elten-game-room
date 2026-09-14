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
worker_count = [[Integer(ARGV[1] || 4), 1].max, 6].min
question_limit = ARGV[2] == nil ? nil : Integer(ARGV[2])
questions = GameRoomContent::Pack0e7a79bfbaaded2145287ed3.load.fetch("questions")
questions = questions.first(question_limit) if question_limit

STOP_WORDS = %w[
  a an about after again against all also am among and any are as at be because been before
  being between both but by can could did do does doing during each few for from further had
  has have having he her here hers herself him himself his how i if in into is it its itself
  me more most my myself no nor not of off on once only or other our ours ourselves out over
  own same she should so some such than that the their theirs them themselves then there these
  they this those through to too under until up very was we were what when where which while
  who whom why will with would you your yours yourself yourselves following name called known
  many much one ones choose approximately according these except found used true false
].freeze

GENERIC_ANSWERS = /\A(?:all|none|both|neither|any) of (?:these|the above)\z/i

def normalized(value)
  CGI.unescapeHTML(value.to_s).unicode_normalize(:nfkc).downcase
    .gsub(/(?<=\d),(?=\d)/, "")
    .gsub(/[’‘]/, "'").gsub(/[^\p{L}\p{N}%+'-]+/u, " ").gsub(/\s+/, " ").strip
end

def tokens(value)
  normalized(value).scan(/[\p{L}\p{N}][\p{L}\p{N}'-]*/u)
end

def content_tokens(value)
  tokens(value).reject { |token| token.length < 3 || STOP_WORDS.include?(token) }
end

def answer_variants(answer)
  base = normalized(answer)
  variants = [base]
  variants << base.sub(/\Athe\s+/, "")
  variants << base.gsub(/,/, "")
  if (match = base.match(/\A([\d,]+(?:\.\d+)?)\s*(.*)\z/))
    number = match[1].delete(",")
    unit = match[2]
    variants << [number, unit].reject(&:empty?).join(" ")
    variants << number
  end
  variants.reject { |value| value.length < 2 }.uniq
end

def query_for(question, answer = question.fetch("correct"))
  prompt_terms = content_tokens(question.fetch("prompt"))
  normalized_answer = normalized(answer)
  answer_terms = content_tokens(answer).first(4)
  if normalized_answer.match?(/\A\d\z/)
    prompt_terms.uniq.first(6).join(" ")
  elsif normalized_answer.match?(/\A[\d\s.,%+-]/)
    (answer_terms + prompt_terms.uniq.first(3)).uniq.first(7).join(" ")
  else
    answer_terms.join(" ")
  end
end

def fetch_pages(endpoint, query)
  params = {
    "action" => "query",
    "generator" => "search",
    "gsrsearch" => query,
    "gsrnamespace" => "0",
    "gsrlimit" => "4",
    "prop" => "extracts|revisions|info",
    "explaintext" => "1",
    "exintro" => "1",
    "exsectionformat" => "plain",
    "exchars" => "20000",
    "exlimit" => "max",
    "rvprop" => "ids|timestamp",
    "inprop" => "url",
    "redirects" => "1",
    "format" => "json",
    "formatversion" => "2",
    "maxlag" => "5"
  }
  body = URI.encode_www_form(params)
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
        return Array(parsed.dig("query", "pages"))
      end
      retry_after = response["retry-after"].to_i
      raise "HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikipedia page request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikipedia page search failed after retries"
end

def evidence_from_page(page, question, answer)
  prompt_terms = content_tokens(question.fetch("prompt")).uniq
  variants = answer_variants(answer)
  sentences = page.fetch("extract", "").gsub(/\n+/, " ").split(/(?<=[.!?])\s+(?=[A-Z0-9])/)
  evidence = []
  title = normalized(page.fetch("title", ""))
  title_is_answer = variants.any? do |variant|
    title == variant || title.delete_suffix("s") == variant.delete_suffix("s")
  end
  sentences.each_with_index do |sentence, index|
    normalized_sentence = normalized(sentence)
    sentence_has_answer = variants.any? { |variant| normalized_sentence.include?(variant) }
    next unless sentence_has_answer || title_is_answer

    overlap = prompt_terms.count { |token| normalized_sentence.include?(token) }
    next if title_is_answer && !sentence_has_answer && overlap.zero?
    context = sentences[[index - 1, 0].max, 3].to_a.join(" ").gsub(/\s+/, " ").strip
    evidence << {
      "overlap" => overlap,
      "match_kind" => sentence_has_answer ? "answer_in_text" : "answer_is_page_title",
      "text" => context[0, 1800]
    }
  end
  evidence.sort_by { |row| [-row.fetch("overlap"), row.fetch("text").length] }.first(5)
end

def inspect_answer(endpoint, question, answer)
  query = query_for(question, answer)
  pages = fetch_pages(endpoint, query)
  rows = pages.map do |page|
    revision = Array(page["revisions"]).first || {}
    evidence = evidence_from_page(page, question, answer)
    {
      "pageid" => page["pageid"],
      "title" => page["title"],
      "url" => page["fullurl"],
      "revision_id" => revision["revid"],
      "revision_timestamp" => revision["timestamp"],
      "extract_size" => page.fetch("extract", "").bytesize,
      "evidence" => evidence
    }
  end
  { "answer" => answer, "query" => query, "pages" => rows }
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
    "questions" => {},
    "errors" => {}
  }
end

completed = payload.fetch("completed_ids").to_h { |id| [id, true] }
remaining = questions.reject { |question| completed.key?(question.fetch("id")) }
endpoint = URI(payload.fetch("endpoint"))
remaining.each_slice(20).with_index do |batch, batch_index|
  queue = Queue.new
  batch.each { |question| queue << question }
  worker_count.times { queue << nil }
  mutex = Mutex.new
  threads = worker_count.times.map do
    Thread.new do
      while (question = queue.pop)
        id = question.fetch("id")
        begin
          answers = if question.fetch("correct").match?(GENERIC_ANSWERS)
            question.fetch("wrong")
          else
            [question.fetch("correct")]
          end
          row = {
            "prompt" => question.fetch("prompt"),
            "correct" => question.fetch("correct"),
            "wrong" => question.fetch("wrong"),
            "generic_answer" => question.fetch("correct").match?(GENERIC_ANSWERS),
            "checks" => answers.map { |answer| inspect_answer(endpoint, question, answer) }
          }
          mutex.synchronize { payload.fetch("questions")[id] = row }
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
  done = questions.length - remaining.length + ((batch_index + 1) * 20)
  warn "Wikipedia page evidence: #{[done, questions.length].min}/#{questions.length}"
end

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
