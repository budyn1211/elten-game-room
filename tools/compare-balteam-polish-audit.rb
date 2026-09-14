# encoding: UTF-8
require "json"
require "time"

ours_path = File.expand_path(ARGV.fetch(0), Dir.pwd)
removals_path = File.expand_path(ARGV.fetch(1), Dir.pwd)
edits_path = File.expand_path(ARGV.fetch(2), Dir.pwd)
output_path = File.expand_path(ARGV.fetch(3), Dir.pwd)

ours = JSON.parse(File.read(ours_path, encoding: "UTF-8")).fetch("decisions")
theirs = JSON.parse(File.read(removals_path, encoding: "UTF-8")).fetch("removals")
their_edits = JSON.parse(File.read(edits_path, encoding: "UTF-8")).fetch("edits")

ours_by_id = ours.to_h { |row| [row.fetch("id"), row] }
theirs_by_id = theirs.to_h { |row| [row.fetch("id"), row] }
edits_by_id = their_edits.to_h { |row| [row.fetch("original_id"), row.fetch("replacement")] }

raise "Balteam removal references an unknown ID" if !(theirs_by_id.keys - ours_by_id.keys).empty?
raise "Balteam edit references an unknown ID" if !(edits_by_id.keys - ours_by_id.keys).empty?
raise "Balteam removes and edits the same ID" if !(theirs_by_id.keys & edits_by_id.keys).empty?

def reason_prefix(row)
  Array(row["reasons"]).first.to_s.split(":", 2).first
end

comparisons = ours.map do |ours_row|
  id = ours_row.fetch("id")
  removal = theirs_by_id[id]
  edit = edits_by_id[id]
  relation = if removal && ours_row.fetch("decision") == "remove"
    "both_remove"
  elsif removal
    "balteam_remove_ours_retain"
  elsif ours_row.fetch("decision") == "remove" && edit
    "ours_remove_balteam_edit"
  elsif ours_row.fetch("decision") == "remove"
    "ours_remove_balteam_retain"
  elsif edit
    replacement = edit.merge("id" => id)
    ours_reviewed = ours_row.fetch("reviewed")
    comparable = replacement.reject { |key, _| key == "id" } == ours_reviewed.reject { |key, _| key == "id" }
    comparable ? "same_edit" : "balteam_edit_requires_comparison"
  else
    "both_retain"
  end
  {
    "id" => id,
    "relation" => relation,
    "our_decision" => ours_row.fetch("decision"),
    "our_source_status" => ours_row.fetch("source_status"),
    "our_reviewed" => ours_row["reviewed"],
    "our_evidence" => ours_row.fetch("evidence"),
    "balteam_removal" => removal,
    "balteam_edit_preserving_id" => edit && edit.merge("id" => id)
  }
end

divergent_removals = comparisons.select { |row| row.fetch("relation") == "balteam_remove_ours_retain" }
payload = {
  "generated" => Time.now.utc.iso8601,
  "balteam_commit" => "9be74abfa6968270bfc04312833767bd83833ac3",
  "question_count" => comparisons.length,
  "summary" => comparisons.map { |row| row.fetch("relation") }.tally.sort.to_h,
  "balteam_removals_by_reason_prefix" => theirs.map { |row| reason_prefix(row) }.tally.sort.to_h,
  "divergent_removals_by_our_source_status" => divergent_removals.map { |row| row.fetch("our_source_status") }.tally.sort.to_h,
  "comparisons" => comparisons
}
File.write(output_path, JSON.pretty_generate(payload) + "\n", encoding: "UTF-8")
puts JSON.pretty_generate(payload.reject { |key, _| key == "comparisons" })
