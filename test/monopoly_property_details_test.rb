require_relative "support/new_games_fixture"

game = GameRoomGames::Monopoly.new
state = game.send(:initial_state, %w[Alice Bob], game.default_options)
state[:owners].merge!(1 => "Alice", 3 => "Alice", 5 => "Alice", 12 => "Bob")
state[:cash]["Alice"] = 5000
replay = GameRoomGames::Replay.new(state: state, players: state[:players], current_player: "Alice")
board = game.custom_game_shortcuts(replay, "Alice").find { |shortcut| shortcut.key == "d" && shortcut.modifiers == [:shift] }
state[:board].each do |square|
  if [:property, :railroad, :utility].include?(square[:type])
    assert(board.choices[square[:index]].label.include?(game.send(:property_group_label, square)), "Board omits group for #{square[:index]}")
  else
    assert(board.choices[square[:index]].label == "#{square[:index]}. #{square[:name]}", "Non-property label changed")
  end
end
holdings = ->(player) { game.custom_game_shortcuts(replay, player).find { |shortcut| shortcut.key == "v" && shortcut.modifiers.empty? }.choices }
street = holdings.call("Alice").first
assert(street.label.include?("group 2 of 2") && !street.label.include?("group ownership"), "Group progress is not concise")
assert(street.value.is_a?(Array) && street.value.all? { |choice| choice.is_a?(GameRoomGames::ShortcutChoice) }, "Enter has no property details")
assert(street.value.map(&:label).join.include?("4 to Alice"), "Completed undeveloped group rent incorrect")
state[:houses][1] = 3
assert(holdings.call("Alice").first.value.map(&:label).join.include?("90 to Alice"), "Developed rent incorrect")
state[:mortgaged][1] = true
assert(holdings.call("Alice").first.value.map(&:label).join.include?("mortgaged"), "Mortgage not explained")
state[:mortgaged].delete(1)
state[:options]["no_rent_in_jail"] = true
state[:jail]["Alice"] = 1
assert(holdings.call("Alice").first.value.map(&:label).join.include?("in jail"), "Jail option not reflected")
state[:jail]["Alice"] = 0
station = holdings.call("Alice").last
assert(station.value.map(&:label).join.include?("25 to Alice"), "Railroad rent incorrect")
utility = holdings.call("Bob").first
assert(utility.value.map(&:label).join.include?("4 times"), "Utility describes stale roll instead of multiplier")
assert(state[:last_roll].to_i == 0, "Inspection changed the game")
puts "PASS Monopoly: board groups, concise ownership, nested rent details and exceptions"
