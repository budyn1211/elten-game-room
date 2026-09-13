require "digest"
require "json"
require "optparse"
require "set"

options = { pool: nil, add: [], dry_run: false }
OptionParser.new do |parser|
  parser.on("--pool PATH") { |value| options[:pool] = value }
  parser.on("--add PATH") { |value| options[:add] << value }
  parser.on("--dry-run") { options[:dry_run] = true }
  parser.on("--report PATH") { |value| options[:report] = value }
end.parse!

abort "missing --pool" if options[:pool].to_s.empty?
abort "missing --add" if options[:add].empty?

STOP_WORDS = %w[
  w we z ze na do od po za o u i a the czy jest jaki jaka jakie jakim jakiej
  jakiego ktory ktora ktore kto komu czego czym gdzie ile to ta ten tego tej
  tym te sie byl byla bylo byly ma mial miala jako dla przez lezy znajduje
  miescila plynie wywodzi wladala wladal panstwa panstwie panstwem panstwo
  miasto miasta miescie postac postaci postacia szkoly szkola szkole stolica
  stolicy ostatnim wladca wladcy rzeka rzeki warownia warowni siedziba
  siedzibe urodzila urodzil mieszkala mieszkal wiedzminskiej wiedzminska
  pochodzi lezaca znajdujaca nazywa
].to_set

FOLD = {
  "ą" => "a", "ć" => "c", "ę" => "e", "ł" => "l", "ń" => "n",
  "ó" => "o", "ś" => "s", "ź" => "z", "ż" => "z"
}.freeze

def fold(text)
  text.to_s.downcase.gsub(/[ąćęłńóśźż]/) { |letter| FOLD[letter] }
end

ROMAN = /\A(?:i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xiii|xiv|xv)\z/

def fingerprint(question)
  words = fold(question["prompt"])
    .gsub(/[^[:alnum:]\s]/, " ")
    .split(/\s+/)
    .reject { |word| word.empty? || (STOP_WORDS.include?(word) && !word.match?(ROMAN)) }
    .sort
    .uniq
  parts = [
    fold(question["category"]),
    fold(question["correct"]),
    words.join(" ")
  ]
  Digest::SHA256.hexdigest(parts.join("|"))
end

def load_questions(path)
  raw = JSON.parse(File.read(path, encoding: "utf-8"))
  list = raw.is_a?(Array) ? raw : (raw["questions"] || [])
  list.map do |question|
    {
      "category" => question["category"].to_s.strip,
      "level" => question["level"].to_s.strip,
      "prompt" => question["prompt"].to_s.strip,
      "correct" => question["correct"].to_s.strip,
      "wrong" => Array(question["wrong"]).map { |value| value.to_s.strip },
      "source" => question["source"].to_s
    }
  end
end

pool = File.exist?(options[:pool]) ? load_questions(options[:pool]) : []
seen = {}
pool.each { |question| seen[fingerprint(question)] = question["prompt"] }
started_with = pool.length

added = 0
rejected = []
options[:add].each do |path|
  load_questions(path).each do |question|
    key = fingerprint(question)
    if seen.key?(key)
      rejected << [question["prompt"], seen[key]]
      next
    end
    seen[key] = question["prompt"]
    pool << question
    added += 1
  end
end

pool.sort_by! { |question| [question["category"], question["prompt"]] }

if !options[:dry_run]
  File.write(options[:pool], JSON.pretty_generate({ "questions" => pool }), encoding: "utf-8")
end

counts = pool.group_by { |question| question["category"] }.transform_values(&:length)
puts(options[:dry_run] ? "DRY RUN, nothing written" : "pool written: #{options[:pool]}")
puts "  had #{started_with}, added #{added}, skipped as duplicates #{rejected.length}, now #{pool.length}"
counts.sort.each { |name, count| puts "  #{name}: #{count}" }

if options[:report]
  lines = ["duplicates skipped: #{rejected.length}", ""]
  rejected.each { |new_prompt, old_prompt| lines << "NEW: #{new_prompt}\nOLD: #{old_prompt}\n" }
  File.write(options[:report], lines.join("\n"), encoding: "utf-8")
  puts "  duplicate report: #{options[:report]}"
end
