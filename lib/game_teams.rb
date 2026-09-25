require_relative "game_participants"
require_relative "game_random"

require_relative "game_room_localization"

module GameRoomTeams
  using GameRoomLocalization::Translations
  OPTION_KEY = "team_seats"
  PLAYERS_KEY = "team_players"

  class Assignment
    attr_reader :players, :team_size, :team_count, :seats

    def initialize(players:, team_size:, seats: nil)
      @players = GameRoomParticipants.unique(players)
      @initial_players = @players.dup.freeze
      @team_size = team_size.to_i
      if @team_size <= 0 || @players.length % @team_size != 0
        raise ArgumentError, "players cannot be divided into teams of the requested size"
      end

      @team_count = @players.length / @team_size
      raise ArgumentError, "team play requires at least two teams" if @team_count < 2

      @seats = normalized_seats(seats)
    end

    def reset
      @players = @initial_players.dup
      @seats = automatic_seats
      self
    end

    def randomize(random: Random.new)
      @players = GameRoomRandom.shuffle(@initial_players, random: random)
      @seats = automatic_seats
      self
    end

    def assign(player_index, team_index)
      player = player_index.to_i
      team = team_index.to_i
      raise ArgumentError, "unknown player seat" if !player.between?(0, @players.length - 1)
      raise ArgumentError, "unknown team" if !team.between?(0, @team_count - 1)

      @seats[player] = team
      self
    end

    # Team slots stay in place; only the people occupying them move. Persist
    # the resulting assignment in the original roster order, not UI order.
    def move(index, direction)
      raise ArgumentError, 'unknown player seat' unless index.is_a?(Integer) && index.between?(0, @players.length - 1)
      raise ArgumentError, 'invalid team movement' unless [-1, 1].include?(direction)
      target = index + direction
      return index unless target.between?(0, @players.length - 1)
      @players[index], @players[target] = @players[target], @players[index]
      target
    end

    def seats_for(players)
      players.map { |player| team_index_for(player) }
    end

    def valid?
      validation_error == nil
    end

    def validation_error
      @team_count.times do |team|
        count = @seats.count(team)
        next if count == @team_size

        return _("Team %{team} must contain exactly %{count} players; it currently contains %{actual}.") % {
          team: team + 1,
          count: @team_size,
          actual: count
        }
      end
      nil
    end

    def team_ids
      Array.new(@team_count) { |index| "team:#{index}" }
    end

    def team_index_for(participant)
      index = @players.index { |player| GameRoomParticipants.same?(player, participant) }
      index == nil ? nil : @seats[index]
    end

    def team_number_for(participant)
      index = team_index_for(participant)
      index == nil ? nil : index + 1
    end

    def members_for(team)
      team_index = team.to_s.start_with?("team:") ? team.to_s.delete_prefix("team:").to_i : team.to_i
      return [] if !team_index.between?(0, @team_count - 1)

      @players.each_with_index.select { |_player, index| @seats[index] == team_index }.map(&:first)
    end

    def teammates_for(participant)
      team = team_index_for(participant)
      team == nil ? [] : members_for(team)
    end

    private

    def normalized_seats(value)
      candidates = value.to_a.map(&:to_i)
      valid_shape = candidates.length == @players.length && candidates.all? do |team|
        team.between?(0, @team_count - 1)
      end
      valid_shape ? candidates : automatic_seats
    end

    def automatic_seats
      Array.new(@players.length) { |index| index % @team_count }
    end
  end
end
