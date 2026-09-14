# encoding: UTF-8
require "json"
require "net/http"
require "time"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

output_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
batch_size = Integer(ARGV[1] || 40)
question_limit = ARGV[2] == nil ? nil : Integer(ARGV[2])
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")
questions = questions.first(question_limit) if question_limit

SEPARATOR = " #{[0x2014].pack("U")} ".freeze
DISPLAY_PREFIXES = %w[
  Minerał Pierwiastek Związek Lek Piłkarz Piłkarka Siatkarz Siatkarka Skoczek
  Skoczkini Tenisista Tenisistka Koszykarz Koszykarka Hokeista Hokeistka
  Kierowca Biskup Papież Rabin Misjonarz Teolog Klub Stadion Turniej Konkurs
  Bitwa Katedra Rzeka Szczyt Zamek Port Bazylika Skocznia Meczet Kościół
  Wojna Wulkan Wodospad Synagoga Opactwo Park Wyspa Królestwo Cieśnina
  Pustynia Kanał Sobór Klasztor Oblężenie Traktat Kaplica Powstanie
  Uniwersytet Góry Dynastia Morze Cesarstwo Republika Wyspy Archidiecezja
  Cerkiew Order Imperium Zatoka Świątynia Pałac
].freeze

def prompt_subject(question)
  question.fetch("prompt").to_s.split(SEPARATOR, 2).first.to_s.strip
end

def lower_first(value)
  first = value.slice(/\A./m)
  return value if first == nil

  first.downcase + value[first.length..].to_s
end

def subject_labels(question)
  subject = prompt_subject(question)
  labels = [subject, lower_first(subject)]
  prefix, rest = subject.split(" ", 2)
  if rest && DISPLAY_PREFIXES.include?(prefix)
    labels.concat([rest, lower_first(rest)])
  end
  labels.reject(&:empty?).uniq
end

def answer_labels(question)
  answer = question.fetch("correct").to_s.strip
  [answer, lower_first(answer)].reject(&:empty?).uniq
end

def sparql_string(value)
  JSON.generate(value.to_s, ascii_only: false)
end

def label_query(labels)
  values = labels.flat_map do |text|
    escaped = sparql_string(text)
    ["(#{escaped} #{escaped}@pl)", "(#{escaped} #{escaped}@en)"]
  end.join("\n    ")

  <<~SPARQL
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    SELECT DISTINCT ?text ?item WHERE {
      VALUES (?text ?label) {
        #{values}
      }
      { ?item rdfs:label ?label }
      UNION
      { ?item skos:altLabel ?label }
    }
  SPARQL
end

def fetch_sparql(endpoint, query)
  body = URI.encode_www_form("query" => query, "format" => "json")
  7.times do |attempt|
    request = Net::HTTP::Post.new(endpoint)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/sparql-results+json"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request.body = body
    begin
      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true,
        open_timeout: 20, read_timeout: 90) { |http| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      retry_after = response["retry-after"].to_i
      detail = response.body.to_s.gsub(/\s+/, " ")[0, 600]
      if response.code.to_i >= 400 && response.code.to_i < 500 && response.code.to_i != 429
        raise "Wikidata returned HTTP #{response.code}: #{detail}"
      end
      warn "Wikidata returned HTTP #{response.code}: #{detail}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikidata request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikidata query failed after retries"
end

def fetch_entities(endpoint, ids)
  query = URI.encode_www_form(
    "action" => "wbgetentities",
    "ids" => ids.join("|"),
    "props" => "claims",
    "format" => "json",
    "formatversion" => "2"
  )
  uri = endpoint.dup
  uri.query = query
  7.times do |attempt|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    request["Accept"] = "application/json"
    begin
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 90) { |http| http.request(request) }
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      retry_after = response["retry-after"].to_i
      detail = response.body.to_s.gsub(/\s+/, " ")[0, 600]
      if response.code.to_i >= 400 && response.code.to_i < 500 && response.code.to_i != 429
        raise "Wikidata API returned HTTP #{response.code}: #{detail}"
      end
      warn "Wikidata API returned HTTP #{response.code}: #{detail}; retry #{attempt + 1}/7"
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikidata API request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikidata API request failed after retries"
end

def normalized_text(value)
  value.to_s.unicode_normalize(:nfkc).downcase.gsub(/\s+/, " ").strip
end

def claim_match(datavalue, answer, answer_items)
  return nil if !datavalue.is_a?(Hash)

  value = datavalue["value"]
  case datavalue["type"]
  when "wikibase-entityid"
    entity_id = value.is_a?(Hash) ? (value["id"] || "Q#{value["numeric-id"]}") : nil
    return nil if entity_id == nil || !answer_items.include?(entity_id)

    return ["entity", entity_id]
  when "time"
    time = value.is_a?(Hash) ? value["time"].to_s : ""
    answer_year = answer.to_s.match?(/\A[0-9]{4}\z/) ? answer.to_s : nil
    value_year = time[/\A[+-](\d{4})/, 1]
    return ["year", time] if answer_year && value_year == answer_year
  when "monolingualtext"
    text = value.is_a?(Hash) ? value["text"].to_s : ""
    return ["literal", text] if normalized_text(text) == normalized_text(answer)
  when "quantity"
    amount = value.is_a?(Hash) ? value["amount"].to_s.sub(/\A\+/, "") : ""
    return ["quantity", amount] if normalized_text(amount) == normalized_text(answer)
  when "string"
    return ["literal", value.to_s] if normalized_text(value) == normalized_text(answer)
  end
  nil
end

def bindings(response)
  response.fetch("results").fetch("bindings")
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
    "endpoint" => "https://query.wikidata.org/sparql",
    "question_count" => questions.length,
    "batch_size" => batch_size,
    "label_items" => {},
    "completed_labels" => [],
    "completed_subject_items" => [],
    "matches" => {}
  }
end

endpoint = URI(payload.fetch("endpoint"))
all_labels = questions.flat_map { |question| subject_labels(question) + answer_labels(question) }.uniq
completed_labels = payload.fetch("completed_labels").to_h { |label| [label, true] }
remaining_labels = all_labels.reject { |label| completed_labels.key?(label) }
label_batch_size = [batch_size * 2, 120].min
remaining_labels.each_slice(label_batch_size).with_index do |batch, index|
  result = fetch_sparql(endpoint, label_query(batch))
  found = Hash.new { |hash, key| hash[key] = [] }
  bindings(result).each do |binding|
    text = binding.fetch("text").fetch("value")
    item = binding.fetch("item").fetch("value").split("/").last
    found[text] << item if !found[text].include?(item)
  end
  batch.each do |label|
    payload.fetch("label_items")[label] = found[label]
    completed_labels[label] = true
  end
  payload["completed_labels"] = completed_labels.keys
  save(output_path, payload)
  done = all_labels.length - remaining_labels.length + ((index + 1) * label_batch_size)
  warn "Wikidata labels: #{[done, all_labels.length].min}/#{all_labels.length}"
end

question_items = lambda do |question, kind|
  labels = kind == :subject ? subject_labels(question) : answer_labels(question)
  labels.flat_map { |label| payload.fetch("label_items").fetch(label, []) }.uniq
end

matches = payload.fetch("matches")
questions_by_item = Hash.new { |hash, key| hash[key] = [] }
questions.each do |question|
  question_items.call(question, :subject).each { |item| questions_by_item[item] << question }
end
subject_items = questions_by_item.keys.sort
completed_items = payload.fetch("completed_subject_items", []).to_h { |item| [item, true] }
remaining_items = subject_items.reject { |item| completed_items.key?(item) }
api_endpoint = URI("https://www.wikidata.org/w/api.php")
remaining_items.each_slice([batch_size, 50].min).with_index do |batch, index|
  response = fetch_entities(api_endpoint, batch)
  response.fetch("entities", {}).each do |item, entity|
    questions_by_item[item].each do |question|
      answer = question.fetch("correct")
      answer_items = question_items.call(question, :answer)
      entity.fetch("claims", {}).each do |property, statements|
        statements.each do |statement|
          datavalue = statement.dig("mainsnak", "datavalue")
          matched = claim_match(datavalue, answer, answer_items)
          next if matched == nil

          row = {
            "match_type" => matched[0],
            "item" => item,
            "property" => property,
            "value" => matched[1],
            "statement" => statement["id"],
            "rank" => statement["rank"],
            "reference_count" => Array(statement["references"]).length
          }
          bucket = (matches[question.fetch("id")] ||= [])
          bucket << row if !bucket.include?(row)
        end
      end
    end
  end
  batch.each { |item| completed_items[item] = true }
  payload["completed_subject_items"] = completed_items.keys
  save(output_path, payload)
  done = subject_items.length - remaining_items.length + ((index + 1) * [batch_size, 50].min)
  warn "Wikidata claims: #{[done, subject_items.length].min}/#{subject_items.length}"
end

questions.each { |question| matches[question.fetch("id")] ||= [] }

payload["finished"] = Time.now.utc.iso8601
save(output_path, payload)
puts output_path
