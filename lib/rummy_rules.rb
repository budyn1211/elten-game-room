# Pure rules shared by replay, the local meld editor and the normal bot.
# Physical cards use rank, suit and deck-copy; jokers use X, index and copy.
module GameRoomRummyRules
  RANKS = %w[A 2 3 4 5 6 7 8 9 T J Q K].freeze
  SUITS = %w[C D H S].freeze
  module_function

  def joker?(card)
    card.to_s.start_with?("X")
  end

  def face(card)
    joker?(card) ? "X" : card.to_s[0, 2]
  end

  def rank(card)
    (RANKS.index(card.to_s[0]) || -1) + 1
  end

  def deck(copies)
    copies.times.flat_map do |copy|
      SUITS.flat_map { |suit| RANKS.map { |value| "#{value}#{suit}#{copy}" } } + ["X0#{copy}", "X1#{copy}"]
    end
  end

  def validate(cards, identities: false)
    return nil unless cards.is_a?(Array) && cards.length.between?(3, 13)
    return nil unless cards.uniq.length == cards.length
    return nil unless cards.all? { |card| /\A(?:[A2-9TJQK][CDHS]|X[01])[0-3]\z/.match?(card.to_s) }
    natural = cards.reject { |card| joker?(card) }
    return nil if cards.length - natural.length > 1
    if cards.length <= 4 && natural.map { |card| rank(card) }.uniq.length == 1
      suits = natural.map { |card| card[1] }
      type = if suits.uniq.length == suits.length
        :set
      elsif identities && suits.uniq.length == 1
        :identity
      end
      if type
        value = rank(natural.first)
        replacement_suit = type == :identity ? suits.first : (SUITS - suits).one? ? (SUITS - suits).first : nil
        return { type: type, cards: cards.dup,
          ranks: cards.map { value == 1 ? 14 : value },
          joker_face: cards.any? { |card| joker?(card) } && replacement_suit ? "#{RANKS[value - 1]}#{replacement_suit}" : nil }
      end
    end
    return nil unless natural.map { |card| card[1] }.uniq.length == 1
    suit = natural.first[1]
    [false, true].each do |high_ace|
      offsets = cards.each_with_index.filter_map do |card, index|
        next if joker?(card)
        value = rank(card)
        value = 14 if value == 1 && high_ace
        value - index
      end
      next unless offsets.uniq.length == 1
      first = offsets.first
      next unless first >= 1 && first + cards.length - 1 <= (high_ace ? 14 : 13)
      ranks = cards.each_index.map { |index| first + index }
      joker_index = cards.index { |card| joker?(card) }
      value = joker_index && ranks[joker_index]
      return { type: :run, cards: cards.dup, ranks: ranks,
        joker_face: value ? "#{RANKS[(value - 1) % 13]}#{suit}" : nil }
    end
    nil
  end

  def value(rank, rounded: true)
    return rounded ? 15 : 11 if rank == 14
    return rounded ? 5 : 1 if rank == 1
    return 10 if rank >= 10
    rounded ? 5 : rank
  end

  def hand_value(card, rounded: true)
    return 20 if joker?(card)
    value(rank(card) == 1 ? 14 : rank(card), rounded: rounded)
  end

  def values(meld, rounded: true)
    meld[:ranks].map { |rank| value(rank, rounded: rounded) + (meld[:type] == :identity ? 10 : 0) }
  end

  def points(meld, rounded: true)
    values(meld, rounded: rounded).sum
  end

  def preserves_joker?(old, replacement)
    return false unless replacement
    joker = old[:cards].find { |card| joker?(card) }
    return true if !joker || !replacement[:cards].include?(joker)
    # An ambiguous set may become unambiguous, but a fixed joker never changes.
    old[:joker_face] == nil || old[:joker_face] == replacement[:joker_face]
  end

  def additions(meld, card, identities: false)
    return [] if joker?(card)
    result = []
    orders = meld[:type] == :run ? [[card] + meld[:cards], meld[:cards] + [card]] : [meld[:cards] + [card]]
    orders.each do |cards|
      candidate = validate(cards, identities: identities)
      next unless candidate && candidate[:type] == meld[:type] && preserves_joker?(meld, candidate)
      result << { mode: :extend, meld: candidate }
    end
    if meld[:joker_face] == face(card)
      old = meld[:cards].find { |item| joker?(item) }
      candidate = validate(meld[:cards].map { |item| item == old ? card : item }, identities: identities)
      result << { mode: :recover, meld: candidate, joker: old } if candidate && candidate[:type] == meld[:type]
    end
    result.uniq
  end

  def removable(meld, identities: false)
    return [] if meld[:cards].length <= 3
    indices = meld[:type] == :run ? [0, meld[:cards].length - 1] : meld[:cards].each_index.to_a
    indices.filter_map do |index|
      card = meld[:cards][index]
      next if joker?(card)
      cards = meld[:cards].dup
      cards.delete_at(index)
      candidate = validate(cards, identities: identities)
      next unless candidate && preserves_joker?(meld, candidate)
      { card: card, meld: candidate, index: index }
    end
  end
end
