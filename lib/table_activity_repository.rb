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
    :subject,
    :invitation_id,
    :created_at,
    keyword_init: true
  )

  TABLE_NAME = "table_activity".freeze
  KINDS = %w[created joined left bot_added bot_removed chat invited invitation_rejected game_aborted options_changed].freeze
  GLOBAL_KINDS = %w[created joined left bot_added bot_removed].freeze
  BOT_KINDS = %w[bot_added bot_removed].freeze
  TABLE_LIMIT = 2_000
  GLOBAL_LIMIT = 200
  MESSAGE_MAX_LENGTH = 400

  def initialize(server_tables:, transport: nil)
    @server_tables = server_tables
    @transport = transport
  end

  def append(table:, kind:, message: nil, actor: Session.name, subject: nil, invitation_id: nil)
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
    if BOT_KINDS.include?(normalized_kind) && !subject.to_s.empty?
      # This existing field carries the stable bot ID, not a translated
      # sentence. It works in both the native log and the lobby table without
      # another request or a server-column migration.
      clean_message = bot_subject(subject, table_id)
      raise ArgumentError, "Invalid activity computer" if clean_message.empty?
    end
    invitation_activity = %w[invited invitation_rejected].include?(normalized_kind)
    if invitation_activity && (subject.to_s.strip.empty? || subject.to_s.length > 64 || invitation_id.to_i <= 0)
      raise ArgumentError, "Invalid invitation activity"
    end

    if native_live_sessions?
      arguments = {
        table: table,
        kind: normalized_kind,
        actor: author,
        message: clean_message
      }
      arguments.merge!(subject: subject.to_s, invitation_id: invitation_id.to_i) if invitation_activity
      inserted = @transport.append_activity(**arguments)
      persist_global_activity(table, normalized_kind, author, message: clean_message) if GLOBAL_KINDS.include?(normalized_kind) && table["private"] != true
      return entry_from(inserted, table)
    end

    inserted = activity_table.insert(
      "table_id" => table_id,
      "kind" => normalized_kind,
      "actor" => author,
      "table_owner" => owner,
      "game" => game,
      "message" => clean_message,
      "subject" => invitation_activity ? subject.to_s : "",
      "invitation_id" => invitation_activity ? invitation_id.to_i : 0,
      "created_at" => Time.now.to_i
    )
    entry_from(inserted, table)
  end

  def append_safely(**arguments)
    append(**arguments)
  rescue StandardError => error
    Log.warning("ELTEN Game Room could not save table activity: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def entries_for(table, limit: TABLE_LIMIT, viewer: nil)
    table_id = row_id(table)
    return [] if table_id <= 0

    if native_live_sessions?
      entries = @transport.activity_records(table)
        .filter_map { |row| entry_from(row, table) }
        .sort_by { |entry| [entry.created_at, entry.id] }
        .last([[limit.to_i, 1].max, TABLE_LIMIT].min)
      return entries_for_current_visit(entries, table, viewer)
    end

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
  rescue StandardError => error
    Log.warning("ELTEN Game Room could not load table activity: #{error.class}: #{error.message}") if defined?(Log)
    []
  end

  def global_entries(tables: nil, limit: GLOBAL_LIMIT)
    # Named bot records use message for their identity. An empty-message
    # filter would hide them; the kind allowlist below still excludes chat.
    activity_table
      .select(
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
    bot = GameRoomParticipants.display_name(entry.subject) if !entry.subject.to_s.empty?
    if global
      case entry.kind
      when "created"
        _("%{player} created a table for %{game}.") % { player: player, game: game }
      when "joined"
        _("%{player} joined %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "left"
        _("%{player} left %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "bot_added"
        return _("Added %{bot} at %{owner}'s table for %{game}.") % { bot: bot, owner: owner, game: game } if bot != nil
        _("%{player} added a computer at %{owner}'s table for %{game}.") % { player: player, owner: owner, game: game }
      when "bot_removed"
        return _("Removed %{bot} from %{owner}'s table for %{game}.") % { bot: bot, owner: owner, game: game } if bot != nil
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
        return _("Added %{bot}.") % { bot: bot } if bot != nil
        _("%{player} added a computer.") % { player: player }
      when "bot_removed"
        return _("Removed %{bot}.") % { bot: bot } if bot != nil
        _("%{player} removed a computer.") % { player: player }
      when "chat"
        _("%{player}: %{message}") % { player: player, message: entry.message }
      when "invited"
        _("%{player} invited %{user}.") % { player: player, user: GameRoomParticipants.display_name(entry.subject) }
      when "invitation_rejected"
        _("%{user} declined %{player}'s invitation.") % { player: player, user: GameRoomParticipants.display_name(entry.subject) }
      when "game_aborted"
        _("%{player} ended the game. The table remains open.") % { player: player }
      when "options_changed"
        _("%{player} changed the settings for the next game.") % { player: player }
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
      [event_times.fetch(entry.event_id.to_i, 0), entry.event_id.to_i, 0, index, item]
    end
    activity_entries.to_a.each_with_index do |entry, index|
      text = text_for(entry, game_name: game_name, global: false)
      category = entry.kind == "chat" ? :chat : :room
      item = GameRoomHistory::Entry.new(text: text.to_s, category: category)
      records << [entry.created_at.to_i, entry.id.to_i, 1, index, item] if !text.to_s.empty?
    end
    records.sort_by { |record| record[0, 4] }.map(&:last)
  end

  private

  def native_live_sessions?
    @transport.respond_to?(:live_store?) && @transport.live_store?
  end

  def persist_global_activity(table, kind, actor, message: "")
    activity_table.insert(
      "table_id" => row_id(table),
      "kind" => kind.to_s,
      "actor" => actor.to_s,
      "table_owner" => table_owner(table),
      "game" => table["game"].to_s,
      "message" => message,
      "created_at" => Time.now.to_i
    )
  rescue StandardError => error
    Log.warning("ELTEN Game Room could not save lobby activity: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

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
    subject = row["subject"].to_s
    if BOT_KINDS.include?(row["kind"].to_s)
      subject = bot_subject(row["message"], row_id(table))
      return nil if !row["message"].to_s.empty? && subject.empty?
    end
    if %w[invited invitation_rejected].include?(row["kind"].to_s)
      return nil if row["subject"].to_s.empty? || row["subject"].to_s.length > 64 || row["invitation_id"].to_i <= 0
    end

    Entry.new(
      id: row_id(row),
      table_id: row["table_id"].to_i,
      kind: row["kind"].to_s,
      actor: actor,
      owner: table_owner(table),
      game: table["game"].to_s,
      message: message,
      subject: subject,
      invitation_id: row["invitation_id"].to_i,
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

  def bot_subject(value, table_id)
    candidate = value.to_s
    return "" unless candidate.length <= 64 && GameRoomParticipants.bot?(candidate)
    return "" unless candidate.start_with?("bot:#{table_id}:") && GameRoomParticipants.bot_number(candidate).between?(1, 8)

    candidate
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
