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
  profile: "standard_team",
  seed: 2_100_000,
  training_seeds: 2,
  validation_seeds: 6,
  training_score_limits: [300],
  validation_score_limits: [300],
  output: "spades-overtrick-search.json"
}
OptionParser.new do |parser|
  parser.on("--profile KEY") { |value| options[:profile] = value }
  parser.on("--seed NUMBER", Integer) { |value| options[:seed] = value }
  parser.on("--training-seeds COUNT", Integer) { |value| options[:training_seeds] = value }
  parser.on("--validation-seeds COUNT", Integer) { |value| options[:validation_seeds] = value }
  parser.on("--training-score-limits LIST") { |value| options[:training_score_limits] = value.split(",").map(&:to_i) }
  parser.on("--validation-score-limits LIST") { |value| options[:validation_score_limits] = value.split(",").map(&:to_i) }
  parser.on("--output PATH") { |value| options[:output] = value }
end.parse!

raise ArgumentError, "unknown Spades profile" if !SpadesLearning::PROFILE_KEYS.include?(options[:profile])

PRESETS = [
  [1.0, -3.0, 1.5],
  [2.0, -4.0, 2.0],
  [3.0, -5.0, 2.5],
  [4.0, -6.0, 3.0],
  [4.0, -8.0, 4.0],
  [2.0, -6.0, 4.0],
  [4.0, -4.0, 4.0],
  [2.0, -8.0, 2.0],
  [6.0, -8.0, 4.0],
  [0.0, -6.0, 4.0],
  [4.0, -10.0, 6.0],
  [2.0, -3.0, 4.0]
].freeze

def policy_with_overtrick_weights(profile, baseline, preset)
  weights = baseline.to_h
  needed, unneeded, release = preset
  weights["playing"]["needed_win_probability"] = needed
  weights["playing"]["unneeded_win_probability"] = unneeded
  weights["playing"]["unneeded_high_release"] = release
  SpadesLearning::Policy.complete(profile, weights)
end

def summary(evaluation)
  {
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
    incomplete_games: evaluation.incomplete_games
  }
end

game = GameRoomGames::Spades.new
policies = SpadesLearning::PolicySet.default
arrangements = SpadesLearning::ARRANGEMENT_PROFILES.select do |_key, (profile, _players, _team_size)|
  profile == options[:profile]
end
records = []

arrangements.each_with_index do |(arrangement, (profile, player_count, team_size)), arrangement_index|
  state = {
    options: { "quicksand" => profile.start_with?("quicksand"), "team_size" => team_size, "score_limit" => 50 },
    players: GameRoomParticipants.bots_for(1, player_count)
  }
  baseline = policies.for_state(state)
  training_scenarios = SpadesLearning::ScenarioMatrix.for_arrangement(
    profile, player_count: player_count, team_size: team_size,
    score_limits: options[:training_score_limits]
  )
  training_arena = SpadesLearning::Arena.new(game: game, scenarios: training_scenarios)
  training_seeds = Array.new(options[:training_seeds]) do |index|
    options[:seed] + arrangement_index * 10_000_000 + index * 7_919
  end
  ranked = PRESETS.map do |preset|
    candidate = policy_with_overtrick_weights(profile, baseline, preset)
    evaluation = training_arena.compare(candidate: candidate, opponent: baseline, seeds: training_seeds)
    [preset, candidate, evaluation]
  end.sort_by do |_preset, _candidate, evaluation|
    [-(evaluation.wins - evaluation.neutral_wins), -evaluation.average_margin,
      -evaluation.bid_accuracy_margin, evaluation.average_actions]
  end

  validation_scenarios = SpadesLearning::ScenarioMatrix.for_arrangement(
    profile, player_count: player_count, team_size: team_size,
    score_limits: options[:validation_score_limits]
  )
  validation_arena = SpadesLearning::Arena.new(game: game, scenarios: validation_scenarios)
  validation_seeds = Array.new(options[:validation_seeds]) do |index|
    options[:seed] + 900_000_000 + arrangement_index * 10_000_000 + index * 15_853
  end
  finalists = ranked.map do |preset, candidate, training|
    validation = validation_arena.compare(candidate: candidate, opponent: baseline, seeds: validation_seeds)
    {
      preset: preset,
      policy: candidate,
      training: training,
      validation: validation
    }
  end
  selected = finalists.select do |entry|
    evaluation = entry[:validation]
    evaluation.incomplete_games == 0 && evaluation.wins >= evaluation.neutral_wins &&
      evaluation.average_margin >= -0.01
  end.max_by do |entry|
    evaluation = entry[:validation]
    [evaluation.wins - evaluation.neutral_wins, evaluation.average_margin,
      evaluation.bid_accuracy_margin, -evaluation.average_actions]
  end

  warn format(
    "%s: %s%s",
    arrangement,
    selected == nil ? "baseline retained" : "selected ",
    selected == nil ? "" : selected[:preset].inspect
  )
  records << {
    arrangement: arrangement,
    selected: selected != nil,
    selected_preset: selected&.fetch(:preset),
    selected_weights: selected&.fetch(:policy)&.to_h,
    finalists: finalists.map do |entry|
      {
        preset: entry[:preset],
        training: summary(entry[:training]),
        validation: summary(entry[:validation])
      }
    end
  }
end

report = {
  generated_at: Time.now.utc.iso8601,
  settings: options.reject { |key, _value| key == :output },
  profile: options[:profile],
  arrangements: records
}
File.write(options[:output], JSON.pretty_generate(report))
warn "Saved #{options[:output]}"
