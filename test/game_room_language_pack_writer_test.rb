require "tmpdir"
require "ripper"
require_relative "../tools/quiz-pack-writer"

metadata = { id: "localization.test.en", set_id: "localization.test", kind: "quiz", language_id: "en", version: 1, title: "General knowledge", game_ids: ["quiz"] }
Dir.mktmpdir("game-room-locale-writer-") do |directory|
  path = File.join(directory, "pack.rb")
  pack = QuizPackWriter.write(path, metadata, [{ id: "test", question: "Test?", answer: "Yes" }], translated: true)
  source = File.read(path, encoding: "UTF-8")
  raise "generated pack titles still use the host translator" unless source.include?('title: GameRoomLocalization.translate("General knowledge")')
  raise "generated packs do not load their translator" unless source.include?('require_relative "../lib/game_room_localization"')
  raise "generated packs moved the encoding header" unless source.start_with?("# encoding: UTF-8\n")
  raise "generated pack syntax is invalid" unless Ripper.sexp(source)
  raise "translated titles changed the content checksum" unless source.include?(pack.checksum)
end
puts "Generated translated pack titles use the independent interface catalog"
