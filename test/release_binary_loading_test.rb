require_relative "packaged_rules_encoding_test"

if ARGV.first
  entries = BinaryRulesLoad.instance_variable_get(:@entries)
  raise "Development Ruby leaked into installer" if entries.keys.any? { |path| path.start_with?("test/", "tools/") }
  key = "games/scrabble.rb"
  content = entries.delete(key)
  begin
    begin
      BinaryRulesLoad.read(File.join(BinaryRulesLoad::ROOT, key))
      raise "Missing packaged runtime was silently read from disk"
    rescue KeyError
      # Deliberately missing record must fail even though the source exists.
    end
  ensure
    entries[key] = content
  end
  path = File.join(BinaryRulesLoad::ROOT, "test/support/ui.rb")
  raise "Test harness cannot read its own support files" unless BinaryRulesLoad.read(path) == File.binread(path)
end
puts "PASS release binary boundary: all game/data loading, external test harness, no production fallback"
