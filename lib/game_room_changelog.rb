module GameRoomChangelog
  STORAGE_FILE = "changelog.json".freeze
  LAST_SEEN_BUILD_KEY = "last_seen_build".freeze
  ITEM_TEMPLATE = "Version %{version}, build %{build}: %{change}".freeze

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
      entry.changes.map do |change|
        translate.call(ITEM_TEMPLATE) % {
          version: entry.version,
          build: entry.build,
          change: translate.call(change)
        }
      end
    end
  end
end
