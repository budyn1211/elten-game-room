# encoding: UTF-8
require "json"
require "time"

root = File.expand_path("..", __dir__)
require File.join(root, "content", "quiz_pl_wikidata_data")

analysis_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
analysis = JSON.parse(File.read(analysis_path, encoding: "UTF-8"))
analysis_by_id = analysis.fetch("decisions").to_h { |row| [row.fetch("id"), row] }
questions = GameRoomContent::Packa0830f585cc4689a1e2a6335.load.fetch("questions")

def revised_prompt(prompt)
  output = prompt.to_s.gsub("wznieśiono", "wzniesiono")
  output = output.gsub(/jakie (?:jest obywatelstwo tej osoby|obywatelstwo ma ta osoba|ma obywatelstwo)\?/i,
    "jakie ma lub miała obywatelstwo?")
  output = output.gsub("jaki kraj reprezentuje?", "jaki kraj ta osoba reprezentuje lub reprezentowała?")
  output = output.sub(/\A(.+?) — jaki szczyt jest najwyższym punktem tego regionu\?\z/) do
    "#{$1} — najwyższym punktem którego regionu jest ten szczyt?"
  end
  output
end

def volatile_club_question?(prompt)
  prompt.match?(/ — w jakim klubie (?:gra|trenuje)\?\z/i)
end

def evidence_for(row)
  evidence = []
  Array(row["wikidata_evidence"]).each do |item|
    evidence << {
      "kind" => "Wikidata statement",
      "url" => "https://www.wikidata.org/wiki/#{item.fetch('item')}",
      "item" => item["item"],
      "property" => item["property"],
      "value" => item["value"],
      "statement" => item["statement"],
      "reference_count" => item["reference_count"]
    }
  end
  Array(row["wikipedia_evidence"]).first(3).each do |item|
    evidence << item.merge("kind" => "Polish Wikipedia")
  end
  Array(row["full_wikipedia_evidence"]).first(3).each do |item|
    evidence << item.merge("kind" => "Polish Wikipedia full text")
  end
  Array(row["two_hop_evidence"]).first(3).each do |item|
    evidence << item.merge(
      "kind" => "Wikidata two-hop statement",
      "url" => "https://www.wikidata.org/wiki/#{item.fetch('subject')}"
    )
  end
  Array(row["provided_source_links"]).each do |url|
    evidence << { "kind" => "official supplied source", "url" => url }
  end
  evidence.uniq
end

decisions = questions.map do |question|
  id = question.fetch("id")
  source = analysis_by_id.fetch(id)
  remove_reason = if source.fetch("status") == "not_proven"
    "brak potwierdzenia poprawnej odpowiedzi w sprawdzonych źródłach"
  elsif volatile_club_question?(question.fetch("prompt"))
    "pytanie o bieżący klub jest nietrwałe bez daty odniesienia"
  end
  if remove_reason
    {
      "id" => id,
      "decision" => "remove",
      "reason" => remove_reason,
      "source_status" => source.fetch("status"),
      "original" => question,
      "reviewed" => nil,
      "evidence" => evidence_for(source)
    }
  else
    prompt = revised_prompt(question.fetch("prompt"))
    reviewed = prompt == question.fetch("prompt") ? question : question.merge("prompt" => prompt)
    {
      "id" => id,
      "decision" => reviewed.equal?(question) ? "keep" : "correct",
      "reason" => reviewed.equal?(question) ? "odpowiedź potwierdzona" : "doprecyzowano lub poprawiono składnię bez zmiany faktu",
      "source_status" => source.fetch("status"),
      "original" => question,
      "reviewed" => reviewed,
      "evidence" => evidence_for(source)
    }
  end
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "scope" => "Polish general quiz factual and language audit",
  "question_count" => decisions.length,
  "summary" => decisions.group_by { |row| row.fetch("decision") }.transform_values(&:length),
  "source_statuses" => decisions.group_by { |row| row.fetch("source_status") }.transform_values(&:length),
  "decisions" => decisions
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.slice("question_count", "summary", "source_statuses"))
