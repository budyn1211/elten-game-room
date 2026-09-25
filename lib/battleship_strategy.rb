require_relative "game_bots"

module BattleshipPlanning
  class Strategy
    include GameRoomBots::ReplayOnlyStrategy

    def initialize(fallback: GameRoomBots::HeuristicStrategy.new)
      @fallback = fallback
    end

    def choose(actions:, actor:, random_source:, game:, replay:, context: nil, **_extra)
      choices = actions.to_a
      return nil if choices.empty?
      return choices.first if choices.length == 1
      @fallback.choose(actions: choices, actor: actor, random_source: random_source,
        game: game, replay: replay, context: context)
    end

    def cell_value(game, state, player, cell)
      shots = state[:shots].fetch(player, {})
      return -1_000.0 if shots.key?(cell)
      key = [shots.to_a, game.fleet_of(state), !!state[:options]["touching"], game.board_size]
      if @score_key != key
        @scores = placement_scores(shots, game.fleet_of(state), key[2], key[3])
        @score_key = key
      end
      @scores.fetch(cell, -500.0)
    end

    private

    # Only public, chronological answers enter this model. With touching ships,
    # adjacent hits need not belong to the ship just sunk; retain uncertainty.
    def placement_scores(shots, fleet, touching, size)
      remaining = fleet.dup
      finished = []
      observed = {}
      shots.each do |cell, result|
        observed[cell] = result
        next if result != "sunk"
        hits = observed.keys.select { |square| observed[square] != "miss" && !finished.include?(square) }
        if touching
          candidates = placements(remaining, size).select do |ship|
            ship.include?(cell) && ship.all? { |square| hits.include?(square) } &&
              ship.none? { |square| square != cell && observed[square] == "sunk" }
          end
          certain = candidates.empty? ? [cell] : candidates.reduce { |a, b| a & b }
          lengths = candidates.map(&:length).uniq
          remove_size(remaining, lengths.first) if lengths.length == 1
        else
          certain = [cell]
          queue = [cell]
          until queue.empty?
            neighbours(queue.shift, size).each do |near|
              next unless hits.include?(near) && !certain.include?(near)
              certain << near
              queue << near
            end
          end
          remove_size(remaining, certain.length)
        end
        finished |= certain
      end
      blocked = finished + shots.select { |_, result| result == "miss" }.keys
      unless touching
        finished.each { |cell| blocked.concat(neighbours(cell, size, diagonal: true)) }
      end
      wounded = shots.keys.select { |cell| shots[cell] == "hit" && !finished.include?(cell) }
      scores = {}
      placements(remaining, size).each do |ship|
        next if (ship & blocked).any?
        hits = (ship & wounded).length
        ship.each do |cell|
          next if shots.key?(cell)
          scores[cell] = (scores[cell] || 0.0) + 1.0 + hits * 1_000.0
        end
      end
      scores
    end

    def remove_size(fleet, length)
      index = fleet.index(length)
      fleet.delete_at(index) if index
    end

    def placements(fleet, size)
      fleet.flat_map do |length|
        (0...(size * size)).flat_map do |cell|
          choices = []
          choices << (0...length).map { |step| cell + step } if cell % size + length <= size
          choices << (0...length).map { |step| cell + step * size } if length > 1 && cell / size + length <= size
          choices
        end
      end
    end

    def neighbours(cell, size, diagonal: false)
      offsets = diagonal ? [-1, 0, 1].product([-1, 0, 1]) : [[1, 0], [-1, 0], [0, 1], [0, -1]]
      offsets.filter_map do |dx, dy|
        next if dx.zero? && dy.zero?
        x, y = cell % size + dx, cell / size + dy
        y * size + x if x.between?(0, size - 1) && y.between?(0, size - 1)
      end
    end
  end
end
