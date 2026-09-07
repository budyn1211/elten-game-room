require "json"
require "optparse"
require "time"

def _(text)
  text
end

require_relative "../lib/spades_learning"
require_relative "../games/spades"

options = {
  arrangement: nil,
  seed: 1_700_000,
  samples: 120,
  finalists: 8,
  training_seeds: 3,
  validation_seeds: 16,
  score_limits: [300],
  max_actions: 3_000,
  output: "spades-bidding-search.json"
}
OptionParser.new do |parser|
  parser.on("--arrangement KEY") { |value| options[:arrangement] = value }
  parser.on("--seed NUMBER", Integer) { |value| options[:seed] = value }
  parser.on("--samples COUNT", Integer) { |value| options[:samples] = value }
  parser.on("--finalists COUNT", Integer) { |value| options[:finalists] = value }
  parser.on("--training-seeds COUNT", Integer) { |value| options[:training_seeds] = value }
  parser.on("--validation-seeds COUNT", Integer) { |value| options[:validation_seeds] = value }
  parser.on("--score-limits LIST") { |value| options[:score_limits] = value.split(",").map(&:to_i) }
  parser.on("--max-actions COUNT", Integer) { |value| options[:max_actions] = value }
  parser.on("--output PATH") { |value| options[:output] = value }
end.parse!

raise ArgumentError, "--arrangement is required" if options[:arrangement] == nil
profile, player_count, team_size = SpadesLearning::ARRANGEMENT_PROFILES.fetch(options[:arrangement])
game = GameRoomGames::Spades.new
scenarios = SpadesLearning::ScenarioMatrix.for_arrangement(
  profile,
  player_count: player_count,
  team_size: team_size,
  score_limits: options[:score_limits]
)
state = { options: scenarios.first.options, players: GameRoomParticipants.bots_for(1, player_count) }
baseline = SpadesLearning::PolicySet.default.for_state(state)
arena = SpadesLearning::Arena.new(game: game, scenarios: scenarios, max_actions: options[:max_actions])
random = Random.new(options[:seed])
training_seeds = Array.new(options[:training_seeds]) { |index| options[:seed] + index * 7_919 }
validation_seeds = Array.new(options[:validation_seeds]) do |index|
  options[:seed] + 900_000_000 + index * 15_853
end

ranges = {
  "distance" => 4.0..14.0,
  "overbid" => 0.0..6.0,
  "underbid" => 0.0..8.0,
  "contract_size" => 0.0..12.0,
  "certain_tricks" => 0.0..8.0,
  "table_bid_balance" => 0.0..12.0,
  "table_underbid_pressure" => 0.0..12.0,
  "table_overbid_pressure" => 0.0..6.0,
  "last_bid_table_balance" => 0.0..18.0
}.freeze

def random_value(random, range)
  range.begin + random.rand * (range.end - range.begin)
end

policies = [baseline]
options[:samples].times do
  weights = baseline.to_h
  ranges.each do |name, range|
    weights["bidding"][name] = random_value(random, range)
  end
  policies << SpadesLearning::Policy.complete(profile, weights)
end

ranked = policies.each_with_index.map do |policy, index|
  evaluation = arena.compare(candidate: policy, opponent: policy, seeds: training_seeds)
  match = arena.compare(candidate: policy, opponent: baseline, seeds: training_seeds)
  normalized_gap = evaluation.average_table_bid_gap / [player_count, 1].max.to_f
  score = evaluation.candidate_bid_error + normalized_gap * 0.15
  viable = match.wins >= match.neutral_wins && match.average_margin >= -0.10 &&
    match.incomplete_games == 0
  warn format(
    "candidate %d/%d: %s, %d/%d wins, margin %+.3f, error %.3f, bias %+.3f, gap %.3f",
    index + 1, policies.length, viable ? "viable" : "unsafe",
    match.wins, match.neutral_wins, match.average_margin,
    evaluation.candidate_bid_error, evaluation.candidate_bid_bias, evaluation.average_table_bid_gap
  ) if (index + 1) % 20 == 0
  [policy, evaluation, match, score, viable]
end.sort_by { |_policy, _evaluation, _match, score, viable| [viable ? 0 : 1, score] }

baseline_calibration = arena.compare(candidate: baseline, opponent: baseline, seeds: validation_seeds)
finalists = ranked.first(options[:finalists]).map.with_index do |(policy, training, training_match, _score, _viable), index|
  calibration = arena.compare(candidate: policy, opponent: policy, seeds: validation_seeds)
  head_to_head = arena.compare(candidate: policy, opponent: baseline, seeds: validation_seeds)
  accepted = policy.weights != baseline.weights && calibration.incomplete_games == 0 &&
    head_to_head.incomplete_games == 0 &&
    calibration.candidate_bid_error < baseline_calibration.candidate_bid_error - 0.03 &&
    calibration.average_table_bid_gap < baseline_calibration.average_table_bid_gap - 0.10 &&
    head_to_head.wins >= head_to_head.neutral_wins && head_to_head.average_margin >= -0.01
  warn format(
    "finalist %d: %s, %d/%d wins, margin %+.4f, error %.3f, bias %+.3f, gap %.3f",
    index + 1, accepted ? "accepted" : "rejected",
    head_to_head.wins, head_to_head.neutral_wins, head_to_head.average_margin,
    calibration.candidate_bid_error, calibration.candidate_bid_bias,
    calibration.average_table_bid_gap
  )
  {
    policy: policy,
    accepted: accepted,
    training: training,
    training_match: training_match,
    calibration: calibration,
    head_to_head: head_to_head
  }
end

selected = finalists.select { |entry| entry[:accepted] }.min_by do |entry|
  [entry[:calibration].candidate_bid_error, entry[:calibration].average_table_bid_gap,
    -entry[:head_to_head].average_margin]
end
selected_policy = selected == nil ? baseline : selected[:policy]

serialize = lambda do |evaluation|
  {
    games: evaluation.games,
    wins: evaluation.wins,
    neutral_wins: evaluation.neutral_wins,
    average_margin: evaluation.average_margin,
    average_actions: evaluation.average_actions,
    average_rounds: evaluation.average_rounds,
    bid_accuracy_margin: evaluation.bid_accuracy_margin,
    bid_error: evaluation.candidate_bid_error,
    bid_bias: evaluation.candidate_bid_bias,
    table_bid_gap: evaluation.average_table_bid_gap,
    table_bid_deficit: evaluation.average_table_bid_deficit,
    incomplete_games: evaluation.incomplete_games
  }
end
report = {
  generated_at: Time.now.utc.iso8601,
  settings: options.reject { |key, _value| key == :output },
  arrangement: options[:arrangement],
  accepted: selected != nil,
  baseline_calibration: serialize.call(baseline_calibration),
  selected_profile: selected_policy.to_h,
  finalists: finalists.map do |entry|
    {
      accepted: entry[:accepted],
      training: serialize.call(entry[:training]),
      training_match: serialize.call(entry[:training_match]),
      calibration: serialize.call(entry[:calibration]),
      head_to_head: serialize.call(entry[:head_to_head])
    }
  end
}
File.write(options[:output], JSON.pretty_generate(report))
warn "Saved #{options[:output]} (#{selected == nil ? 'baseline retained' : 'candidate accepted'})"
