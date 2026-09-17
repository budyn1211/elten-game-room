require_relative "rummy_rules"

# Bounded set packing of a *single known hand*. No opponent hands or stock
# order enter this object. Limits bound computation, not the legal game rules.
module GameRoomRummyPlanner
  RULES = GameRoomRummyRules
  MAX_CANDIDATES = 420
  BEAM = 64
  module_function

  def candidates(hand, identities: false)
    hand = hand.uniq
    natural = hand.reject { |c| RULES.joker?(c) }
    jokers = hand.select { |c| RULES.joker?(c) }
    result = {}
    add = lambda do |cards|
      meld = RULES.validate(cards, identities: identities)
      result[cards.join] = meld if meld && result.length < MAX_CANDIDATES
    end
    natural.group_by { |c| RULES.rank(c) }.each_value do |cards|
      by_suit = cards.group_by { |c| c[1] }
      [3, 4].each do |size|
        by_suit.keys.combination(size) do |suits|
          4.times do |copy|
            add.call(suits.map { |suit| by_suit[suit][copy % by_suit[suit].length] })
          end
        end
        by_suit.keys.combination(size - 1) do |suits|
          jokers.each do |joker|
            4.times { |copy| add.call(suits.map { |suit| by_suit[suit][copy % by_suit[suit].length] } + [joker]) }
          end
        end
      end
    end
    if identities
      natural.group_by { |c| RULES.face(c) }.each_value do |cards|
        [3, 4].each do |size|
          cards.combination(size) { |group| add.call(group) }
          jokers.each { |joker| cards.combination(size - 1) { |group| add.call(group + [joker]) } }
        end
      end
    end
    RULES::SUITS.each do |suit|
      cards = natural.select { |c| c[1] == suit }.group_by { |c| RULES.rank(c) }
      1.upto(12) do |first|
        3.upto([13, 15 - first].min) do |size|
          ranks = (first...(first + size)).map { |r| r == 14 ? 1 : r }
          next if ranks.uniq.length != ranks.length
          missing = ranks.each_index.select { |index| !cards.key?(ranks[index]) }
          next if missing.length > 1
          4.times do |copy|
            ordinary = ranks.map { |r| cards[r] && cards[r][copy % cards[r].length] }
            add.call(ordinary) if missing.empty?
            positions = missing.empty? ? ranks.each_index.to_a : missing
            jokers.each do |joker|
              positions.each do |index|
                group = ordinary.dup
                group[index] = joker
                add.call(group)
              end
            end
          end
        end
      end
    end
    result.values
  end

  def plans(hand, identities: false, rounded: true, minimum: 0, debts: [])
    index = hand.each_with_index.to_h
    candidates = candidates(hand, identities: identities).map do |meld|
      mask = meld[:cards].reduce(0) { |m, c| m | (1 << index.fetch(c)) }
      { groups: [meld[:cards]], mask: mask, points: RULES.points(meld, rounded: rounded), cards: meld[:cards] }
    end.sort_by { |p| [-p[:cards].length, -p[:points], p[:cards].join] }
    beam = [{ groups: [], mask: 0, points: 0, cards: [] }]
    candidates.each do |candidate|
      added = beam.filter_map do |entry|
        next unless (entry[:mask] & candidate[:mask]) == 0
        { groups: entry[:groups] + candidate[:groups], mask: entry[:mask] | candidate[:mask],
          points: entry[:points] + candidate[:points], cards: entry[:cards] + candidate[:cards] }
      end
      beam = (beam + added).group_by { |p| p[:mask] }.values.map { |ps| ps.max_by { |p| p[:points] } }
      beam.sort_by! { |p| [-utility(p, debts), -p[:points], p[:mask]] }
      beam = beam.first(BEAM)
    end
    beam.select { |p| !p[:groups].empty? && p[:points] >= minimum }.first(8)
  end

  def repaid(cards, debts)
    remaining = debts.dup
    cards.each do |card|
      index = remaining.index(RULES.face(card))
      remaining.delete_at(index) if index
    end
    debts.length - remaining.length
  end

  def utility(plan, debts)
    repaid(plan[:cards], debts) * 1000 + plan[:cards].length * 100 + plan[:points]
  end

  def card_usefulness(card, hand)
    return 50 if RULES.joker?(card)
    peers = hand.reject { |c| c == card }
    same_rank = peers.count { |c| !RULES.joker?(c) && RULES.rank(c) == RULES.rank(card) }
    neighbours = peers.count { |c| !RULES.joker?(c) && c[1] == card[1] && (RULES.rank(c) - RULES.rank(card)).abs.between?(1, 2) }
    same_rank * 8 + neighbours * 6
  end
end
