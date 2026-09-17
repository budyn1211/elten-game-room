require "base64"
require "zlib"
require_relative "game_content"

module GameRoomWords
  # The content manifest authenticates compressed, sorted blocks. Keep only a
  # small working set inflated; Polish has millions of inflected word forms.
  class Lexicon
    def initialize(pack, language)
      @data, @language = pack.data, language
      @keys, @blocks = @data.fetch("keys"), @data.fetch("blocks")
      raise ArgumentError, "Invalid word dictionary" unless @keys.length == @blocks.length && !@keys.empty?
      @cache = {}
      @mutex = Mutex.new
    end

    def include?(word)
      word = @language.normalize(word)
      return false unless word.length.between?(2, 15) && @language.valid_word_shape?(word)
      index = @keys.bsearch_index { |key| key > word }
      index = (index || @keys.length) - 1
      return false if index < 0
      @mutex.synchronize do
        words = @cache.delete(index)
        unless words
          text = Zlib::Inflate.inflate(Base64.strict_decode64(@blocks[index])).force_encoding("UTF-8")
          raise ArgumentError, "Invalid word block" unless text.valid_encoding? && text.bytesize <= 131_072
          words = text.split("\n").freeze
        end
        @cache[index] = words
        @cache.shift while @cache.length > 16
        candidate = words.bsearch { |entry| entry >= word }
        candidate == word
      end
    end
  end
end
