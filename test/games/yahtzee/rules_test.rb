require_relative '../../support/new_games_fixture'

players = %w[Alice Bob Carol]
repository = NewGames116Repository.new(players)

yahtzee = GameRoomGames::Yahtzee.new
yahtzee_session = { "options" => JSON.generate(yahtzee.default_options) }
yahtzee_events = []
yahtzee_replay = yahtzee.replay(yahtzee_session, yahtzee_events, repository)
roll = yahtzee.legal_actions(yahtzee_replay, "Alice").first
yahtzee_replay = append_action(yahtzee, yahtzee_session, repository, yahtzee_events, yahtzee_replay, "Alice", roll, context_for)
assert(yahtzee_replay.state[:dice] == yahtzee_replay.state[:dice].sort, "Yahtzee dice are not sorted")
assert(yahtzee_replay.state[:turn_rolls] == 1, "Yahtzee did not count the first roll")
yahtzee_surface = yahtzee.surface_spec(yahtzee_replay, "Alice")
assert(yahtzee_surface.header == yahtzee.name && yahtzee_surface.roll_number == 1,
  "Yahtzee does not expose the stable one-field roll surface")
shortcut_signatures = yahtzee.custom_game_shortcuts(yahtzee_replay, "Alice").map do |shortcut|
  [shortcut.key, shortcut.modifiers]
end
1.upto(6) do |value|
  assert(shortcut_signatures.include?([value.to_s, []]) && shortcut_signatures.include?([value.to_s, [:shift]]),
    "Yahtzee is missing die-value shortcut #{value}")
end
assert(shortcut_signatures.include?(["space", []]), "Yahtzee is missing the dice status shortcut")
assert(yahtzee.custom_game_shortcuts(yahtzee_replay, "Alice").all? do |shortcut|
  !shortcut.payload.key?("number")
end, "Yahtzee shortcuts still select dice by position")
score = yahtzee.legal_actions(yahtzee_replay, "Alice").find { |action| action["action"] == "score" }
yahtzee_replay = append_action(yahtzee, yahtzee_session, repository, yahtzee_events, yahtzee_replay, "Alice", score)
assert(yahtzee_replay.current_player == "Bob", "Yahtzee did not advance after scoring")
assert(!yahtzee.default_options.key?("yahtzee_bonus") && !yahtzee.default_options.key?("joker_rule"),
  "Yahtzee must not expose the retired bonus or Joker options")
[[[1,1,1,1,2],15],[[2,2,2,2,6],15],[[3,3,3,3,6],18],[[1,1,1,1,1],40],[[1,1,1,2,3],0]].each do |dice,expected|
  assert(yahtzee.send(:score_category,'four_kind',dice,yahtzee_replay.state,'Alice')==expected,
    "Four of a kind must award at least 15, or 40 for Yahtzee, only for a qualifying roll: #{dice.inspect}")
end

puts 'PASS yahtzee: rules, legal actions and options'
