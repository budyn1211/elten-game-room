# encoding: UTF-8
require "json"
require "net/http"
require "time"
require "uri"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

label_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
analysis_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
label_data = JSON.parse(File.read(label_path, encoding: "UTF-8"))
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")
questions_by_id = questions.to_h { |question| [question.fetch("id"), question] }
labels = label_data.fetch("label_items")
separator = " #{[0x2014].pack("U")} "

RELATIONS = {
  "z jakiego kraju był jego patron?" => "P138",
  "z jakiego kraju był jego odkrywca?" => "P61"
}.freeze

PREFIXES = %w[Minerał Pierwiastek].freeze

def lower_first(value)
  first = value.slice(/\A./m)
  first ? first.downcase + value[first.length..].to_s : value
end

def item_labels(question, labels, kind, separator)
  text = if kind == :subject
    question.fetch("prompt").split(separator, 2).first.to_s.strip
  else
    question.fetch("correct").to_s.strip
  end
  candidates = [text, lower_first(text)]
  prefix, rest = text.split(" ", 2)
  candidates.concat([rest, lower_first(rest)]) if rest && PREFIXES.include?(prefix)
  candidates.compact.uniq.flat_map { |label| labels.fetch(label, []) }.uniq
end

def fetch_entities(endpoint, ids)
  return {} if ids.empty?
  query = URI.encode_www_form(
    "action" => "wbgetentities", "ids" => ids.join("|"), "props" => "claims|labels",
    "languages" => "pl|en", "format" => "json", "formatversion" => "2"
  )
  uri = endpoint.dup
  uri.query = query
  7.times do |attempt|
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ELTEN-Game-Room-Quiz-Factual-Audit/1.0 (https://github.com/papierek1997/elten-game-room)"
    begin
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 90) { |http| http.request(request) }
      return JSON.parse(response.body).fetch("entities", {}) if response.is_a?(Net::HTTPSuccess)
      retry_after = response["retry-after"].to_i
      raise "HTTP #{response.code}" if response.code.to_i.between?(400, 499) && response.code.to_i != 429
      sleep(retry_after.positive? ? [retry_after, 60].min : [2**attempt, 30].min)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => error
      warn "Wikidata entity request failed: #{error.class}: #{error.message}; retry #{attempt + 1}/7"
      sleep([2**attempt, 30].min)
    end
  end
  raise "Wikidata entity request failed after retries"
end

def entity_values(entity, property)
  Array(entity.dig("claims", property)).filter_map do |statement|
    value = statement.dig("mainsnak", "datavalue", "value")
    next unless value.is_a?(Hash)
    id = value["id"] || (value["numeric-id"] && "Q#{value['numeric-id']}")
    next unless id
    {
      "id" => id,
      "statement" => statement["id"],
      "reference_count" => Array(statement["references"]).length,
      "rank" => statement["rank"]
    }
  end
end

targets = analysis.fetch("decisions").filter_map do |row|
  question = questions_by_id.fetch(row.fetch("id"))
  suffix = question.fetch("prompt").split(separator, 2)[1].to_s.strip
  property = RELATIONS[suffix]
  next unless property
  {
    "question" => question,
    "suffix" => suffix,
    "property" => property,
    "subjects" => item_labels(question, labels, :subject, separator),
    "answers" => item_labels(question, labels, :answer, separator)
  }
end

endpoint = URI("https://www.wikidata.org/w/api.php")
subject_ids = targets.flat_map { |row| row.fetch("subjects") }.uniq
subjects = {}
subject_ids.each_slice(50) { |batch| subjects.merge!(fetch_entities(endpoint, batch)) }
linked_ids = targets.flat_map do |row|
  row.fetch("subjects").flat_map { |id| entity_values(subjects[id] || {}, row.fetch("property")).map { |value| value.fetch("id") } }
end.uniq
linked = {}
linked_ids.each_slice(50) { |batch| linked.merge!(fetch_entities(endpoint, batch)) }

decisions = targets.map do |row|
  hops = row.fetch("subjects").flat_map do |subject_id|
    entity_values(subjects[subject_id] || {}, row.fetch("property")).flat_map do |first|
      entity_values(linked[first.fetch("id")] || {}, "P27").filter_map do |second|
        next unless row.fetch("answers").include?(second.fetch("id"))
        {
          "subject" => subject_id,
          "relation_property" => row.fetch("property"),
          "relation_statement" => first.fetch("statement"),
          "relation_reference_count" => first.fetch("reference_count"),
          "intermediate" => first.fetch("id"),
          "citizenship_property" => "P27",
          "citizenship_statement" => second.fetch("statement"),
          "citizenship_reference_count" => second.fetch("reference_count"),
          "answer" => second.fetch("id")
        }
      end
    end
  end
  {
    "id" => row.fetch("question").fetch("id"),
    "status" => hops.empty? ? "not_proven" : "verified_two_hop",
    "prompt" => row.fetch("question").fetch("prompt"),
    "correct" => row.fetch("question").fetch("correct"),
    "subject_items" => row.fetch("subjects"),
    "answer_items" => row.fetch("answers"),
    "evidence" => hops
  }
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary"))
