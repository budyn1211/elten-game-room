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
  profiles: SpadesLearning::ARRANGEMENT_PROFILES.keys,
  seeds: 5,
  seed: 90_000,
  score_limits: [300],
  max_actions: 6_000,
  playing_weights: {},
  calibration: true,
  output: nil
}
OptionParser.new do |parser|
  parser.on("--profiles LIST") { |value| options[:profiles] = value.split(",") }
  parser.on("--seeds COUNT", Integer) { |value| options[:seeds] = value }
  parser.on("--seed NUMBER", Integer) { |value| options[:seed] = value }
  parser.on("--score-limits LIST") { |value| options[:score_limits] = value.split(",").map(&:to_i) }
  parser.on("--max-actions COUNT", Integer) { |value| options[:max_actions] = value }
  parser.on("--playing-weights LIST") do |value|
    options[:playing_weights] = value.split(",").to_h do |entry|
      name, weight = entry.split("=", 2)
      raise OptionParser::InvalidArgument, entry if name.to_s.empty? || weight.to_s.empty?

      [name, Float(weight)]
    end
  end
  parser.on("--skip-calibration") { options[:calibration] = false }
  parser.on("--output PATH") { |value| options[:output] = value }
end.parse!

unknown = options[:profiles] - SpadesLearning::ARRANGEMENT_PROFILES.keys
raise ArgumentError, "unknown arrangements: #{unknown.join(', ')}" if !unknown.empty?

game = GameRoomGames::Spades.new
completed = SpadesLearning::PolicySet.default
build_50_fallbacks = %w[
  standard_individual_p3 standard_individual_p4 quicksand_team_p4_t2
].freeze
seeds = Array.new(options[:seeds]) { |index| options[:seed] + index * 1_009 }
records = []

SpadesLearning::ARRANGEMENT_PROFILES.each do |arrangement, (profile, player_count, team_size)|
  next if !options[:profiles].include?(arrangement)
  scenarios = SpadesLearning::ScenarioMatrix.for_arrangement(
    profile,
    player_count: player_count,
    team_size: team_size,
    score_limits: options[:score_limits]
  )
  state = { options: scenarios.first.options, players: GameRoomParticipants.bots_for(1, player_count) }
  arena = SpadesLearning::Arena.new(game: game, scenarios: scenarios, max_actions: options[:max_actions])
  completed_policy = completed.for_state(state)
  if !options[:playing_weights].empty?
    weights = completed_policy.to_h
    weights["playing"].merge!(options[:playing_weights])
    completed_policy = SpadesLearning::Policy.complete(profile, weights)
  end
  legacy_policy = if build_50_fallbacks.include?(arrangement)
    SpadesLearning::Policy.default
  else
    SpadesLearning::Policy.new(SpadesLearning::TRAINED_PROFILE_WEIGHTS.fetch(profile))
  end
  evaluation = arena.compare(
    candidate: completed_policy,
    opponent: legacy_policy,
    seeds: seeds
  )
  completed_calibration = if options[:calibration]
    arena.compare(candidate: completed_policy, opponent: completed_policy, seeds: seeds)
  end
  legacy_calibration = if options[:calibration]
    arena.compare(candidate: legacy_policy, opponent: legacy_policy, seeds: seeds)
  end
  record = {
    arrangement: arrangement,
    profile: profile,
    player_count: player_count,
    team_size: team_size,
    games: evaluation.games,
    wins: evaluation.wins,
    neutral_wins: evaluation.neutral_wins,
    average_margin: evaluation.average_margin,
    average_actions: evaluation.average_actions,
    average_rounds: evaluation.average_rounds,
    bid_accuracy_margin: evaluation.bid_accuracy_margin,
    candidate_bid_error: evaluation.candidate_bid_error,
    opponent_bid_error: evaluation.opponent_bid_error,
    candidate_bid_bias: evaluation.candidate_bid_bias,
    opponent_bid_bias: evaluation.opponent_bid_bias,
    candidate_contract_rate: evaluation.candidate_contract_rate,
    opponent_contract_rate: evaluation.opponent_contract_rate,
    candidate_average_overtricks: evaluation.candidate_average_overtricks,
    opponent_average_overtricks: evaluation.opponent_average_overtricks,
    candidate_average_shortfall: evaluation.candidate_average_shortfall,
    opponent_average_shortfall: evaluation.opponent_average_shortfall,
    quality_advantage: evaluation.quality_advantage(
      quicksand: scenarios.all? { |scenario| scenario.quicksand == true }
    ),
    average_table_bid_gap: evaluation.average_table_bid_gap,
    average_table_bid_deficit: evaluation.average_table_bid_deficit,
    completed_calibration: completed_calibration == nil ? nil : {
      bid_error: completed_calibration.candidate_bid_error,
      bid_bias: completed_calibration.candidate_bid_bias,
      average_actions: completed_calibration.average_actions,
      average_rounds: completed_calibration.average_rounds,
      table_bid_gap: completed_calibration.average_table_bid_gap,
      table_bid_deficit: completed_calibration.average_table_bid_deficit,
      contract_rate: completed_calibration.candidate_contract_rate,
      average_overtricks: completed_calibration.candidate_average_overtricks,
      average_shortfall: completed_calibration.candidate_average_shortfall
    },
    legacy_calibration: legacy_calibration == nil ? nil : {
      bid_error: legacy_calibration.candidate_bid_error,
      bid_bias: legacy_calibration.candidate_bid_bias,
      average_actions: legacy_calibration.average_actions,
      average_rounds: legacy_calibration.average_rounds,
      table_bid_gap: legacy_calibration.average_table_bid_gap,
      table_bid_deficit: legacy_calibration.average_table_bid_deficit,
      contract_rate: legacy_calibration.candidate_contract_rate,
      average_overtricks: legacy_calibration.candidate_average_overtricks,
      average_shortfall: legacy_calibration.candidate_average_shortfall
    },
    incomplete_games: evaluation.incomplete_games
  }
  records << record
  warn format(
    "%s: %d/%d wins, margin %+.4f, bid %+.4f, bias %+.3f, " \
      "contracts %.1f%%, over %.2f, short %.2f, deficit %+.3f, incomplete %d",
    arrangement, evaluation.wins, evaluation.neutral_wins,
    evaluation.average_margin, evaluation.bid_accuracy_margin,
    evaluation.candidate_bid_bias, evaluation.candidate_contract_rate * 100.0,
    evaluation.candidate_average_overtricks, evaluation.candidate_average_shortfall,
    evaluation.average_table_bid_deficit, evaluation.incomplete_games
  )
end

report = {
  generated_at: Time.now.utc.iso8601,
  seed: options[:seed],
  seeds: options[:seeds],
  score_limits: options[:score_limits],
  playing_weights: options[:playing_weights],
  comparison: "selected profiles versus the exact build 50 checkpoints",
  arrangements: records
}
json = JSON.pretty_generate(report)
if options[:output]
  File.write(options[:output], json)
else
  puts json
end
