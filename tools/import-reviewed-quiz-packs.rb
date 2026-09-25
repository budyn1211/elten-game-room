# encoding: UTF-8
# Mechanical, reproducible conversion of the reviewed PR's data, not a scraper.
require_relative "quiz-pack-writer"
require_relative "quiz-data-cleanup"
require_relative 'support/quiz_write_guard'
def _(text); text; end
require_relative "../content/languages"

write_options = QuizWriteGuard.options!(ARGV)
root, output = ARGV
abort "Usage: ruby tools/import-reviewed-quiz-packs.rb REVIEWED_PR_ROOT OUTPUT_CONTENT_DIR" unless output
revision = "efa6e640a57901e7b01e5ac2158e84f1c3375435"
$LOADED_FEATURES << File.expand_path("lib/game_content.rb", root)
files = {
  "quiz_general_en" => ["quiz.general.en", "9386447f5f13c8084ef3d80f853a248dfdefc82eb23ab21d03a32f5ad778b91d"],
  "quiz_pl_wikidata" => ["quiz.wikidata.pl", "8c3359787f9c69c901b5b285d7c0e117537558e4ce4602cdb5bb6261158db063"],
  "quiz_witcher_pl" => ["quiz.witcher.pl", "28d76c227e5712251aacb1e4aa786c49a984d00816ec1d4fd2aa0131d0af16d2"]
}
report = { "revision" => revision, "packs" => {} }
# Validate ALL pinned inputs before the first destination can be written.
prepared = files.map do |name, (id, checksum)|
  path = File.expand_path("content/#{name}.rb", root)
  bytes = File.binread(path)
  # Checkout line endings can differ; the pinned review copy uses CRLF.
  normalized = bytes.gsub("\r\n", "\n").gsub("\n", "\r\n")
  raise "Unreviewed input: #{path}" unless [bytes, normalized].any? { |v| Digest::SHA256.hexdigest(v) == checksum }
  # Only the exact pinned, reviewed data definitions may execute here.
  load path
  original = GameRoomContent.registry.pack(id)
  source = "https://github.com/budyn1211/elten-game-room/blob/#{revision}/content/#{name}.rb"
  questions, audit = QuizDataCleanup.clean(original.data.fetch("questions"), source: source)
  metadata = { id: original.id, set_id: original.set_id, kind: :quiz,
    language_id: original.language_id, version: original.version, title: original.title,
    game_ids: original.game_ids, license: original.license, author: original.author }
  [name, id, checksum, metadata, questions, source, audit]
end
inputs = files.keys.map { |name| File.join(root, 'content', name + '.rb') }
targets = files.keys.flat_map { |name| [File.join(output, name + '.rb'), File.join(output, name + '_data.rb')] }
targets << File.join(output, 'QUIZ_IMPORT_REPORT.json')
versions = prepared.to_h { |name, _id, _checksum, metadata, *_| [File.join(output, name + '.rb'), metadata.fetch(:version)] }
exit unless QuizWriteGuard.check!(tool: File.basename(__FILE__), inputs: inputs, outputs: targets,
  versions: versions, options: write_options)
prepared.each do |name, id, checksum, metadata, questions, source, audit|
  pack = QuizPackWriter.write(File.join(output, name + ".rb"), metadata, questions,
    source: source, translated: id == "quiz.general.en")
  report["packs"][id] = audit.merge("checksum" => pack.checksum, "input_sha256" => checksum)
  puts "#{id}: #{audit['input']} -> #{audit['kept']}, cleaned #{audit['changed'].length}, rejected #{audit['rejected'].length}"
end
File.write(File.join(output, "QUIZ_IMPORT_REPORT.json"), JSON.pretty_generate(report) + "\n", encoding: "UTF-8")
