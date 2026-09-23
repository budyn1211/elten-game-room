require "json"
require "tmpdir"
require "fileutils"

path = File.expand_path("../tools/translation_compatibility.rb", __dir__)
raise "Legacy translations are not generated from the canonical catalog" unless File.file?(path)
require path

def assert(condition, message)
  raise message unless condition
end

Dir.mktmpdir("game-room-po-views-") do |root|
  %w[tools locale docs/rulebooks].each { |directory| FileUtils.mkdir_p(File.join(root, directory)) }
  layout = { "catalogs" => {
    "locale/example-pl.json" => { "context" => nil, "messages" => ["Settings", "%{count} question"] },
    "locale/scoped-pl.json" => { "context" => "game", "messages" => ["Roll"] }
  }, "documents" => ["docs/CHANGELOG_TEST.md"] }
  File.write(File.join(root, "tools/translation_layout.json"), JSON.generate(layout))
  File.write(File.join(root, "locale/example-pl.json"), JSON.generate({ "Settings" => "POISON" }))
  File.write(File.join(root, "locale/scoped-pl.json"), JSON.generate({ "Roll" => "POISON" }))
  book = { "source" => "games/example.rb", "sections" => [{ "id" => "rules", "title" => { "en" => "Rules", "pl" => "POISON" }, "paragraphs" => [{ "en" => "Play.", "pl" => "POISON" }] }] }
  File.write(File.join(root, "docs/rulebooks/example.json"), JSON.generate(book))
  File.write(File.join(root, "docs/CHANGELOG_TEST.md"), "# Test\n\n## Polski\n\n- POISON\n\n## English\n\n- New feature.\n")
  messages = {
    "Settings" => "Ustawienia", "%{count} question\0%{count} questions" => "%{count} pytanie\0%{count} pytania\0%{count} pytań",
    "game\u0004Roll" => "Rzuć", "Rules" => "Zasady", "Play." => "Graj.", "New feature." => "Nowa funkcja."
  }
  result = GameRoomTranslationCompatibility.sync(root, messages)
  assert(result.length == 4, "not every legacy view was regenerated")
  exported = JSON.parse(File.read(File.join(root, "locale/example-pl.json")))
  assert(exported == { "Settings" => "Ustawienia", "%{count} question" => "%{count} pytanie" }, "legacy JSON remained authoritative or lost a singular alias")
  assert(JSON.parse(File.read(File.join(root, "locale/scoped-pl.json"))) == { "Roll" => "Rzuć" }, "context was lost when exporting a legacy view")
  updated = JSON.parse(File.read(File.join(root, "docs/rulebooks/example.json")))
  assert(updated["sections"][0]["title"] == { "en" => "Rules", "pl" => "Zasady" }, "rule structure or English text changed")
  assert(updated["sections"][0]["paragraphs"][0]["pl"] == "Graj.", "rule translation was not taken from the catalog")
  assert(File.read(File.join(root, "docs/CHANGELOG_TEST.md")).include?("- Nowa funkcja.\n"), "the Polish changelog still needs a separate edit")
  assert(GameRoomTranslationCompatibility.sync(root, messages).empty?, "compatibility generation is not idempotent")
  GameRoomTranslationCompatibility.sync(root, messages, check: true)
  original = File.binread(File.join(root, "locale/example-pl.json"))
  changed = messages.merge("Settings" => "Nowe ustawienia")
  stale = false
  begin
    GameRoomTranslationCompatibility.sync(root, changed, check: true)
  rescue GameRoomTranslationCompatibility::StaleFiles
    stale = true
  end
  assert(stale && File.binread(File.join(root, "locale/example-pl.json")) == original, "read-only check rewrote a generated file")
  GameRoomTranslationCompatibility.sync(root, changed)
  assert(JSON.parse(File.read(File.join(root, "locale/example-pl.json")))["Settings"] == "Nowe ustawienia", "editing one catalog did not update a legacy view")
  mirror = File.join(root, "locale/example-pl.json")
  File.binwrite(mirror, "truncated JSON {")
  snapshot = Dir.glob(File.join(root, "**/*")).select { |file| File.file?(file) }.to_h { |file| [file, File.binread(file)] }
  error = nil
  begin
    GameRoomTranslationCompatibility.sync(root, changed, check: true)
  rescue StandardError => caught
    error = caught
  end
  assert(error.is_a?(GameRoomTranslationCompatibility::StaleFiles) && error.message.include?(mirror), "a malformed generated mirror was not reported as stale: #{error.inspect}")
  assert(snapshot.all? { |file, bytes| File.binread(file) == bytes }, "checking a malformed mirror changed files")
  result = GameRoomTranslationCompatibility.sync(root, changed)
  assert(result == [mirror], "a malformed generated mirror was not regenerated from PO")
  assert(JSON.parse(File.read(mirror)) == { "Settings" => "Nowe ustawienia", "%{count} question" => "%{count} pytanie" }, "regenerating malformed JSON lost PO values or the layout")
  assert(GameRoomTranslationCompatibility.sync(root, changed, check: true).empty?, "repaired generated JSON is still stale")
  ["tools/translation_layout.json", "docs/rulebooks/example.json"].each do |relative|
    source = File.join(root, relative)
    valid = File.binread(source)
    begin
      File.binwrite(source, "truncated JSON {")
      snapshot = Dir.glob(File.join(root, "**/*")).select { |file| File.file?(file) }.to_h { |file| [file, File.binread(file)] }
      [false, true].each do |check|
        error = nil
        begin
          GameRoomTranslationCompatibility.sync(root, messages, check: check)
        rescue StandardError => caught
          error = caught
        end
        assert(error.is_a?(JSON::ParserError), "malformed structural source was treated as a generated mirror: #{relative}")
        assert(snapshot.all? { |file, bytes| File.binread(file) == bytes }, "malformed structural source allowed partial writes: #{relative}")
      end
    ensure
      File.binwrite(source, valid)
    end
  end
end
puts "Canonical-catalog compatibility views: poisoning resistance, rules, changelog, context, plural alias, malformed mirror recovery, structural source protection and read-only checks passed"
