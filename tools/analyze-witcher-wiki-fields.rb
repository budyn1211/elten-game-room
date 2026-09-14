# encoding: UTF-8
require "json"

path = File.expand_path(ARGV.fetch(0), Dir.pwd)
pages = JSON.parse(File.read(path, encoding: "UTF-8")).fetch("pages")
counts = Hash.new(0)
examples = Hash.new { |hash, key| hash[key] = [] }

pages.each_value do |page|
  page.fetch("wikitext", "").each_line do |line|
    next unless (match = line.match(/^\s*\|\s*([^=|]+?)\s*=\s*(.*)$/))

    field = match[1].strip.downcase
    value = match[2].strip
    counts[field] += 1
    examples[field] << value[0, 160] if !value.empty? && examples[field].length < 3
  end
end

counts.sort_by { |field, count| [-count, field] }.each do |field, count|
  puts "#{count}\t#{field}\t#{examples[field].join(' || ')}"
end
