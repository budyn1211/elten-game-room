require "digest"
require "json"

begin
  # Packaged builds vendor Ruby's Unicode normalizer because ELTEN's isolated
  # application runtime does not expose the lazily loaded standard-library
  # implementation to programs.
  require_relative "vendor/unicode_normalize/normalize"
rescue LoadError
  # Source checkouts can still use the implementation supplied by their Ruby
  # runtime. normalize_unicode below retains a final UTF-8-only fallback.
end

module GameRoomContent
  SET_OPTION_KEY = "content_set_id".freeze
  LANGUAGE_OPTION_KEY = "content_language_id".freeze
  PACK_OPTION_KEY = "content_pack_id".freeze
  PACK_VERSION_KEY = "content_pack_version".freeze
  PACK_CHECKSUM_KEY = "content_pack_checksum".freeze
  PACK_ID_PATTERN = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/i
  LANGUAGE_ID_PATTERN = /\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/
  CHECKSUM_PATTERN = /\A[0-9a-f]{64}\z/i

  def self.utf8(value)
    text = value.to_s.dup
    text.force_encoding(Encoding::UTF_8) if text.encoding == Encoding::ASCII_8BIT
    text.encode(Encoding::UTF_8)
  end

  class LanguageProfile
    attr_reader :id, :label, :alphabet

    def initialize(id:, label:, alphabet:, normalizer: nil)
      @id = GameRoomContent.utf8(id).strip
      @label = GameRoomContent.utf8(label).strip
      @alphabet = alphabet.to_a.map { |letter| normalize_unicode(letter).downcase }.freeze
      @normalizer = normalizer
      raise ArgumentError, "a language profile requires a valid language id" if !LANGUAGE_ID_PATTERN.match?(@id)
      raise ArgumentError, "a language profile requires a label" if @label.empty?
      raise ArgumentError, "a language profile requires an alphabet" if @alphabet.empty?
      raise ArgumentError, "language alphabet entries must be unique" if @alphabet.uniq.length != @alphabet.length
    end

    def normalize(text)
      value = normalize_unicode(text).strip.gsub(/\s+/, " ")
      value = @normalizer.call(value) if @normalizer != nil
      GameRoomContent.utf8(value)
    end

    def normalize_word(text)
      normalize(text).delete(" ")
    end

    def graphemes(text)
      normalize_unicode(text).scan(/\X/)
    end

    def valid_word_shape?(text)
      letters = graphemes(normalize_word(text))
      !letters.empty? && letters.all? { |letter| @alphabet.include?(letter.downcase) }
    end

    private

    def normalize_unicode(value)
      text = GameRoomContent.utf8(value)
      if defined?(UnicodeNormalize) && UnicodeNormalize.respond_to?(:normalize)
        return UnicodeNormalize.normalize(text, :nfc)
      end
      return text if @unicode_normalization_available == false
      return text if !text.respond_to?(:unicode_normalize)

      normalized = text.unicode_normalize(:nfc)
      @unicode_normalization_available = true
      normalized
    rescue LoadError
      # A source checkout may run in an incomplete Ruby environment. Packaged
      # builds carry the full implementation above; this fallback only keeps a
      # damaged or incomplete development runtime from preventing app startup.
      @unicode_normalization_available = false
      text
    end
  end

  class Pack
    attr_reader :id, :set_id, :kind, :language_id, :version, :title, :game_ids,
      :checksum, :license, :author, :entry_count

    def initialize(
      id:,
      set_id: nil,
      kind:,
      language_id:,
      version:,
      title:,
      game_ids:,
      data: nil,
      loader: nil,
      checksum: nil,
      license: nil,
      author: nil,
      entry_count: nil
    )
      @id = GameRoomContent.utf8(id).strip
      @set_id = GameRoomContent.utf8(set_id == nil ? @id : set_id).strip
      @kind = GameRoomContent.utf8(kind).strip
      @language_id = GameRoomContent.utf8(language_id).strip
      @version = Integer(version)
      @title = GameRoomContent.utf8(title).strip
      @game_ids = game_ids.to_a.map { |game_id| GameRoomContent.utf8(game_id) }.reject(&:empty?).uniq.freeze
      @license = GameRoomContent.utf8(license).strip
      @author = GameRoomContent.utf8(author).strip
      @entry_count = entry_count == nil ? nil : Integer(entry_count)
      raise ArgumentError, "a content entry count cannot be negative" if @entry_count != nil && @entry_count < 0
      @loader = loader
      @data = data == nil ? nil : deep_freeze(normalize_data(data))
      raise ArgumentError, "a content pack requires a valid id" if !PACK_ID_PATTERN.match?(@id)
      raise ArgumentError, "a content pack requires a valid set id" if !PACK_ID_PATTERN.match?(@set_id)
      raise ArgumentError, "a content pack requires a kind" if @kind.empty?
      raise ArgumentError, "a content pack requires a valid language id" if !LANGUAGE_ID_PATTERN.match?(@language_id)
      raise ArgumentError, "a content pack version must be positive" if @version <= 0
      raise ArgumentError, "a content pack requires a title" if @title.empty?
      raise ArgumentError, "a content pack requires at least one game id" if @game_ids.empty?
      if (@data == nil) == (@loader == nil)
        raise ArgumentError, "a content pack requires either inline data or one lazy loader"
      end
      @checksum = checksum.to_s.downcase
      @checksum = digest(@data) if @checksum.empty? && @data != nil
      raise ArgumentError, "a lazy content pack requires a SHA-256 checksum" if @checksum.empty?
      raise ArgumentError, "a content pack checksum must be SHA-256" if !CHECKSUM_PATTERN.match?(@checksum)
      if @data != nil && digest(@data) != @checksum
        raise ArgumentError, "inline content pack #{@id} failed checksum verification"
      end
      @load_mutex = Mutex.new
      @verified = @data != nil
    end

    def supports?(game_id:, kind: nil)
      game_matches = @game_ids.include?("*") || @game_ids.include?(game_id.to_s)
      kind_matches = kind == nil || @kind == kind.to_s
      game_matches && kind_matches
    end

    def data
      return @data if @data != nil

      @load_mutex.synchronize do
        if @data == nil
          loaded = deep_freeze(normalize_data(@loader.call))
          raise ArgumentError, "content pack #{@id} failed checksum verification" if digest(loaded) != @checksum
          @data = loaded
          @verified = true
        end
      end
      @data
    end

    def verified?
      @verified == true
    end

    def manifest
      {
        "id" => @id,
        "set" => @set_id,
        "kind" => @kind,
        "language" => @language_id,
        "version" => @version,
        "title" => @title,
        "games" => @game_ids,
        "checksum" => @checksum,
        "license" => @license,
        "author" => @author
      }
    end

    private

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical_value(value)))
    end

    def normalize_data(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), result|
          result[GameRoomContent.utf8(key)] = normalize_data(item)
        end
      when Array
        value.map { |item| normalize_data(item) }
      when Symbol
        GameRoomContent.utf8(value)
      when String
        GameRoomContent.utf8(value)
      when Numeric, TrueClass, FalseClass, NilClass
        value
      else
        raise ArgumentError, "unsupported content pack value: #{value.class}"
      end
    end

    def canonical_value(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical_value(value[key]) }
      when Array
        value.map { |item| canonical_value(item) }
      else
        value
      end
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, item| deep_freeze(key); deep_freeze(item) }
      when Array
        value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end
  end

  class PackSet
    attr_reader :id, :kind, :title, :game_ids, :packs

    def initialize(packs)
      values = packs.to_a
      raise ArgumentError, "a content set requires at least one pack" if values.empty?

      first = values.first
      @id = first.set_id
      @kind = first.kind
      @title = first.title
      @game_ids = first.game_ids
      if values.any? do |pack|
        pack.set_id != @id || pack.kind != @kind || pack.title != @title || pack.game_ids != @game_ids
      end
        raise ArgumentError, "content set variants require matching metadata"
      end
      @packs = values.sort_by { |pack| [pack.language_id, pack.version, pack.id] }.freeze
    end

    def language_ids
      @packs.map(&:language_id).uniq
    end

    def supports?(game_id:, kind: nil)
      @packs.any? { |pack| pack.supports?(game_id: game_id, kind: kind) }
    end
  end

  class Registry
    def initialize
      @languages = {}
      @packs = {}
    end

    def register_language(profile)
      raise ArgumentError, "expected a language profile" if !profile.is_a?(LanguageProfile)
      raise ArgumentError, "duplicate language profile: #{profile.id}" if @languages.key?(profile.id)

      @languages[profile.id] = profile
      profile
    end

    def register_pack(pack)
      raise ArgumentError, "expected a content pack" if !pack.is_a?(Pack)
      raise ArgumentError, "unknown content language: #{pack.language_id}" if !@languages.key?(pack.language_id)
      raise ArgumentError, "duplicate content pack: #{pack.id}" if @packs.key?(pack.id)
      if @packs.values.any? { |current| current.set_id == pack.set_id && current.language_id == pack.language_id }
        raise ArgumentError, "duplicate content set language: #{pack.set_id}/#{pack.language_id}"
      end
      siblings = @packs.values.select { |current| current.set_id == pack.set_id }
      PackSet.new(siblings + [pack]) if !siblings.empty?

      @packs[pack.id] = pack
      pack
    end

    def language(id)
      @languages[id.to_s]
    end

    def pack(id)
      @packs[id.to_s]
    end

    def languages
      @languages.values.dup
    end

    def packs
      @packs.values.dup
    end

    def packs_for(game_id:, kind: nil)
      @packs.values.select { |pack| pack.supports?(game_id: game_id, kind: kind) }
        .sort_by { |pack| [pack.title.downcase, pack.set_id, pack.language_id, pack.version, pack.id] }
    end

    def pack_sets
      @packs.values.group_by(&:set_id).values.map { |packs| PackSet.new(packs) }
        .sort_by { |pack_set| [pack_set.title.downcase, pack_set.id] }
    end

    def pack_set(id)
      packs = @packs.values.select { |pack| pack.set_id == id.to_s }
      packs.empty? ? nil : PackSet.new(packs)
    end

    def pack_sets_for(game_id:, kind: nil)
      packs_for(game_id: game_id, kind: kind).group_by(&:set_id).values
        .map { |packs| PackSet.new(packs) }
        .sort_by { |pack_set| [pack_set.title.downcase, pack_set.id] }
    end

    def pack_for(game_id:, kind:, set_id:, language_id:)
      packs_for(game_id: game_id, kind: kind).find do |pack|
        pack.set_id == set_id.to_s && pack.language_id == language_id.to_s
      end
    end
  end

  class << self
    def registry
      @registry ||= Registry.new
    end
  end
end
