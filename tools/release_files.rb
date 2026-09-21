# Build-time only. Never distribute this tool or the source tree wholesale.
require "json"
require "fileutils"
require "pathname"

module GameRoomReleaseFiles
  ROOT_FILES = %w[__app.rb manifest.json LICENSE THIRD_PARTY_NOTICES.md].freeze
  AUDIO_EXTENSIONS = %w[.ogg .opus .wav .wave .mp3 .flac .aac .m4a .wma .spx .webm].freeze
  REQUIRED_FILES = (ROOT_FILES + %w[locale/PL.mo LICENSES/RUBY.txt LICENSES/RUBY-BSDL.txt
    lib/vendor/unicode_normalize/normalize.rb lib/vendor/unicode_normalize/tables.rb]).freeze

  def self.allowed?(relative)
    return false if relative.split("/").any? { |part| part.start_with?(".") }
    ROOT_FILES.include?(relative) ||
      relative.match?(%r{\A(?:games|lib|content)/.+\.rb\z}) ||
      (relative.start_with?("Audio/") && AUDIO_EXTENSIONS.include?(File.extname(relative).downcase)) ||
      relative.match?(%r{\Alocale/[A-Za-z]{2}\.mo\z}) ||
      relative.match?(%r{\ALICENSES/.+\.txt\z}) ||
      relative.match?(%r{\Acontent/.+_(?:NOTICE|NOTICES|LICENSE|SOURCES)\.(?:md|txt)\z})
  end

  def self.files(source)
    source = File.realpath(source)
    selected = Dir.chdir(source) do
      Dir.glob("**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) && allowed?(path) }.sort
    end
    missing = REQUIRED_FILES - selected
    raise "Missing release files: #{missing.join(', ')}" unless missing.empty?
    folded = selected.map(&:downcase)
    raise "Case-insensitive release path collision" unless folded.uniq == folded
    selected.each do |relative|
      actual = File.realpath(File.join(source, relative))
      raise "Release file escapes source: #{relative}" unless actual.start_with?(source + "/")
      if relative.start_with?("Audio/")
        header = File.binread(actual, 128)
        unless File.extname(relative) == ".opus" && header.start_with?("OggS") && header.include?("OpusHead")
          raise "Release audio must be Ogg Opus (.opus), authored at 144 kb/s VBR: #{relative}"
        end
      end
    end
    ruby = selected.grep(/\.rb\z/)
    ruby.each do |relative|
      File.read(File.join(source, relative), encoding: "UTF-8").scan(/\brequire_relative\s*(?:\(\s*)?["']([^"']+)["']/).flatten.each do |dependency|
        dependency += ".rb" if File.extname(dependency).empty?
        resolved = Pathname.new(File.join(File.dirname(relative), dependency)).cleanpath.to_s.tr("\\", "/")
        raise "Release dependency is absent: #{relative} -> #{resolved}" unless ruby.include?(resolved)
      end
    end
    manifest = JSON.parse(File.read(File.join(source, "manifest.json")))
    manifest.fetch("required_assets", {}).fetch("sounds", []).each do |sound|
      matches = selected.select { |file| file.start_with?("Audio/") && File.basename(file, File.extname(file)).casecmp(sound).zero? }
      raise "Required sound must have exactly one file: #{sound}" unless matches.length == 1
    end
    selected.freeze
  end

  def self.stage(source, destination)
    source = File.realpath(source)
    destination = File.expand_path(destination)
    raise "Release destination already exists" if File.exist?(destination)
    paths = files(source)
    # Resolve the existing parent, rejecting links back into the source tree.
    parent = File.realpath(File.dirname(destination))
    raise "Release destination must be outside the source tree" if parent == source || parent.start_with?(source + "/")
    Dir.mkdir(destination)
    paths.each do |relative|
      target = File.join(destination, relative)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(source, relative), target, preserve: true)
    end
    raise "Staged release file list differs" unless files(destination) == paths
    paths.each do |relative|
      raise "Staged bytes differ: #{relative}" unless File.binread(File.join(source, relative)) == File.binread(File.join(destination, relative))
    end
    paths
  end
end

if $PROGRAM_NAME == __FILE__
  source, destination = ARGV
  abort "Usage: ruby tools/release_files.rb SOURCE NEW_DESTINATION" unless source && destination
  files = GameRoomReleaseFiles.stage(source, destination)
  puts JSON.generate(release_files: files.length, ruby_files: files.grep(/\.rb\z/).length)
end
