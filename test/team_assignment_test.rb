def _(text)
  text
end

require_relative "../lib/game_teams"
require_relative "../games/base"

def assert(condition, message)
  raise message if !condition
end

four = ["Alice", "Bob", "Carol", "Dave"]
pairs = GameRoomTeams::Assignment.new(players: four, team_size: 2)
assert(pairs.seats == [0, 1, 0, 1], "four-player teams were not assigned alternately")
assert(pairs.members_for("team:0") == ["Alice", "Carol"], "the first automatic pair is incorrect")
assert(pairs.members_for("team:1") == ["Bob", "Dave"], "the second automatic pair is incorrect")
assert(pairs.valid?, "the automatic four-player assignment is invalid")

pairs.assign(1, 0)
assert(!pairs.valid?, "an overfilled team was accepted")
assert(pairs.validation_error.include?("Team 1"), "team validation did not identify the invalid team")
pairs.assign(2, 1)
assert(pairs.valid?, "a manually swapped pair was rejected")
assert(pairs.members_for(0) == ["Alice", "Bob"], "a manual team selection was not retained")
assert(pairs.team_number_for("bob") == 1, "team lookup is not case-insensitive")

six = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank"]
six_pairs = GameRoomTeams::Assignment.new(players: six, team_size: 2)
assert(six_pairs.seats == [0, 1, 2, 0, 1, 2], "three automatic pairs are incorrect")
six_triples = GameRoomTeams::Assignment.new(players: six, team_size: 3)
assert(six_triples.seats == [0, 1, 0, 1, 0, 1], "two automatic triples are incorrect")

class TeamContractGame < GameRoomGames::Base
  def team_size(_options, player_count:)
    player_count == 4 ? 2 : 0
  end
end

game = TeamContractGame.new
stored = game.with_team_assignment({}, players: four, seats: [0, 0, 1, 1])
assert(stored[GameRoomTeams::OPTION_KEY] == [0, 0, 1, 1], "the shared game contract lost team seats")
restored = game.team_assignment(JSON.parse(JSON.generate(stored)), players: four)
assert(restored.members_for(0) == ["Alice", "Bob"], "saved teams were not restored from session JSON")

puts "Team assignment framework tests passed"
