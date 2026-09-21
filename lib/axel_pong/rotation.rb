module GameRoomPong
  class Rotation
    attr_reader :teams, :server, :receiver

    def initialize(teams: [0, 1], rally: 0, first_server: 0)
      raise ArgumentError unless teams.is_a?(Array) && teams.all? { |team| team.is_a?(Integer) && [0, 1].include?(team) } &&
        (teams == [0, 1] || (teams.length == 4 && teams.count(0) == 2 && teams.count(1) == 2))
      @teams = teams.dup.freeze
      if doubles?
        a, b = members(first_server)
        c, d = members(1 - first_server)
        pairs = [[a, c], [d, b], [b, d], [c, a], [a, d], [c, b], [b, c], [d, a]]
        @server, @receiver = pairs[(rally / 2) % pairs.length]
        @ring = [@server, @receiver,
          (members(team(@server)) - [@server]).first,
          (members(team(@receiver)) - [@receiver]).first].freeze
      else
        @server = (first_server + rally / 2) % 2
        @receiver = 1 - @server
        @ring = [@server, @receiver].freeze
      end
    end

    def team(seat); @teams[seat]; end

    def doubles?; @teams.length == 4; end

    def hitter(turn); @ring[turn % @ring.length]; end

    def members(team); @teams.each_index.select { |seat| @teams[seat] == team }; end
  end
end
