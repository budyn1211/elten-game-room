require_relative 'training/spades_training'
require "json"
require "optparse"
require "time"

def _(text)
  text
end

require_relative "../lib/spades_learning"
require_relative "../games/spades"

options = {
  report: nil,
  profiles: nil,
  seeds: 40,
  seed: 12_000_000,
  max_actions: 6_000,
  output: nil
}
OptionParser.new do |parser|
  parser.on("--report PATH") { |value| options[:report] = value }
  parser.on("--profiles LIST") { |value| options[:profiles] = value.split(",") }
  parser.on("--seeds COUNT", Integer) { |value| options[:seeds] = value }
  parser.on("--seed NUMBER", Integer) { |value| options[:seed] = value }
  parser.on("--max-actions COUNT", Integer) { |value| options[:max_actions] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
end.parse!

raise ArgumentError, "--report is required" if options[:report].to_s.empty?

training = JSON.parse(File.read(options[:report]))
selected = training.fetch("selected_profiles")
profiles = options[:profiles] || training.fetch("arrangements").select do |entry|
  entry["accepted"] == true
end.map { |entry| entry.fetch("arrangement") }
unknown = profiles - SpadesLearning::ARRANGEMENT_PROFILES.keys
raise ArgumentError, "unknown arrangements: #{unknown.join(', ')}" if !unknown.empty?

game = GameRoomGames::Spades.new
baseline_set = SpadesLearning::PolicySet.default
seeds = Array.new(options[:seeds]) { |index| options[:seed] + index * 1_009 }
records = profiles.map do |arrangement|
  profile, player_count, team_size = SpadesLearning::ARRANGEMENT_PROFILES.fetch(arrangement)
  scenarios = SpadesLearning::ScenarioMatrix.for_arrangement(
    profile,
    player_count: player_count,
    team_size: team_size,
    score_limits: [300]
  )
  state = {
    options: scenarios.first.options,
    players: GameRoomParticipants.bots_for(1, player_count)
  }
  candidate = SpadesLearning::Policy.complete(profile, selected.fetch(arrangement))
  baseline = baseline_set.for_state(state)
  arena = SpadesLearning::Arena.new(
    game: game,
    scenarios: scenarios,
    max_actions: options[:max_actions]
  )
  evaluation = arena.compare(candidate: candidate, opponent: baseline, seeds: seeds)
  quicksand = scenarios.all? { |scenario| scenario.quicksand == true }
  record = {
    arrangement: arrangement,
    games: evaluation.games,
    wins: evaluation.wins,
    neutral_wins: evaluation.neutral_wins,
    average_margin: evaluation.average_margin,
    quality_advantage: evaluation.quality_advantage(quicksand: quicksand),
    candidate_contract_rate: evaluation.candidate_contract_rate,
    opponent_contract_rate: evaluation.opponent_contract_rate,
    candidate_bid_error: evaluation.candidate_bid_error,
    opponent_bid_error: evaluation.opponent_bid_error,
    candidate_bid_bias: evaluation.candidate_bid_bias,
    opponent_bid_bias: evaluation.opponent_bid_bias,
    candidate_average_overtricks: evaluation.candidate_average_overtricks,
    opponent_average_overtricks: evaluation.opponent_average_overtricks,
    candidate_average_shortfall: evaluation.candidate_average_shortfall,
    opponent_average_shortfall: evaluation.opponent_average_shortfall,
    average_actions: evaluation.average_actions,
    average_rounds: evaluation.average_rounds,
    incomplete_games: evaluation.incomplete_games
  }
  warn format(
    "%s: %d/%d wins, margin %+.4f, quality %+.4f, contracts %.1f%%/%.1f%%, incomplete %d",
    arrangement, evaluation.wins, evaluation.neutral_wins,
    evaluation.average_margin, record[:quality_advantage],
    evaluation.candidate_contract_rate * 100.0,
    evaluation.opponent_contract_rate * 100.0,
    evaluation.incomplete_games
  )
  record
end

report = {
  generated_at: Time.now.utc.iso8601,
  source_report: options[:report],
  seed: options[:seed],
  seeds: options[:seeds],
  arrangements: records
}
json = JSON.pretty_generate(report)
if options[:output].to_s.empty?
  puts json
else
  File.write(options[:output], json)
end
