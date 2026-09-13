# encoding: UTF-8
module GameRoomContent
  module WitcherPolishSets
    VALID_SCOPES = [:all, :games, :books_screen].freeze

    def self.load(scope)
      scope = scope.to_sym
      raise ArgumentError, "unknown Witcher question scope: #{scope}" if !VALID_SCOPES.include?(scope)

      source = source_data
      classification = medium_data
      questions = source.fetch("questions")
      media = classification.fetch("media")
      prompts = classification.fetch("prompts")
      ids = questions.map { |question| question.fetch("id") }
      raise ArgumentError, "Witcher medium data does not cover the source pack" if media.keys.sort != ids.sort

      selected = questions.filter_map do |question|
        id = question.fetch("id")
        code = media.fetch(id)
        next if scope == :games && code != "g"
        next if scope == :books_screen && code == "g"

        replacement = prompts[id]
        replacement == nil ? question : question.merge("prompt" => replacement)
      end
      {
        "questions" => selected,
        "source" => source.fetch("source"),
        "data_version" => classification.fetch("version")
      }
    end

    def self.source_data
      return @source_data if @source_data != nil
      require_relative "quiz_witcher_pl_data"
      @source_data = GameRoomContent::Pack1f9366a686ccc2dddda06ad6.load
    end

    def self.medium_data
      return @medium_data if @medium_data != nil
      require_relative "quiz_witcher_pl_medium_data"
      @medium_data = GameRoomContent::WitcherPolishMediumData.load
    end
  end
end
