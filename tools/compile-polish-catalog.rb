require "json"

root = File.expand_path("..", __dir__)
catalog_path = File.join(root, "locale", "PL.mo")

def read_catalog(path)
  data = File.binread(path)
  magic, revision, count, originals, translations = data.byteslice(0, 20).unpack("V5")
  raise "unsupported catalogue" if magic != 0x950412de || revision != 0

  count.times.to_h do |index|
    length, offset = data.byteslice(originals + index * 8, 8).unpack("V2")
    source = data.byteslice(offset, length).force_encoding("UTF-8")
    length, offset = data.byteslice(translations + index * 8, 8).unpack("V2")
    translation = data.byteslice(offset, length).force_encoding("UTF-8")
    [source, translation]
  end
end

def write_catalog(path, catalog)
  entries = catalog.sort_by { |source, _translation| source.b }
  count = entries.length
  original_table_offset = 28
  translation_table_offset = original_table_offset + count * 8
  original_data_offset = translation_table_offset + count * 8

  original_blob = +"".b
  original_table = entries.map do |source, _translation|
    value = source.encode("UTF-8").b
    entry = [value.bytesize, original_data_offset + original_blob.bytesize]
    original_blob << value << "\0"
    entry
  end

  translation_data_offset = original_data_offset + original_blob.bytesize
  translation_blob = +"".b
  translation_table = entries.map do |_source, translation|
    value = translation.encode("UTF-8").b
    entry = [value.bytesize, translation_data_offset + translation_blob.bytesize]
    translation_blob << value << "\0"
    entry
  end

  bytes = [0x950412de, 0, count, original_table_offset, translation_table_offset, 0, 0].pack("V7")
  bytes << original_table.flatten.pack("V*")
  bytes << translation_table.flatten.pack("V*")
  bytes << original_blob << translation_blob

  temporary = "#{path}.tmp-#{Process.pid}"
  File.binwrite(temporary, bytes)
  File.rename(temporary, path)
ensure
  File.delete(temporary) if defined?(temporary) && File.exist?(temporary)
end

files = if ARGV.empty?
  locale_directory = File.join(root, "locale")
  Dir.children(locale_directory).grep(/-pl\.json\z/).sort.map { |name| File.join(locale_directory, name) }
else
  ARGV.map { |name| File.expand_path(name, root) }
end

catalog = read_catalog(catalog_path)
files.each do |path|
  JSON.parse(File.read(path, encoding: "UTF-8")).each do |source, translation|
    source_placeholders = source.split("\0", 2).first.scan(/%\{[^}]+\}/).sort
    translation.split("\0", -1).each do |variant|
      raise "placeholder mismatch in #{File.basename(path)}: #{source}" if variant.scan(/%\{[^}]+\}/).sort != source_placeholders
    end
    catalog[source] = translation
  end
end

write_catalog(catalog_path, catalog)
puts "Compiled #{catalog.length} Polish messages from #{files.length} source files"
