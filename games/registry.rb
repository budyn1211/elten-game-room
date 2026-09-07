module GameRoomGames
  class Registry
    def initialize(game_types)
      @game_types = {}
      game_types.each do |game_type|
        game = game_type.new
        id = game.id.to_s
        raise ArgumentError, "a game must have an id" if id.empty?
        raise ArgumentError, "duplicate game id: #{id}" if @game_types.key?(id)

        game.rule_book

        @game_types[id] = game_type
      end
    end

    def ids
      @game_types.keys.dup
    end

    def build(id)
      game_type = @game_types[id.to_s]
      game_type == nil ? nil : game_type.new
    end

    def name(id)
      game = build(id)
      game == nil ? nil : game.name
    end
  end
end
