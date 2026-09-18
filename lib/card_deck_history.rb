require_relative "game_content"

# Recycling remains part of the game's existing action and seeded shuffle.
# This helper adds public history only after that action has been accepted.
module GameRoomCardDeckHistory
  protected

  def record_deck_reshuffle(history, previous_count, current_count, event_id)
    return unless current_count.to_i > previous_count.to_i
    key = "reshuffle:#{event_id}"
    return if history.any? { |entry| entry.key == key }

    entry = GameRoomGames::HistoryEntry.new(key: key,
      text: GameRoomContent.utf8(_("The deck was reshuffled.")),
      event_id: event_id, actor: "", kind: :reshuffle)
    # Announce replenishing the deck before the resulting draw/exchange.
    index = history.index { |item| item.event_id == event_id } || history.length
    history.insert(index, entry)
  end
end
