require "digest"
require_relative "game_bots"
require_relative "participant_decision_events"

# A small information-set policy, not a perfect-information game search. The
# replay contains every hand, but this policy deliberately copies only its own
# cards, public totals/powers and completed public plays. Sealed choices and
# other hands/piles never enter the evaluator. A spy alone may use the reveals.
module ScientificWarBot
  RANKS = %w[2 3 4 5 6 7 8 9 T J Q K A X].freeze
  SAMPLE_COUNT = 48

  class Strategy
    include GameRoomBots::ReplayOnlyStrategy

    def choose(actions:, actor:, random_source:, game:, replay:, **_extra)
      values = actions.to_a
      return values.first if values.length <= 1

      evaluation = Evaluation.new(game, replay, actor)
      # Suits/physical duplicates have identical effects; do not give a rank
      # extra probability merely because several copies are in this hand.
      candidates = values.group_by { |action| [action["action"], action["card"].to_s[0]] }.values.map(&:first)
      scored = candidates.map { |action| [action, evaluation.score(action)] }
      best_card = scored.reject { |action, _score| action["action"] == "swap" }.map(&:last).max
      scored.reject! { |action, score| action["action"] == "swap" && best_card && score <= best_card + 0.05 }
      best = scored.map(&:last).max
      # With exact spy information (or at the limit), never trade a known
      # better outcome for variety. Otherwise mix only near-equal choices.
      tolerance = evaluation.exact? || evaluation.final_trick? ? 0.000001 : 0.6
      close = scored.select { |_action, score| score >= best - tolerance }
      return close.first.first if close.length == 1

      weights = close.map { |_action, score| tolerance < 0.01 ? 1 : 1 + ((score - best + tolerance) * 20).round }
      roll = random_source.roll(count: 1, sides: weights.sum).values.first.to_i
      close.each_with_index do |(action, _score), index|
        roll -= weights[index]
        return action if roll <= 0
      end
      close.last.first
    end
  end

  class Evaluation
    def initialize(game, replay, actor)
      @game = game
      state = replay.state
      @player = state[:players].find { |player| GameRoomParticipants.same?(player, actor) }
      @players = state[:players].reject { |player| state[:eliminated][player] }
      @opponents = @players - [@player]
      @hand = state[:hands].fetch(@player).dup
      @pile = state[:piles].fetch(@player).dup
      # Counts are available through E even without a three. Do not inspect
      # opponents' array contents, or use their separate hand/pile sizes.
      @totals = @players.to_h { |player| [player, state[:hands][player].length + state[:piles][player].length] }
      @reversed = state[:reversed]
      @trick = state[:trick]
      @limit = state[:options]["trick_limit"].to_i
      @carried = state[:carried].dup
      @powers = state[:powers].dup
      @exact = state[:phase] == :spying && @powers[@player] == "Q"
      @scenarios = if @exact
        [[state[:reveals].reject { |player, _card| player == @player }, 1.0]]
      else
        public_scenarios(replay, state[:players].length)
      end
      @scores = {}
      @future = {}
    end

    def exact?
      @exact
    end

    def final_trick?
      @trick >= @limit
    end

    def score(action)
      return 0.0 if action["action"] == "reveal"
      if action["action"] == "swap"
        return -Float::INFINITY if @pile.empty?

        # Compare the useful choices, not pile sizes. A large weak pile is
        # not an improvement over a small hand with the card we need now.
        return @pile.map { |card| card[0] }.uniq.map { |rank| card_score(rank, @pile, @hand) }.max - 0.25
      end

      card_score(action["card"].to_s[0], @hand, @pile)
    end

    private

    def public_scenarios(replay, player_count)
      pool = RANKS.to_h { |rank| [rank, player_count] }
      (@hand + @pile + @carried).each { |card| pool[card[0]] -= 1 }
      pool.transform_values! { |count| [count, 0].max }
      # Frequencies describe only completed, publicly revealed tricks. In
      # particular neither commit digests nor the current partial reveal is
      # used to predict the other players' choices.
      events = GameRoomParticipantDecisionEvents.for(replay).to_a
      frequencies = @opponents.to_h { |player| [player, Hash.new(0)] }
      events.reverse_each.take(192).each do |event|
        next unless %w[reveal spy_play].include?(event["action"])

        fields = event["value"].to_s.split(":")
        next unless fields.first.to_i < @trick

        player = event["actor"]
        rank = fields.last.to_s[0]
        frequencies[player][rank] += 1 if frequencies.key?(player) && RANKS.include?(rank)
      end
      distributions = @opponents.to_h do |player|
        seen = frequencies[player].values.sum
        [player, RANKS.to_h { |rank| [rank, 1.0 + frequencies[player][rank].to_f / [seen, 1].max] }]
      end
      if @opponents.length == 1
        player = @opponents.first
        weights = RANKS.to_h { |rank| [rank, pool[rank] * distributions[player][rank]] }
        total = weights.values.sum
        return weights.filter_map { |rank, weight| [{ player => rank }, weight / total] if weight > 0 }
      end

      # Shared samples for every candidate, with a local seed based solely on
      # permitted information. Analysis consumes none of the session RNG;
      # choosing between near-equal moves consumes at most one session roll.
      signature = [@player, @trick, @reversed, @totals, pool, distributions]
      random = Random.new(Digest::SHA256.hexdigest(Marshal.dump(signature)).to_i(16))
      Array.new(SAMPLE_COUNT) do
        remaining = pool.dup
        plays = @opponents.to_h do |player|
          weights = RANKS.map { |rank| remaining[rank] * distributions[player][rank] }
          target = random.rand * weights.sum
          index = weights.each_index.find { |i| (target -= weights[i]) < 0 } || RANKS.length - 1
          rank = RANKS[index]
          remaining[rank] -= 1
          [player, rank]
        end
        [plays, 1.0 / SAMPLE_COUNT]
      end
    end

    def card_score(rank, hand, pile)
      key = [rank, hand.equal?(@hand)]
      return @scores[key] if @scores.key?(key)

      value = @scenarios.sum do |others, probability|
        plays = others.merge(@player => rank)
        winner, = @game.send(:trick_outcome, { reversed: @reversed }, plays)
        totals = @totals.transform_values { |count| count - 1 }
        totals[winner] += @carried.length + @players.length if winner
        surviving = totals.select { |_player, count| count > 0 }
        mine = totals[@player]
        theirs = @opponents.map { |player| totals[player] }.max || 0
        terminal = final_trick? || surviving.length <= 1 || mine <= 0
        utility = if terminal
          mine <= 0 && surviving.any? ? -1_000.0 : (mine <=> theirs) * 1_000.0
        else
          # Denying the leading rival a pot is better than a certain loss;
          # winning it is better still. This also values carrying a large pot.
          (mine - theirs) * 2.0 + future_value(rank, plays, hand, pile)
        end
        probability * utility
      end
      @scores[key] = value
    end

    def future_value(rank, plays, hand, pile)
      reversed = plays.values.count { |card| card[0] == "J" }.odd? ? !@reversed : @reversed
      # The same candidate is evaluated against every public sample. Compute
      # its remaining hand only once per orientation, even with 100+ cards.
      key = [rank, hand.equal?(@hand), reversed]
      base, has_cards = @future[key] ||= begin
        remaining = hand.map { |card| card[0] }
        remaining.delete_at(remaining.index(rank))
        remaining = pile.map { |card| card[0] } if remaining.empty?
        reserve = rank == "X" ? 0.8 : strength(rank, @reversed) * 0.45
        reserve += 0.15 if rank == "Q"
        future_hand = remaining.empty? ? 0.0 : remaining.sum { |card| strength(card, reversed) } / remaining.length * 0.4
        [future_hand - reserve, remaining.any?]
      end
      queens = plays.select { |_player, card| card[0] == "Q" }.keys
      power = if queens.length == 1 && has_cards
        queens.first == @player ? 1.2 : -0.4
      else
        0.0
      end
      power + base
    end

    def strength(rank, reversed)
      return 0.7 if rank == "X"

      index = RANKS.index(rank) || 0
      (reversed ? 12 - index : index) / 12.0
    end
  end
end
