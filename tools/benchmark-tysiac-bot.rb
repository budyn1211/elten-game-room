def _(text)
  text
end

require_relative "../lib/game_simulation"
require_relative "../games/tysiac"

match_count = [ARGV.fetch(0, "9").to_i, 1].max
game = GameRoomGames::Tysiac.new
players = GameRoomParticipants.bots_for(1, 3)
planner = game.bot_strategy
heuristic = GameRoomBots::HeuristicStrategy.new
wins = Hash.new(0)
failures = Hash.new(0)
elapsed = Hash.new(0.0)

match_count.times do |index|
  planner_seat = index % players.length
  strategies = players.each_with_index.to_h do |player, seat|
    [player, seat == planner_seat ? planner : heuristic]
  end
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = GameRoomSimulation::MatchRunner.new(
    game: game,
    players: players,
    strategies: strategies,
    max_actions: 10_000
  ).run(seed: index + 1)
  duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  elapsed[planner_seat] += duration
  if !result.finished?
    failures[result.reason] += 1
    next
  end

  winner_seat = players.index(result.winner)
  wins[winner_seat == planner_seat ? :planner : :heuristic] += 1
  puts "match=#{index + 1} planner_seat=#{planner_seat + 1} winner_seat=#{winner_seat + 1} actions=#{result.actions} seconds=#{duration.round(3)}"
end

puts "planner_wins=#{wins[:planner]} heuristic_wins=#{wins[:heuristic]} failures=#{failures.values.sum}"
puts "planner_seat_seconds=#{players.each_index.map { |seat| (elapsed[seat] / [match_count / players.length, 1].max).round(3) }.join(',')}"
