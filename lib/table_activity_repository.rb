require_relative "game_participants"
require_relative "game_history_navigation"

class TableActivityRepository
  Entry = Struct.new(
    :id,
    :table_id,
    :kind,
    :actor,
    :owner,
    :game,
    :message,
    :created_at,
    keyword_init: true
  )

  TABLE_NAME = "table_activity".freeze
  KINDS = %w[created joined left bot_added bot_removed chat].freeze
  GLOBAL_KINDS = (KINDS - ["chat"]).freeze
  TABLE_LIMIT = 2_000
  GLOBAL_LIMIT = 200
  MESSAGE_MAX_LENGTH = 400

  def initialize(server_tables:)
    @server_tables = server_tables
  end

  def append(table:, kind:, message: nil, actor: Session.name)
    normalized_kind = kind.to_s
    raise ArgumentError, "Invalid table activity kind" if !KINDS.include?(normalized_kind)

    table_id = row_id(table)
    owner = table_owner(table)
    game = table["game"].to_s
    author = actor.to_s.strip
    raise ArgumentError, "Invalid activity table" if table_id <= 0
    raise ArgumentError, "Activity author is required" if author.empty?
    raise ArgumentError, "Activity table owner is required" if owner.empty?
    raise ArgumentError, "Activity game is required" if game.empty?

    clean_message = normalized_kind == "chat" ? normalize_message(message) : ""
    raise ArgumentError, "A chat message cannot be empty" if normalized_kind == "chat" && clean_message.empty?

    inserted = activity_table.insert(
      "table_id" => table_id,
      "kind" => normalized_kind,
      "actor" => author,
      "table_owner" => owner,
      "game" => game,
      "message" => clean_message,
      "created_at" => Time.now.to_i
    )
    entry_from(inserted, table)
  end

  def append_safely(**arguments)
    append(**arguments)
  rescue EltenLink::Error, ArgumentError => error
    Log.warning("ELTEN Game Room could not save table activity: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def entries_for(table, limit: TABLE_LIMIT, viewer: nil)
    table_id = row_id(table)
    return [] if table_id <= 0

    entries = activity_table
      .select(
        where: { "table_id" => table_id },
        order: [["created_at", "asc"]],
        limit: [[limit.to_i, 1].max, TABLE_LIMIT].min
      )
      .to_a
      .filter_map { |row| entry_from(row, table) }
      .sort_by { |entry| [entry.created_at, entry.id] }
    entries_for_current_visit(entries, table, viewer)
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room could not load table activity: #{error.class}: #{error.message}") if defined?(Log)
    []
  end

  def global_entries(tables: nil, limit: GLOBAL_LIMIT)
    activity_table
      .select(
        where: { "message" => "" },
        order: [["created_at", "desc"]],
        limit: GLOBAL_LIMIT
      )
      .to_a
      .filter_map do |row|
        next if !GLOBAL_KINDS.include?(row["kind"].to_s)

        table = {
          "__id" => row["table_id"].to_i,
          "owner" => row["table_owner"].to_s,
          "game" => row["game"].to_s
        }
        entry_from(row, table)
      end
      .sort_by { |entry| [entry.created_at, entry.id] }
      .last([[limit.to_i, 1].max, GLOBAL_LIMIT].min)
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room could not load lobby activity: #{error.class}: #{error.message}") if defined?(Log)
    []
  end

  def latest_global_id
    rows = activity_table.select(
      where: { "message" => "" },
      order: [["created_at", "desc"]],
      limit: 20
    ).to_a.select { |row| GLOBAL_KINDS.include?(row["kind"].to_s) }
    return 0 if rows.empty?

    rows.map { |row| row_id(row) }.max.to_i
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room could not check lobby activity: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def text_for(entry, game_name:, global: false)
    player = GameRoomParticipants.display_name(entry.actor)
    owner = GameRoomParticipants.display_name(entry.owner)
    game = game_name.call(entry.game).to_s
    if global
      case entry.kind
      when "created"
        _("%{player} created a table for %{game}.") % { player: player, game: game }
      when "joined"
        _("%{player} joined %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "left"
        _("%{player} left %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "bot_added"
        _("%{player} added a computer at %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "bot_removed"
        _("%{player} removed a computer from %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      end
    else
      case entry.kind
      when "created"
        _("%{player} created the table.") % { player: player }
      when "joined"
        _("%{player} joined the room.") % { player: player }
      when "left"
        _("%{player} left the room.") % { player: player }
      when "bot_added"
        _("%{player} added a computer.") % { player: player }
      when "bot_removed"
        _("%{player} removed a computer.") % { player: player }
      when "chat"
        _("%{player}: %{message}") % { player: player, message: entry.message }
      end
    end
  end

  def merge_history(game_entries:, game_events:, activity_entries:, game_name:)
    merged_history_entries(
      game_entries: game_entries,
      game_events: game_events,
      activity_entries: activity_entries,
      game_name: game_name
    ).map(&:text)
  end

  def merged_history_entries(game_entries:, game_events:, activity_entries:, game_name:)
    event_times = game_events.to_a.each_with_object({}) do |event, result|
      result[row_id(event)] = event["created_at"].to_i
    end
    records = game_entries.to_a.each_with_index.map do |entry, index|
      item = GameRoomHistory::Entry.new(text: entry.text.to_s, category: :game)
      [event_times.fetch(entry.event_id.to_i, 0), 0, entry.event_id.to_i, index, item]
    end
    activity_entries.to_a.each_with_index do |entry, index|
      text = text_for(entry, game_name: game_name, global: false)
      category = entry.kind == "chat" ? :chat : :room
      item = GameRoomHistory::Entry.new(text: text.to_s, category: category)
      records << [entry.created_at.to_i, 1, entry.id.to_i, index, item] if !text.to_s.empty?
    end
    records.sort_by { |record| record[0, 4] }.map(&:last)
  end

  private

  def entries_for_current_visit(entries, table, viewer)
    username = viewer.to_s.strip
    return entries if username.empty?

    owner = table_owner(table)
    anchor_kind = GameRoomParticipants.same?(owner, username) ? "created" : "joined"
    anchor = entries.reverse.find do |entry|
      entry.kind == anchor_kind && GameRoomParticipants.same?(entry.actor, username)
    end
    return entries if anchor == nil

    entries.select { |entry| entry.id.to_i >= anchor.id.to_i }
  end

  def activity_table
    @activity_table ||= @server_tables.fetch(TABLE_NAME)
  end

  def entry_from(row, table)
    return nil if row_id(row) <= 0 || row["table_id"].to_i != row_id(table)
    return nil if !KINDS.include?(row["kind"].to_s)
    return nil if row["table_owner"].to_s.casecmp(table_owner(table)) != 0
    return nil if row["game"].to_s != table["game"].to_s

    insertion_user = row["__insertion_user"].to_s
    claimed_actor = row["actor"].to_s
    return nil if !insertion_user.empty? && insertion_user.casecmp(claimed_actor) != 0

    actor = insertion_user.empty? ? claimed_actor : insertion_user
    return nil if actor.empty?

    message = row["kind"].to_s == "chat" ? normalize_message(row["message"]) : ""
    return nil if row["kind"].to_s == "chat" && message.empty?

    Entry.new(
      id: row_id(row),
      table_id: row["table_id"].to_i,
      kind: row["kind"].to_s,
      actor: actor,
      owner: table_owner(table),
      game: table["game"].to_s,
      message: message,
      created_at: row["created_at"].to_i
    )
  end

  def normalize_message(value)
    value.to_s
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      .gsub(/[\r\n\t]+/, " ")
      .gsub(/[[:cntrl:]]/, "")
      .strip
      .gsub(/\s+/, " ")
      .slice(0, MESSAGE_MAX_LENGTH)
      .to_s
  end

  def table_owner(row)
    insertion_user = row["__insertion_user"].to_s
    insertion_user.empty? ? row["owner"].to_s : insertion_user
  end

  def row_id(row)
    return 0 if row == nil

    (row["__id"] || row["id"]).to_i
  end
end
