# encoding: UTF-8
require "json"
require "open3"
require "set"
require_relative "quiz-pack-writer"

ROOT = File.expand_path("..", __dir__)
REMOVALS_PATH = File.join(ROOT, "content", "QUIZ_PL_GENERAL_REMOVALS.json")
EDITS_PATH = File.join(ROOT, "content", "QUIZ_PL_GENERAL_EDITS.json")
LEDGER_PATH = File.join(ROOT, "content", "QUIZ_PL_GENERAL_AUDIT_LEDGER.json")
PACK_PATH = File.join(ROOT, "content", "quiz_pl_wikidata.rb")
DATA_PATH = File.join(ROOT, "content", "quiz_pl_wikidata_data.rb")
EXPECTED_BEFORE = {
  "chemia" => 3_050,
  "geografia" => 3_101,
  "sport" => 3_001,
  "wiara i religia" => 3_071,
  "śladami przodków" => 3_205
}.freeze
EXPECTED_REMOVED = {
  "chemia" => 814,
  "geografia" => 752,
  "sport" => 684,
  "wiara i religia" => 1_184,
  "śladami przodków" => 1_055
}.freeze
EXPECTED_AFTER = {
  "chemia" => 2_236,
  "geografia" => 2_349,
  "sport" => 2_317,
  "wiara i religia" => 1_887,
  "śladami przodków" => 2_150
}.freeze
EXPECTED_SCHEMAS = {
  "chemia" => 38,
  "geografia" => 49,
  "sport" => 62,
  "wiara i religia" => 65,
  "śladami przodków" => 70
}.freeze


def extract_payload(text)
  match = text.match(/JSON\.parse\(<<'([^']+)'\)\r?\n(.*?)\r?\n\1\r?\n/m)
  raise "quiz payload not found" if match == nil

  JSON.parse(match[2])
end


def fail_unless(condition, message)
  raise message if !condition
end

removals = JSON.parse(File.read(REMOVALS_PATH, encoding: "UTF-8"))
edits_document = JSON.parse(File.read(EDITS_PATH, encoding: "UTF-8"))
ledger = JSON.parse(File.read(LEDGER_PATH, encoding: "UTF-8"))
revision = edits_document.fetch("base_revision")
fail_unless(revision.match?(/\A[0-9a-f]{40}\z/), "invalid base revision")
stdout, stderr, status = Open3.capture3("git", "-C", ROOT, "show", "#{revision}:content/quiz_pl_wikidata_data.rb")
raise "cannot read base quiz data: #{stderr}" if !status.success?
base = extract_payload(stdout)
base_questions = base.fetch("questions")
base_by_id = base_questions.to_h { |question| [question.fetch("id"), question] }
removed_ids = removals.fetch("removals").map { |row| row.fetch("id") }.to_set
edits = edits_document.fetch("edits").to_h { |row| [row.fetch("original_id"), row.fetch("replacement")] }
fail_unless(base_questions.length == 15_428, "unexpected base question count")
fail_unless(removed_ids.length == 4_489, "unexpected removal count")
fail_unless(edits.length == 602, "unexpected edit count")
fail_unless(edits_document.fetch("edit_count") == edits.length, "edit manifest count is incorrect")
fail_unless((removed_ids | edits.keys.to_set).subset?(base_by_id.keys.to_set), "audit references an unknown base question")
fail_unless((removed_ids & edits.keys.to_set).empty?, "a question is both removed and edited")
questions = base_questions.filter_map do |question|
  id = question.fetch("id")
  next if removed_ids.include?(id)

  edits.fetch(id, question)
end
source = edits_document.fetch("source")
expected_data = { "questions" => questions, "source" => source }
expected_checksum = edits_document.fetch("expected_checksum")
metadata = {
  id: "quiz.wikidata.pl",
  set_id: "quiz.wikidata",
  kind: :quiz,
  language_id: "pl-PL",
  version: 1,
  title: "Wiedza ogólna: chemia, geografia, sport, wiara, historia",
  game_ids: ["quiz"],
  author: "ELTEN Game Room",
  license: "CC0-1.0"
}
calculated = GameRoomContent::Pack.new(**metadata, data: expected_data)
fail_unless(calculated.checksum == expected_checksum, "audit inputs produce an unexpected checksum")

if ARGV == ["--check"]
  actual = extract_payload(File.read(DATA_PATH, encoding: "UTF-8"))
  fail_unless(actual == expected_data, "generated quiz data differs from the audit inputs")
  loader = File.read(PACK_PATH, encoding: "UTF-8")
  fail_unless(loader.include?("entry_count: 10939"), "loader entry count is incorrect")
  fail_unless(loader.include?("checksum: \"#{expected_checksum}\""), "loader checksum is incorrect")
  summary = ledger.fetch("summary")
  fail_unless(ledger.fetch("base_revision") == revision, "ledger has a different base revision")
  fail_unless(ledger.fetch("expected_checksum") == expected_checksum, "ledger has a different checksum")
  fail_unless(ledger.fetch("schema_count") == 284, "ledger schema count is incorrect")
  fail_unless(ledger.fetch("schemas").length == 284, "ledger schema records are incomplete")
  fail_unless(ledger.fetch("question_source_count") == 15_428, "ledger question-source count is incorrect")
  fail_unless(ledger.fetch("question_sources").length == 15_428, "ledger question-source records are incomplete")
  fail_unless(ledger.fetch("curated_record_count") == 61, "ledger curated-record count is incorrect")
  fail_unless(ledger.fetch("curated_records").length == 61, "ledger curated records are incomplete")
  fail_unless(ledger.fetch("direct_relation_check_count") == 13_237, "ledger direct-check count is incorrect")
  fail_unless(ledger.fetch("direct_relation_checks").length == 13_237, "ledger direct-check records are incomplete")
  fail_unless(ledger.fetch("date_check_count") == 1_651, "ledger date-check count is incorrect")
  fail_unless(ledger.fetch("date_checks").length == 1_651, "ledger date-check records are incomplete")
  fail_unless(summary.fetch("questions_checked") == base_questions.length, "ledger base count is incorrect")
  fail_unless(summary.fetch("questions_removed") == removed_ids.length, "ledger removal count is incorrect")
  fail_unless(summary.fetch("questions_edited") == edits.length, "ledger edit count is incorrect")
  fail_unless(summary.fetch("questions_remaining") == questions.length, "ledger retained count is incorrect")
  fail_unless(summary.fetch("category_before") == EXPECTED_BEFORE, "ledger starting category totals are incorrect")
  fail_unless(summary.fetch("category_removed") == EXPECTED_REMOVED, "ledger removal category totals are incorrect")
  fail_unless(summary.fetch("category_after") == EXPECTED_AFTER, "ledger retained category totals are incorrect")
  removal_categories = removals.fetch("removals").group_by { |row| row.fetch("category") }.transform_values(&:length)
  fail_unless(removal_categories == EXPECTED_REMOVED, "removal manifest category totals are incorrect")
  categories = questions.group_by { |question| question.fetch("category") }.transform_values(&:length)
  fail_unless(categories == EXPECTED_AFTER, "generated category totals are incorrect")
  schemas = ledger.fetch("schemas")
  schema_categories = schemas.group_by { |row| row.fetch("category") }.transform_values(&:length)
  fail_unless(schema_categories == EXPECTED_SCHEMAS, "ledger schema category totals are incorrect")
  schema_counts = schemas.to_h { |row| [[row.fetch("category"), row.fetch("source")], row.fetch("count")] }
  fail_unless(schema_counts.length == schemas.length, "ledger contains duplicate schema records")
  question_sources = ledger.fetch("question_sources")
  question_source_ids = question_sources.map { |row| row.fetch("id") }
  fail_unless(question_source_ids.uniq.length == base_questions.length && question_source_ids.to_set == base_by_id.keys.to_set, "ledger question-source IDs are invalid")
  assigned = question_sources.reject { |row| row["source_schema"] == nil }
  assigned_counts = assigned.group_by { |row| [row.fetch("category"), row.fetch("source_schema")] }.transform_values(&:length)
  fail_unless(assigned_counts == schema_counts, "ledger per-schema question counts are incorrect")
  unassigned_ids = question_sources.select { |row| row["source_schema"] == nil }.map { |row| row.fetch("id") }.to_set
  curated_ids = ledger.fetch("curated_records").map { |row| row.fetch("id") }.to_set
  fail_unless(unassigned_ids == curated_ids && curated_ids.length == 61, "ledger curated records do not cover all non-schema questions")
  direct_checks = ledger.fetch("direct_relation_checks")
  date_checks = ledger.fetch("date_checks")
  direct_ids = direct_checks.map { |row| row.fetch("id") }
  date_ids = date_checks.map { |row| row.fetch("id") }
  fail_unless(direct_ids.uniq.length == 13_237 && direct_ids.all? { |id| base_by_id.key?(id) }, "ledger direct-check IDs are invalid")
  fail_unless(date_ids.uniq.length == 1_651 && date_ids.all? { |id| base_by_id.key?(id) }, "ledger date-check IDs are invalid")
  fail_unless(direct_checks.all? { |row| schema_counts.key?([row.fetch("category"), row.fetch("source_schema")]) }, "a direct check references an unknown schema")
  fail_unless(date_checks.all? { |row| schema_counts.key?([row.fetch("category"), row.fetch("source_schema")]) }, "a date check references an unknown schema")
  fail_unless(direct_checks.all? { |row| %w[pass issue].include?(row.fetch("status")) }, "a direct check has an invalid status")
  fail_unless(date_checks.all? { |row| %w[pass issue].include?(row.fetch("status")) }, "a date check has an invalid status")
  fail_unless(direct_checks.count { |row| row.fetch("status") == "issue" } == 9, "ledger direct issue count is incorrect")
  fail_unless(date_checks.count { |row| row.fetch("status") == "issue" } == 95, "ledger date issue count is incorrect")
  puts "Polish quiz audit verified: #{questions.length} retained, #{removed_ids.length} removed, #{edits.length} edited"
else
  fail_unless(ARGV.empty?, "Usage: ruby tools/rebuild-audited-polish-quiz.rb [--check]")
  pack = QuizPackWriter.write(PACK_PATH, metadata, questions, source: source)
  fail_unless(pack.checksum == expected_checksum, "written pack has an unexpected checksum")
  puts "Rebuilt #{PACK_PATH}: #{questions.length} questions, checksum #{pack.checksum}"
end
