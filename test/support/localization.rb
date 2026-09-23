require_relative "../../lib/game_room_localization"

module GameRoomTestLocalization
  class Runtime
    attr_reader :settings, :catalog_reads

    def initialize(language, files:, reader:)
      @settings = { "interface_language" => language.to_s, "known_languages" => [language.to_s] }
      @files, @reader, @catalog_reads = files, reader, []
    end

    def language_files
      @files
    end

    def manifest
      Struct.new(:supported_languages, :name).new([:en] + @files.keys, "Game Room")
    end

    def language_data(code)
      @catalog_reads << code
      path = @files[code]
      @reader.call(path) if path
    end

    def read_json(path, default:)
      path == "settings.json" ? @settings : default
    end
  end

  def self.runtime(language, files: nil, reader: nil)
    files ||= Dir.glob(File.expand_path("../../locale/*.mo", __dir__)).to_h do |path|
      [File.basename(path, ".mo").downcase, path]
    end
    missing = %w[fallback missing_translation].include?(language.to_s)
    Runtime.new(missing ? "pl" : language, files: missing ? {} : files, reader: reader || File.method(:binread))
  end

  def self.use_language(language)
    @language = language
    fixture = if defined?(BinaryRulesLoad)
      BinaryRulesLoad.localization_runtime(language)
    else
      runtime(language)
    end
    GameRoomLocalization.boot(runtime: fixture, host_language: "en", known_languages: [])
    requested = language.to_s.downcase.split(/[-_]/).first
    expected = (["en"] + fixture.language_files.keys).include?(requested) ? requested : "en"
    raise "Wrong Game Room test language: #{GameRoomLocalization.primary_language}, expected #{expected}" unless GameRoomLocalization.primary_language == expected
    fixture
  end

  def self.language
    @language || GameRoomLocalization.primary_language
  end
end
