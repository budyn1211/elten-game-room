module GameRoomScoring
  ScoreEntry = Struct.new(
    :player,
    :points,
    :reason,
    :round_id,
    :event_id,
    keyword_init: true
  )

  class ScoreLedger
    attr_reader :entries

    def initialize(entries = [])
      @entries = []
      entries.to_a.each { |entry| add_entry(entry) }
    end

    def add(player:, points:, reason: "", round_id: nil, event_id: nil)
      add_entry(
        ScoreEntry.new(
          player: player.to_s,
          points: points.to_i,
          reason: reason.to_s,
          round_id: round_id,
          event_id: event_id
        )
      )
    end

    def total_for(player)
      canonical = player.to_s.downcase
      @entries.sum { |entry| entry.player.to_s.downcase == canonical ? entry.points.to_i : 0 }
    end

    def totals
      names = []
      @entries.each do |entry|
        names << entry.player if !names.any? { |name| name.to_s.casecmp(entry.player.to_s) == 0 }
      end
      names.each_with_object({}) { |name, result| result[name] = total_for(name) }
    end

    def leaders
      values = totals
      return [] if values.empty?

      maximum = values.values.max
      values.select { |_player, points| points == maximum }.keys
    end

    private

    def add_entry(entry)
      raise ArgumentError, "a score entry requires a player" if entry.player.to_s.empty?

      @entries << ScoreEntry.new(
        player: entry.player.to_s,
        points: entry.points.to_i,
        reason: entry.reason.to_s,
        round_id: entry.round_id,
        event_id: entry.event_id
      )
      @entries.last
    end
  end

  ReviewDecision = Struct.new(
    :item_id,
    :reviewer,
    :decision,
    :event_id,
    keyword_init: true
  )
  ReviewSummary = Struct.new(:item_id, :counts, :decisions, keyword_init: true)

  class ReviewLedger
    attr_reader :allowed_decisions

    def initialize(allowed_decisions: [:accept, :reject, :challenge, :abstain])
      @allowed_decisions = allowed_decisions.to_a.map(&:to_s).uniq
      raise ArgumentError, "manual review requires decisions" if @allowed_decisions.empty?

      @decisions = {}
    end

    def record(item_id:, reviewer:, decision:, event_id: nil)
      item = item_id.to_s
      user = reviewer.to_s
      value = decision.to_s
      raise ArgumentError, "a review decision requires an item" if item.empty?
      raise ArgumentError, "a review decision requires a reviewer" if user.empty?
      raise ArgumentError, "unsupported review decision" if !@allowed_decisions.include?(value)

      @decisions[[item, user.downcase]] = ReviewDecision.new(
        item_id: item,
        reviewer: user,
        decision: value,
        event_id: event_id
      )
    end

    def summary(item_id)
      item = item_id.to_s
      decisions = @decisions.values.select { |entry| entry.item_id == item }
      counts = @allowed_decisions.each_with_object({}) do |decision, result|
        result[decision] = decisions.count { |entry| entry.decision == decision }
      end
      ReviewSummary.new(item_id: item, counts: counts, decisions: decisions)
    end
  end
end
