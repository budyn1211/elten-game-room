require "json"
root = File.expand_path("..", __dir__)
mo = File.binread(File.join(root, "locale/PL.mo"))
count, originals, translations = mo.byteslice(8, 12).unpack("V3")
catalog = {}
count.times do |i|
  size, offset = mo.byteslice(originals + 8 * i, 8).unpack("V2")
  key = mo.byteslice(offset, size).force_encoding("UTF-8")
  size, offset = mo.byteslice(translations + 8 * i, 8).unpack("V2")
  catalog[key] = mo.byteslice(offset, size).force_encoding("UTF-8")
end
files = %w[games/uno.rb games/poker.rb games/makao.rb games/yahtzee.rb games/monopoly.rb content/monopoly_boards.rb lib/game_surfaces/roll_and_score.rb lib/game_surfaces/packet_cards.rb lib/game_screen.rb]
strings = files.flat_map do |file|
  source = File.read(File.join(root, file), encoding: "UTF-8")
  double = source.scan(/_\(("(?:\\.|[^"\\])*")\)/).flatten.map { |value| JSON.parse(value) }
  single = source.scan(/_\('([^']*)'\)/).flatten
  plurals = source.scan(/n_\(("(?:\\.|[^"\\])*")\s*,\s*("(?:\\.|[^"\\])*")/).map { |pair| pair.map { |value| JSON.parse(value) }.join("\0") }
  double + single + plurals
end.uniq
require_relative "../content/monopoly_regional_data"
# Street/city names are proper names; generic transport/company/neutral
# squares also need catalogue coverage even though their labels are data.
strings += GameRoomContent::MonopolyRegionalData::PROFILES.values.flat_map do |profile|
  profile[:layout].filter_map { |type, name, _group| name if [:railroad, :utility, :neutral].include?(type) }
end
strings.uniq!
missing = strings.reject { |value| catalog.key?(value) && !catalog[value].empty? }
puts JSON.pretty_generate(missing.to_h { |value| [value, ""] })
abort "#{missing.length} missing Polish translations" unless missing.empty?
