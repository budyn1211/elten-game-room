module GameRoomChangelog
  STORAGE_FILE = "changelog.json".freeze
  LAST_SEEN_BUILD_KEY = "last_seen_build".freeze
  ENTRY_TEMPLATE = "Version %{version}, build %{build}".freeze

  Entry = Struct.new(:version, :build, :changes, keyword_init: true)

  ENTRIES = [
    Entry.new(
      version: "1.1.8",
      build: 221,
      changes: [
        "Quiz Party no longer stops while preparing the next question when clients receive slightly different timestamps for the same LiveSessions entry."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.8",
      build: 222,
      changes: [
        "Game and room updates are received even while a key is held or text is being typed. This should prevent games from occasionally getting stuck. Chat text, cursor position and selection remain unchanged.",
        "Makao draw penalties no longer return to their author when the next player is already waiting one or more turns.",
        "After a second review, 284 well-supported Quiz Party questions were restored without bringing back ambiguous questions.",
        "A What's new list is shown once after an update and remains available from the main menu.",
        "Game Room notifications use their own notice sound. Joining a table also clears invitations and notifications for that table.",
        "After playing Wild or Wild Draw Four in UNO, colours are offered in the order yellow, red, blue, green."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.8",
      build: 223,
      changes: [
        "The What's new list is remembered correctly after closing it and groups all changes under a single version and build heading."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.9",
      build: 224,
      changes: [
        "F2 and F3 adjust Game Room sound volume; Shift+F2 and Shift+F3 select a sound group. Sound settings now use separate volume levels, including a master level, without affecting speech or other ELTEN sounds.",
        "F1 opens an arrow-key shortcuts list: current game actions first, room and screen actions next, and general controls last. Enter or Escape closes the list. Native ELTEN help remains unchanged outside Game Room.",
        "In card games, Z and Shift+Z move to the next or previous playable card. A single unambiguous card may be played automatically. UNO disables this aid when Straights, Interceptions, Super interceptions by value or Buzzer cards are enabled.",
        "Makao can be announced or caught while a local bot is thinking. Bot moves now include missing joker declarations and strategically distinct card packages, and catching an unannounced Makao takes priority. The table-card shortcut before dealing now gives a clear message."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.9",
      build: 225,
      changes: [
        "F2 and F3 adjust Game Room sound volume; Shift+F2 and Shift+F3 select a sound group. Sound settings now use separate volume levels, including a master level, without affecting speech or other ELTEN sounds.",
        "F1 opens an arrow-key shortcuts list: current game actions first, room and screen actions next, and general controls last. Enter or Escape closes the list. Native ELTEN help remains unchanged outside Game Room.",
        "In card games, Z and Shift+Z move to the next or previous playable card. A single unambiguous card may be played automatically. UNO disables this aid when Straights, Interceptions, Super interceptions by value or Buzzer cards are enabled.",
        "Makao can now also be announced during a bot's turn, including while waiting for its move. Catching an unannounced Makao also works during that time. Bot moves now include missing joker declarations and strategically distinct card packages, and catching an unannounced Makao takes priority. The table-card shortcut before dealing now gives a clear message."
      ].freeze
    ).freeze,
    Entry.new(
      version: "1.1.10",
      build: 226,
      changes: [
        "Invitations can now be accepted from notifications after reopening Game Room. Joining a table clears its invitations; a temporary network error does not invalidate an invitation.",
        "Private tables can be selected when creating any game. They are available by invitation and do not appear in public table lists, the widget or lobby announcements.",
        "Ctrl+R reads the variant and active settings of the selected or current table without opening the rules or moving the cursor.",
        "The table creator can save an ongoing game locally with Ctrl+S, closing the table. Saved games replaces rankings in the main menu.",
        "Resuming preserves the game, settings, bots and remaining turn time, and waits for the original players. Quiz Party and Categories cannot be saved; UNO requires finishing the colour choice and Monopoly requires finishing the auction. Private and resumed tables require an up-to-date Game Room for all players.",
        "S counts discs in Reversi, men and kings in Checkers, and pieces in Chess.",
        "Monopoly bots evaluate trades using colour-group prospects and blocking opponents, rather than selling properties too easily for their purchase price.",
        "Monopoly automatically declines an unowned property purchase when the player cannot afford it, without requiring Enter. Auctions still follow the table settings.",
        "Sending and declining invitations is recorded in the room history. Declining no longer creates a separate notification or an empty notification entry."
      ].freeze
    ).freeze
  ].freeze

  module_function

  def available_entries(current_build, entries: ENTRIES)
    entries.select { |entry| entry.build.to_i <= current_build.to_i }
      .sort_by { |entry| -entry.build.to_i }
  end

  def pending_entries(last_seen_build, current_build, entries: ENTRIES)
    available = available_entries(current_build, entries: entries)
    if last_seen_build == nil
      current = available.find { |entry| entry.build.to_i == current_build.to_i }
      return current == nil ? [] : [current]
    end
    return [] if last_seen_build.to_i >= current_build.to_i

    available.select { |entry| entry.build.to_i > last_seen_build.to_i }
  end

  def list_items(entries, translator: nil)
    translate = translator || ->(text) { text }
    entries.flat_map do |entry|
      heading = translate.call(ENTRY_TEMPLATE) % {
        version: entry.version,
        build: entry.build
      }
      [heading] + entry.changes.map { |change| translate.call(change) }
    end
  end
end
