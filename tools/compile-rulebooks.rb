require "json"
require "ripper"

root = File.expand_path("..", __dir__)
messages = {}
Dir[File.join(root, "docs/rulebooks/*.json")].sort.each do |path|
  book = JSON.parse(File.read(path, encoding: "UTF-8"))
  source_path = File.join(root, book.fetch("source"))
  source = File.read(source_path, encoding: "UTF-8")
  pattern = /^    def rule_sections\r?\n.*?^    end/m
  original = source[pattern] or raise "Missing rule_sections: #{source_path}"
  sections = book.fetch("sections").map do |section|
    strings = [section.fetch("title")] + section.fetch("paragraphs")
    strings.each do |pair|
      en = pair.fetch("en")
      raise "Empty text: #{path}" if en.strip.empty?
      messages[en] = true
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
puts "Compiled #{messages.length} English rulebook messages. Update and compile translations with tools/translations.rb."
