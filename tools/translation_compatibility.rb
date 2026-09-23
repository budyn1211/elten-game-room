require "json"

module GameRoomTranslationCompatibility
  class StaleFiles < StandardError; end

  module_function

  def sync(root, messages, check: false)
    root = File.expand_path(root)
    layout = JSON.parse(File.read(File.join(root, "tools/translation_layout.json"), encoding: "UTF-8"))
    outputs = {}
    layout.fetch("catalogs").each do |relative, definition|
      path = safe_path(root, relative)
      context = definition["context"]
      values = definition.fetch("messages").to_h do |source|
        key = context ? "#{context}\u0004#{source}" : source
        [source, translation(messages, key)]
      end
      outputs[path] = json_output(path, values)
    end
    Dir.glob(File.join(root, "docs/rulebooks/*.json")).sort.each do |path|
      book = JSON.parse(File.read(path, encoding: "UTF-8"))
      book.fetch("sections").each do |section|
        ([section.fetch("title")] + section.fetch("paragraphs")).each do |pair|
          pair["pl"] = translation(messages, pair.fetch("en"))
        end
      end
      outputs[path] = json_output(path, book)
    end
    layout.fetch("documents", []).each do |relative|
      path = safe_path(root, relative)
      text = File.read(path, encoding: "UTF-8")
      polish, english = text.split("## English", 2)
      raise ArgumentError, "missing English document section: #{relative}" unless english
      sources = english.lines.filter_map { |line| line.delete_prefix("- ").strip if line.start_with?("- ") }
      index = 0
      rewritten = polish.lines.map do |line|
        next line unless line.start_with?("- ")
        source = sources.fetch(index)
        index += 1
        ending = line.end_with?("\r\n") ? "\r\n" : "\n"
        "- #{translation(messages, source)}#{ending}"
      end.join
      raise ArgumentError, "document language sections differ: #{relative}" unless index == sources.length
      outputs[path] = rewritten + "## English" + english
    end
    changed = outputs.reject { |path, content| File.file?(path) && File.binread(path) == content.b }
    raise StaleFiles, "Generated translation views are stale: #{changed.keys.join(', ')}" if check && !changed.empty?
    changed.each { |path, content| atomic_write(path, content) } unless check
    changed.keys
  end

  def translation(messages, key)
    return messages.fetch(key).to_s if messages.key?(key)
    unless key.include?("\0")
      plural = messages.keys.find { |candidate| candidate.start_with?(key + "\0") }
      return messages.fetch(plural).to_s.split("\0", -1).first if plural
    end
    ""
  end

  def json_output(path, values)
    if File.file?(path)
      previous = File.read(path, encoding: "UTF-8")
      unchanged = begin
        JSON.parse(previous) == values
      rescue JSON::ParserError
        false
      end
      return previous if unchanged
    end
    JSON.pretty_generate(values) + "\n"
  end

  def safe_path(root, relative)
    parts = relative.to_s.tr("\\", "/").split("/")
    if parts.empty? || parts.include?("..") || parts.any?(&:empty?) || relative.to_s.include?(":")
      raise ArgumentError, "invalid generated translation path"
    end
    path = File.expand_path(relative, root)
    raise ArgumentError, "generated translation path escapes the project" unless path.start_with?(root + "/")
    parent = File.realpath(File.dirname(path))
    raise ArgumentError, "generated translation path follows an external link" unless parent.start_with?(File.realpath(root) + "/")
    path
  end

  def atomic_write(path, content)
    temporary = "#{path}.tmp-#{Process.pid}"
    File.binwrite(temporary, content.encode("UTF-8"))
    File.rename(temporary, path)
  ensure
    File.delete(temporary) if defined?(temporary) && File.file?(temporary)
  end
end
