# encoding: UTF-8
require "json"
require "time"

ours_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
removals_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
edits_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
ledger_path = File.expand_path(ARGV.fetch(3), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(4), Dir.pwd)

ours_payload = JSON.parse(File.read(ours_path, encoding: "UTF-8"))
ours = ours_payload.fetch("decisions")
removal_document = JSON.parse(File.read(removals_path, encoding: "UTF-8"))
edit_document = JSON.parse(File.read(edits_path, encoding: "UTF-8"))
ledger = JSON.parse(File.read(ledger_path, encoding: "UTF-8"))

removals = removal_document.fetch("removals").to_h { |row| [row.fetch("id"), row] }
edits = edit_document.fetch("edits").to_h { |row| [row.fetch("original_id"), row.fetch("replacement")] }
direct = ledger.fetch("direct_relation_checks").to_h { |row| [row.fetch("id"), row] }
dates = ledger.fetch("date_checks").to_h { |row| [row.fetch("id"), row] }
question_sources = ledger.fetch("question_sources").to_h { |row| [row.fetch("id"), row] }

ids = ours.map { |row| row.fetch("id") }
ours_by_id = ours.to_h { |row| [row.fetch("id"), row] }
raise "duplicate IDs in our decisions" if ids.uniq.length != ids.length
raise "Balteam audit uses another source pack" if !(removals.keys - ids).empty? || !(edits.keys - ids).empty?
raise "Balteam audit removes and edits the same question" if !(removals.keys & edits.keys).empty?
raise "Balteam removal count mismatch" if removals.length != removal_document.dig("summary", "questions_removed")
raise "Balteam edit count mismatch" if edits.length != edit_document.fetch("edit_count")
raise "Balteam ledger does not cover every question" if question_sources.keys.sort != ids.sort

balteam_ledger_url = "https://github.com/budyn1211/elten-game-room/blob/9be74abfa6968270bfc04312833767bd83833ac3/content/QUIZ_PL_GENERAL_AUDIT_LEDGER.json"

def ledger_evidence(row)
  return [] if row == nil
  qid = row["subject_qid"]
  result = {
    "kind" => "Balteam structured Wikidata audit",
    "status" => row["status"],
    "property" => row["property"],
    "source_schema" => row["source_schema"]
  }
  result["url"] = "https://www.wikidata.org/wiki/#{qid}" if qid
  result["claims"] = row["claims"] if row["claims"]
  result["reasons"] = row["reasons"] if row["reasons"]
  [result]
end

merged = ours.map do |ours_row|
  id = ours_row.fetch("id")
  removal = removals[id]
  edit = edits[id]
  structured = direct[id] || dates[id]
  evidence = (ours_row.fetch("evidence") + ledger_evidence(structured) + [
    { "kind" => "Balteam audit ledger", "url" => balteam_ledger_url }
  ]).uniq

  if removal
    reasons = Array(removal["reasons"])
    {
      "id" => id,
      "decision" => "remove",
      "reason" => "Balteam's schema-aware audit found an unsafe or ambiguous question: #{reasons.join(', ')}",
      "source_status" => ours_row.fetch("source_status"),
      "original" => ours_row.fetch("original"),
      "reviewed" => nil,
      "evidence" => evidence + Array(removal["evidence_urls"]).map { |url| { "kind" => "Balteam supporting source", "url" => url } },
      "balteam_reasons" => reasons
    }
  elsif edit
    base = ours_row["reviewed"] || ours_row.fetch("original")
    # Keep the stable source ID and any per-question provenance while applying
    # the reviewed prompt, answer and distractors from the external audit.
    reviewed = base.merge(edit.reject { |key, _| key == "id" }).merge("id" => id)
    {
      "id" => id,
      "decision" => reviewed == ours_row.fetch("original") ? "keep" : "correct",
      "reason" => "Balteam's independently audited replacement was accepted after comparison; the original stable ID is retained",
      "source_status" => structured && structured["status"] == "pass" ? "verified_balteam_wikidata" : ours_row.fetch("source_status"),
      "original" => ours_row.fetch("original"),
      "reviewed" => reviewed,
      "evidence" => evidence,
      "balteam_edit" => true
    }
  elsif ours_row.fetch("decision") == "remove"
    # The local search pass occasionally missed facts that the independently
    # reviewed schema ledger retained. Prefer that stronger, record-specific
    # audit rather than deleting a valid question because search matching was
    # inconclusive.
    original = ours_row.fetch("original")
    {
      "id" => id,
      "decision" => "keep",
      "reason" => "retained by Balteam's independently reviewed source-schema audit; the local search pass produced a false negative",
      "source_status" => structured && structured["status"] == "pass" ? "verified_balteam_wikidata" : "verified_balteam_audit",
      "original" => original,
      "reviewed" => original,
      "evidence" => evidence,
      "balteam_retention_overrode_local_false_negative" => true
    }
  else
    ours_row.merge("evidence" => evidence)
  end
end

payload = {
  "generated" => Time.now.utc.iso8601,
  "scope" => "Merged Polish general quiz audit: local evidence plus Balteam commit 9be74ab",
  "question_count" => merged.length,
  "summary" => merged.group_by { |row| row.fetch("decision") }.transform_values(&:length),
  "source_statuses" => merged.group_by { |row| row.fetch("source_status") }.transform_values(&:length),
  "comparison" => {
    "balteam_removals" => removals.length,
    "balteam_edits" => edits.length,
    "our_additional_removals" => merged.count { |row| row.fetch("decision") == "remove" && !removals.key?(row.fetch("id")) },
    "balteam_removals_overriding_our_retention" => merged.count { |row| removals.key?(row.fetch("id")) && ours_by_id.fetch(row.fetch("id")).fetch("decision") != "remove" },
    "balteam_retention_overriding_our_false_negative" => merged.count { |row| row["balteam_retention_overrode_local_false_negative"] == true }
  },
  "decisions" => merged
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.reject { |key, _| key == "decisions" })
