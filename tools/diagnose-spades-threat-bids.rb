def _(text)
  text
end

require_relative "../games/spades"

ReplayForThreatBid = Struct.new(:state, :accepted_events, :players)

game = GameRoomGames::Spades.new
players = ["papierek", "bot:128:1", "bot:128:2"]
options = {
  "score_limit" => 300,
  "team_size" => 0,
  "no_hell" => false,
  "quicksand" => false,
  "suicide" => false,
  "omniscient_bots" => true
}
states = {
  ruff: {
    players: players, options: options.dup, units: players,
    scores: players.to_h { |player| [player, 0] }, round: 1, dealer_index: 2,
    bids: { "papierek" => 5, "bot:128:1" => 6 },
    tricks: players.to_h { |player| [player, 0] },
    hands: {
      "papierek" => %w[7S 7C 4C JD 2D 4D TS QC 6C 3D QS KC 6S JS TC 5S 9D],
      "bot:128:1" => %w[2S AD AC QH 4S 9H KH 8H 5C 5H QD 9S 3S 4H 9C TD 7D],
      "bot:128:2" => %w[5D KS 6H 8C KD AH JC 2H 3C TH AS 6D 8D JH 3H 8S 7H]
    },
    current_trick: [], current_player: "bot:128:2", spades_broken: false,
    phase: :bidding, winner: nil
  },
  weak_trump: {
    players: players, options: options.dup, units: players,
    scores: { "papierek" => 51, "bot:128:1" => 61, "bot:128:2" => -50 },
    round: 2, dealer_index: 0, bids: { "bot:128:1" => 7 },
    tricks: players.to_h { |player| [player, 0] },
    hands: {
      "papierek" => %w[5H QC JH KS 4H 5D AH QD TH JC 5S 4C 6S TS QS 7D 6C],
      "bot:128:1" => %w[5C 6D 9C QH KH JS 7C KD 2S JD 8C 3C AS 2H 7S 9S 3S],
      "bot:128:2" => %w[8H 6H AD TD KC 3H TC 3D 7H AC 8D 4D 8S 9D 2D 9H 4S]
    },
    current_trick: [], current_player: "bot:128:2", spades_broken: false,
    phase: :bidding, winner: nil
  }
}

states.each do |name, state|
  actor = "bot:128:2"
  replay = ReplayForThreatBid.new(state, [], players)
  context = game.bot_decision_context(replay, actor)
  policy = game.bot_strategy.policies.for_state(state)
  puts "#{name}: estimate=#{game.send(:estimated_bot_bid, state, actor).round(3)} " \
    "reserve=#{game.send(:estimated_contract_safety_reserve, state, actor).round(3)} " \
    "plan=#{context.fetch(:round_plan).fetch(:raw_scores).inspect}"
  game.legal_actions(replay, actor).each do |action|
    bid = action.fetch("bid")
    next if !bid.between?(3, 7)

    features = game.send(:bidding_bot_features, state, actor, action)
    learned = policy.score("bidding", features)
    shared = game.bot_policy_score_adjustment(state, actor, action, context)
    planning = game.bot_planning_score_adjustment(state, actor, action, context)
    puts "  #{bid}: learned=#{learned.round(3)} shared=#{shared.round(3)} " \
      "planning=#{planning.round(3)} total=#{(learned + shared + planning).round(3)}"
  end
end

sample_players = ["sample-a", "sample-b", "sample-c"]
pressures = []
80.times do |index|
  hands = game.send(:deal_hands, sample_players, index % 3, format("%032x", 70_000 + index))
  sample_players.each do |actor|
    state = {
      players: sample_players,
      options: options.dup,
      scores: sample_players.to_h { |player| [player, 0] },
      bids: {}, tricks: sample_players.to_h { |player| [player, 0] },
      hands: hands,
      current_trick: [], current_player: actor, spades_broken: false,
      phase: :bidding
    }
    estimate = game.send(:estimated_bot_bid, state, actor)
    planned = [[estimate.round, 1].max, 17].min
    threat = game.send(:bot_bid_threat_context, state, actor, { raw_scores: { planned => 1.0 } })
    pressures << threat[:pressure]
  end
end
active = pressures.count { |pressure| pressure > 0.0 }
puts "sample: active=#{active}/#{pressures.length} mean_pressure=" \
  "#{(pressures.sum / pressures.length).round(3)}"
