require "json"
require "ripper"

# Authoring documents keep English and Polish paragraphs next to each other.
# This compiler updates only rule_sections and the translation catalogue.
# Game engines, option definitions and keyboard handlers are not generated.
root = File.expand_path("..", __dir__)
translations = {}
Dir[File.join(root, "docs/rulebooks/*.json")].sort.each do |path|
  book = JSON.parse(File.read(path, encoding: "UTF-8"))
  source_path = File.join(root, book.fetch("source"))
  source = File.read(source_path, encoding: "UTF-8")
  pattern = /^    def rule_sections\r?\n.*?^    end/m
  original = source[pattern] or raise "Missing rule_sections: #{source_path}"
  sections = book.fetch("sections").map do |section|
    strings = [section.fetch("title")] + section.fetch("paragraphs")
    strings.each do |pair|
      en, pl = pair.fetch("en"), pair.fetch("pl")
      raise "Empty text: #{path}" if en.strip.empty? || pl.strip.empty?
      raise "Placeholders differ: #{en}" unless en.scan(/%\{[^}]+\}/).sort == pl.scan(/%\{[^}]+\}/).sort
      raise "Conflicting translation: #{en}" if translations.key?(en) && translations[en] != pl
      translations[en] = pl
    end
    "        rule_section(:#{section.fetch('id')}, GameRoomRules.translate(#{strings[0]['en'].dump}),\n" +
      strings.drop(1).map { |pair| "          GameRoomRules.translate(#{pair['en'].dump})" }.join(",\n") + ")"
  end
  # Monopoly's per-board figures are still generated from the actual boards.
  if book["preserve_board_profiles"]
    tokens = Ripper.lex(original)
    token_index = tokens.index { |token| token[1] == :on_ident && token[2] == "rule_section" && original.lines[token[0][0] - 1].include?("rule_section(:board_profiles") }
    raise "Missing board profiles" unless token_index
    depth = 0
    closing = nil
    tokens.drop(token_index).each do |token|
      depth += 1 if token[1] == :on_lparen
      depth -= 1 if token[1] == :on_rparen
      if token[1] == :on_rparen && depth.zero?
        closing = token
        break
      end
    end
    offsets = [0]
    original.lines.each { |line| offsets << offsets.last + line.bytesize }
    start_token = tokens[token_index]
    first = offsets[start_token[0][0] - 1] + start_token[0][1]
    last = offsets[closing[0][0] - 1] + closing[0][1] + 1
    profiles = original.byteslice(first...last)
    sections.insert(sections.length - 1, "        " + profiles)
  end
  generated = "    def rule_sections\n      # Generated from docs/rulebooks/#{File.basename(path)}; see tools/compile-rulebooks.rb.\n      [\n#{sections.join(",\n")}\n      ]\n    end"
  result = source.sub(pattern, generated)
  File.write(source_path, result, encoding: "UTF-8") unless result == source
end
translations.merge!(JSON.parse(File.read(File.join(root, "locale/rules-shared-pl.json"), encoding: "UTF-8")))
addition_path = File.join(root, "locale/rules-rewrite-pl.json")
File.write(addition_path, JSON.pretty_generate(translations) + "\n", encoding: "UTF-8")
catalogue = File.join(root, "locale/PL.mo")
data = File.binread(catalogue)
raise "Unsupported MO format" unless data.byteslice(0, 8).unpack("V2") == [0x950412de, 0]
count, originals, translated = data.byteslice(8, 12).unpack("V3")
read_string = lambda do |offset|
  size, start = data.byteslice(offset, 8).unpack("V2")
  value = data.byteslice(start, size)
  raise "Truncated MO string" unless value && value.bytesize == size
  value.force_encoding("UTF-8")
end
catalog = count.times.to_h { |i| [read_string.call(originals + i * 8), read_string.call(translated + i * 8)] }
catalog.merge!(translations)
keys = catalog.keys.sort
start = 28 + keys.length * 16
blob = "".b
tables = [keys, keys.map { |key| catalog.fetch(key) }].map do |strings|
  strings.map do |string|
    entry = [string.bytesize, start + blob.bytesize].pack("V2")
    blob << string.b << "\0"
    entry
  end.join.b
end
header = [0x950412de, 0, keys.length, 28, 28 + keys.length * 8, 0, 0].pack("V7")
File.binwrite(catalogue, header + tables.join.b + blob)
puts "Compiled #{translations.length} bilingual rulebook strings."
