require_relative "game_room_transport"
require_relative "game_participants"
require_relative "game_room_server_tables"

class LobbyRepository
  CreateResult = Struct.new(:table, :created, keyword_init: true) do
    def created?
      created == true
    end
  end

  JoinResult = Struct.new(:table, :status, :members, keyword_init: true) do
    def entered?
      status == :joined || status == :already_here
    end
  end

  TableSnapshot = Struct.new(:table, :members, :bots, :observers, keyword_init: true) do
    def participants
      GameRoomParticipants.unique(members.to_a + bots.to_a)
    end

    def observer?(user)
      GameRoomParticipants.includes?(observers.to_a, user)
    end

    def game_participants
      humans = members.to_a.reject { |member| observer?(member) }
      GameRoomParticipants.unique(humans + bots.to_a)
    end

    def participant_count
      [participants.length, table.to_h["player_count"].to_i].max
    end
  end

  BotUpdateResult = Struct.new(:status, :snapshot, :activity, keyword_init: true) do
    def updated?
      status == :updated
    end
  end

  TABLE_NAME_MIN_LENGTH = 3
  TABLE_NAME_MAX_LENGTH = 60
  TABLE_LIMIT = 100
  MEMBER_LIMIT = 500
  DEFAULT_ROOM_CAPACITY = 8
  MAX_ROOM_CAPACITY = 8
  AVAILABLE_STATUSES = %w[waiting playing].freeze

  def initialize(program, transport: nil, server_tables: nil, activity_repository: nil)
    @program = program
    @server_tables = server_tables || GameRoomServerTables.new(program)
    @transport = transport || GameRoomTransport.new(program)
    @activity_repository = activity_repository
  end

  def valid_table_name?(name)
    length = normalized_name(name).length
    length >= TABLE_NAME_MIN_LENGTH && length <= TABLE_NAME_MAX_LENGTH
  end

  def open_tables(game: nil)
    return @transport.discover_rooms(game: game) if native_live_sessions?

    rows = tables_table.select(order: [["updated_at", "desc"]], limit: TABLE_LIMIT)
    rows = rows.to_a.select { |row| available?(row) }
    rows = rows.select { |row| row["game"].to_s == game.to_s } if game != nil
    rows.sort_by { |row| [status_rank(row), -row["updated_at"].to_i, -table_id(row)] }
  end

  def open_table_snapshots(game: nil)
    if native_live_sessions?
      return open_tables(game: game).map do |row|
        snapshot = @transport.room_snapshot(row)
        snapshot == nil ? TableSnapshot.new(table: row, members: [owner_of(row)], bots: bots_for(row)) : native_snapshot(snapshot)
      end
    end

    tables = open_tables(game: game)
    members = active_member_rows
    tables.map do |row|
      TableSnapshot.new(
        table: row,
        members: member_names(row, members),
        bots: bots_for(row)
      )
    end
  end

  def snapshot_for(row, force: false)
    if native_live_sessions?
      snapshot = force ? @transport.room_snapshot(row, force: true) : @transport.room_snapshot(row)
      return snapshot == nil ? nil : native_snapshot(snapshot)
    end

    tables = open_tables
    current = open_table(table_id(row), tables)
    return nil if current == nil

    members = active_member_rows
    names = reconcile_members(current, members)
    if owner_of(current).casecmp(Session.name.to_s) == 0 && table_touch_required?(current, names.length)
      current = touch_table(current, names.length)
    end
    TableSnapshot.new(table: current, members: names, bots: bots_for(current))
  end

  def create_table(name:, game:, owner:, game_options: "{}", private_table: false, resume_save_id: nil, bot_count: 0, bot_names: nil)
    clean_name = normalized_name(name)
    raise ArgumentError, "Invalid table name" if !valid_table_name?(clean_name)

    if native_live_sessions?
      existing = current_table_for(owner)
      return CreateResult.new(table: existing, created: false) if existing != nil

      table = @transport.create_room(
        name: clean_name,
        game: game,
        owner: owner,
        game_options: game_options,
        capacity: DEFAULT_ROOM_CAPACITY,
        private_table: private_table, resume_save_id: resume_save_id, bot_count: bot_count, bot_names: bot_names
      )
      append_activity(table, "created", actor: owner, table_users: [owner])
      return CreateResult.new(table: table, created: true)
    end

    raise ArgumentError, "Private tables require native LiveSessions" if private_table

    tables = open_tables
    members = active_member_rows
    existing = current_table_for(owner, tables: tables, members: members)
    return CreateResult.new(table: existing, created: false) if existing != nil

    timestamp = Time.now.to_i
    inserted = tables_table.insert(
      "name" => clean_name,
      "game" => game.to_s,
      "owner" => owner.to_s,
      "status" => "waiting",
      "max_players" => DEFAULT_ROOM_CAPACITY,
      "bot_count" => 0,
      "game_options" => game_options.to_s,
      "player_count" => 1,
      "created_at" => timestamp,
      "updated_at" => timestamp
    )

    tables.unshift(inserted)
    primary = reconcile_owned_tables(owner, tables, members) || inserted
    ensure_owner_membership(primary, owner, members)
    current_members = reconcile_members(primary, members)
    primary = touch_table(primary, current_members.length)
    created = table_id(primary) == table_id(inserted)
    append_activity(primary, "created", actor: owner, table_users: current_members) if created
    notify_table_changed(primary, current_members, actor: owner)
    CreateResult.new(table: primary, created: created)
  end

  def join_table(row, user, announce: true)
    if native_live_sessions?
      current = current_table_for(user)
      if current != nil && table_id(current) != table_id(row)
        snapshot = snapshot_for(current)
        return JoinResult.new(table: current, status: :already_at_another_table, members: snapshot&.members.to_a)
      end

      newly_joined = @transport.respond_to?(:consume_new_join) && @transport.consume_new_join(table_id(row), user)
      status = if newly_joined
        :joined
      elsif current != nil && table_id(current) == table_id(row)
        :already_here
      else
        @transport.join_room(row, user)
      end
      snapshot = snapshot_for(row)
      return JoinResult.new(table: row, status: :closed, members: []) if snapshot == nil

      append_activity(snapshot.table, "joined", actor: user, table_users: snapshot.members) if status == :joined
      return JoinResult.new(table: snapshot.table, status: status, members: snapshot.members)
    end

    tables = open_tables
    members = active_member_rows
    target = open_table(table_id(row), tables)
    return JoinResult.new(table: row, status: :closed, members: []) if target == nil

    current = current_table_for(user, tables: tables, members: members)
    if current != nil && table_id(current) != table_id(target)
      return JoinResult.new(table: current, status: :already_at_another_table, members: reconcile_members(current, members))
    end

    current_members = reconcile_members(target, members)
    if includes_user?(current_members, user)
      return JoinResult.new(table: target, status: :already_here, members: current_members)
    end
    if current_members.length + bot_count(target) >= capacity_of(target)
      return JoinResult.new(table: target, status: :full, members: current_members)
    end

    timestamp = Time.now.to_i
    inserted = members_table.insert(
      "table_id" => table_id(target),
      "username" => user.to_s,
      "role" => "member",
      "status" => "active",
      "joined_at" => timestamp,
      "updated_at" => timestamp
    )
    members << inserted

    current_members = reconcile_members(target, members)
    status = includes_user?(current_members, user) ? :joined : :full
    append_activity(target, "joined", actor: user, table_users: current_members) if status == :joined
    notify_table_changed(target, current_members, actor: user) if announce
    JoinResult.new(table: target, status: status, members: current_members)
  end

  def announce_table_joined(row, users, actor: Session.name)
    @transport.table_joined(
      table_id: table_id(row),
      users: users,
      actor: actor
    )
  end

  def announce_table_activity(row, users, actor: Session.name)
    notify_table_changed(row, users, actor: actor)
  end

  def leave_table(row, user)
    if native_live_sessions?
      snapshot = snapshot_for(row)
      return :closed if snapshot == nil

      if owner_of(snapshot.table).casecmp(user.to_s) == 0
        @transport.deactivate_table(table_id: table_id(snapshot.table))
        return :closed
      end
      append_activity(snapshot.table, "left", actor: user, table_users: snapshot.members)
      @transport.deactivate_table(table_id: table_id(snapshot.table))
      return :left
    end

    tables = open_tables
    members = active_member_rows
    target = open_table(table_id(row), tables)
    return :closed if target == nil

    if owner_of(target).casecmp(user.to_s) == 0
      former_members = member_names(target, members)
      close_row(target)
      deactivate_members_for_table(target, members, user: user)
      notify_table_changed(target, former_members, actor: user)
      return :closed
    end

    membership_rows_for(target, user, source: members).each do |member|
      deactivate_member(member)
    end
    current_members = reconcile_members(target, members)
    append_activity(target, "left", actor: user, table_users: current_members + [user.to_s])
    notify_table_changed(target, current_members + [user.to_s], actor: user)
    :left
  end

  def current_table_for(user, tables: nil, members: nil)
    return @transport.current_room(user) if native_live_sessions?

    tables ||= open_tables
    members ||= active_member_rows
    owned = reconcile_owned_tables(user, tables, members)
    if owned != nil
      ensure_owner_membership(owned, user, members)
      reconcile_members(owned, members)
      return owned
    end

    rows = members.select do |row|
      row["status"].to_s == "active" && member_name(row).casecmp(user.to_s) == 0
    end
    valid = rows.map do |row|
      [row, open_table(row["table_id"].to_i, tables)]
    end
    valid.each { |row, table| deactivate_member(row) if table == nil }
    valid = valid.select { |_row, table| table != nil }
    return nil if valid.empty?

    valid.sort_by! { |row, _table| [row["joined_at"].to_i, member_row_id(row)] }
    _primary_row, primary_table = valid.last
    valid[0...-1].each { |row, _table| deactivate_member(row) }
    reconcile_members(primary_table, members)
    primary_table
  end

  def single_open_table_for(owner)
    if native_live_sessions?
      return open_tables.find { |row| owner_of(row).casecmp(owner.to_s) == 0 }
    end

    tables = open_tables
    members = active_member_rows
    reconcile_owned_tables(owner, tables, members)
  end

  def close_table(row)
    if native_live_sessions?
      current = snapshot_for(row)&.table
      return false if current == nil
      raise ArgumentError, "Only the table owner may close it" if owner_of(current).casecmp(Session.name.to_s) != 0

      return @transport.deactivate_table(table_id: table_id(current))
    end

    tables = open_tables
    members = active_member_rows
    current = open_table(table_id(row), tables)
    return false if current == nil
    if owner_of(current).casecmp(Session.name.to_s) != 0
      raise ArgumentError, "Only the table owner may close it"
    end

    former_members = member_names(current, members)
    close_row(current)
    deactivate_members_for_table(current, members, user: Session.name)
    notify_table_changed(current, former_members, actor: Session.name)
    true
  end

  def owner_of(row)
    row["__insertion_user"].to_s.empty? ? row["owner"].to_s : row["__insertion_user"].to_s
  end

  def table_id(row)
    return 0 if row == nil

    (row["__id"] || row["id"]).to_i
  end

  def capacity_of(row)
    requested = [row["max_players"].to_i, DEFAULT_ROOM_CAPACITY].max
    [requested, MAX_ROOM_CAPACITY].min
  end

  def bot_count(row)
    count = [row["bot_count"].to_i, 0].max
    [count, capacity_of(row)].min
  end

  def bots_for(row)
    GameRoomParticipants.bots_for(table_id(row), bot_count(row), names: row["bot_names"])
  end

  def add_bot(row, snapshot: nil)
    update_bot_count(row, 1, snapshot: snapshot)
  end

  def remove_bot(row, snapshot: nil, participant: nil)
    update_bot_count(row, -1, snapshot: snapshot, participant: participant)
  end

  def set_observer(row, user, observing)
    raise "Observer mode requires native LiveSessions" if !native_live_sessions?

    snapshot = snapshot_for(row, force: true)
    return nil if snapshot == nil
    raise ArgumentError, "Only your own table role may be changed" if !GameRoomParticipants.same?(user, Session.name)
    raise ArgumentError, "A computer cannot observe a game" if GameRoomParticipants.bot?(user)
    raise ArgumentError, "The user is not at this table" if !GameRoomParticipants.includes?(snapshot.members, user)

    @transport.set_observer(snapshot.table, observing, actor: user)
    snapshot_for(snapshot.table, force: true)
  end

  def available?(row)
    AVAILABLE_STATUSES.include?(row["status"].to_s)
  end

  def waiting?(row)
    row["status"].to_s == "waiting"
  end

  def playing?(row)
    row["status"].to_s == "playing"
  end

  def set_game_active(row, active, snapshot: nil)
    id = table_id(row)
    raise ArgumentError, "Invalid table row" if id <= 0

    if native_live_sessions?
      current_snapshot = snapshot.is_a?(TableSnapshot) ? snapshot : snapshot_for(row)
      return nil if current_snapshot == nil
      current = current_snapshot.table
      raise ArgumentError, "Only the table owner may update it" if owner_of(current).casecmp(Session.name.to_s) != 0

      status = active ? "playing" : "waiting"
      return current if current["status"].to_s == status

      updated = @transport.update_room(current, { "status" => status }, actor: Session.name)
      row.replace(updated) if row.is_a?(Hash)
      current_snapshot.table.replace(updated)
      return updated
    end

    cached = snapshot.is_a?(TableSnapshot) && table_id(snapshot.table) == id
    current = cached ? snapshot.table.dup : open_table(id)
    return nil if current == nil
    raise ArgumentError, "Only the table owner may update it" if owner_of(current).casecmp(Session.name.to_s) != 0

    status = active ? "playing" : "waiting"
    return current if current["status"].to_s == status

    updated = tables_table.update(id, "status" => status, "updated_at" => Time.now.to_i)
    current.replace(updated) if updated.is_a?(Hash)
    current["status"] = status
    row.replace(current) if row.is_a?(Hash)
    snapshot.table.replace(current) if cached
    names = cached ? GameRoomParticipants.unique(snapshot.members) : reconcile_members(current, active_member_rows)
    notify_table_changed(current, names, actor: Session.name)
    current
  end

  private

  def native_live_sessions?
    @transport.respond_to?(:live_store?) && @transport.live_store?
  end

  def native_snapshot(value)
    TableSnapshot.new(
      table: value.fetch(:table),
      members: value.fetch(:members).to_a,
      bots: value.fetch(:bots).to_a,
      observers: value.fetch(:observers, []).to_a
    )
  end

  def tables_table
    @tables_table ||= @server_tables.fetch("tables")
  end

  def members_table
    @members_table ||= @server_tables.fetch("table_members")
  end

  def open_table(id, tables = nil)
    return nil if id.to_i <= 0

    (tables || open_tables).find { |row| table_id(row) == id.to_i }
  end

  def active_member_rows
    members_table
      .select(order: [["updated_at", "desc"]], limit: MEMBER_LIMIT)
      .to_a
      .select { |row| row["status"].to_s == "active" }
  end

  def membership_rows_for(row, user = nil, source: nil)
    id = table_id(row)
    (source || active_member_rows).select do |member|
      member["status"].to_s == "active" &&
        member["table_id"].to_i == id &&
        (user == nil || member_name(member).casecmp(user.to_s) == 0)
    end
  end

  def member_names(row, members)
    names = [owner_of(row)]
    membership_rows_for(row, source: members)
      .sort_by { |member| [member["joined_at"].to_i, member_row_id(member)] }
      .each { |member| append_unique_user(names, member_name(member)) }
    names.reject { |name| name.to_s.empty? }
  end

  def reconcile_members(row, members)
    table_members = membership_rows_for(row, source: members)
    grouped = table_members.group_by { |member| member_name(member).downcase }
    grouped.each_value do |rows|
      rows.sort_by! { |member| [member["joined_at"].to_i, member_row_id(member)] }
      rows.drop(1).each { |member| deactivate_member(member) if own_member?(member) }
    end

    names = member_names(row, members)
    maximum = [capacity_of(row) - bot_count(row), 1].max
    names.drop(maximum).each do |name|
      membership_rows_for(row, name, source: members).each do |member|
        deactivate_member(member) if own_member?(member)
      end
    end
    names.take(maximum)
  end

  def reconcile_owned_tables(owner, tables, members)
    rows = tables
      .select { |row| owner_of(row).casecmp(owner.to_s) == 0 }
      .sort_by { |row| [row["created_at"].to_i, table_id(row)] }
      .reverse
    primary = rows.first
    rows.drop(1).each do |row|
      former_members = member_names(row, members)
      close_row(row)
      deactivate_members_for_table(row, members, user: owner)
      notify_table_changed(row, former_members, actor: owner)
    end
    primary
  end

  def ensure_owner_membership(row, owner, members)
    return if owner_of(row).casecmp(Session.name.to_s) != 0
    return if !membership_rows_for(row, owner, source: members).empty?

    timestamp = Time.now.to_i
    inserted = members_table.insert(
      "table_id" => table_id(row),
      "username" => owner.to_s,
      "role" => "owner",
      "status" => "active",
      "joined_at" => timestamp,
      "updated_at" => timestamp
    )
    members << inserted
  end

  def deactivate_members_for_table(row, members, user:)
    membership_rows_for(row, user, source: members).each { |member| deactivate_member(member) }
  end

  def deactivate_member(row)
    id = member_row_id(row)
    return if id <= 0 || row["status"].to_s != "active" || !own_member?(row)

    updated = members_table.update(id, "status" => "left", "updated_at" => Time.now.to_i)
    row.replace(updated) if updated.is_a?(Hash)
    row["status"] = "left"
  end

  def touch_table(row, player_count)
    id = table_id(row)
    return row if id <= 0
    raise ArgumentError, "Only the table owner may update it" if owner_of(row).casecmp(Session.name.to_s) != 0

    updated = tables_table.update(
      id,
      "max_players" => capacity_of(row),
      "bot_count" => bot_count(row),
      "player_count" => player_count.to_i + bot_count(row),
      "updated_at" => Time.now.to_i
    )
    updated.is_a?(Hash) ? updated : row
  end

  def table_touch_required?(row, player_count)
    desired_bot_count = bot_count(row)
    row["max_players"].to_i != capacity_of(row) ||
      row["bot_count"].to_i != desired_bot_count ||
      row["player_count"].to_i != player_count.to_i + desired_bot_count
  end

  def close_row(row)
    id = table_id(row)
    raise ArgumentError, "Invalid table row" if id <= 0
    raise ArgumentError, "Only the table owner may close it" if owner_of(row).casecmp(Session.name.to_s) != 0

    updated = tables_table.update(
      id,
      "status" => "closed",
      "player_count" => 0,
      "updated_at" => Time.now.to_i
    )
    row.replace(updated) if updated.is_a?(Hash)
    row["status"] = "closed"
    row["player_count"] = 0
    row
  end

  def update_bot_count(row, difference, snapshot: nil, participant: nil)
    id = table_id(row)
    raise ArgumentError, "Invalid table row" if id <= 0
    raise ArgumentError, "Only the table owner may manage computers" if owner_of(row).casecmp(Session.name.to_s) != 0

    if native_live_sessions?
      current_snapshot = snapshot.is_a?(TableSnapshot) ? snapshot : snapshot_for(row)
      return bot_update_result(:closed, snapshot) if current_snapshot == nil
      current = current_snapshot.table
      current_count = bot_count(current)
      requested = current_count + difference.to_i
      return bot_update_result(:none, current_snapshot) if requested < 0
      return bot_update_result(:full, current_snapshot) if current_snapshot.members.length + requested > capacity_of(current)

      if difference > 0 && current["__discovery_protocol"].to_i < GameRoomLiveSessionStore::CURRENT_DISCOVERY_PROTOCOL
        return bot_update_result(:old_room, current_snapshot)
      end
      bot_names = Array.new(current_count) { |index| current["bot_names"].to_a[index] }
      activity_subject = nil
      if difference > 0
        occupied = current_snapshot.participants.map { |person| GameRoomParticipants.display_name(person) }
        bot_names << GameRoomBotNames.pick(occupied: occupied)
        activity_subject = GameRoomParticipants.bot_id(id, requested, name_token: bot_names.last)
      else
        index = participant == nil ? current_count - 1 : bots_for(current).index(participant)
        return bot_update_result(:stale, current_snapshot) if index == nil
        activity_subject = bots_for(current)[index]
        bot_names.delete_at(index)
      end
      changes = { "bot_count" => requested }
      changes["bot_names"] = bot_names if current["__discovery_protocol"].to_i >= GameRoomLiveSessionStore::CURRENT_DISCOVERY_PROTOCOL
      updated = @transport.update_room(current, changes, actor: Session.name)
      row.replace(updated) if row.is_a?(Hash)
      current_snapshot.table.replace(updated)
      current_snapshot.bots = bots_for(updated)
      activity = append_activity(
        updated,
        difference.to_i > 0 ? "bot_added" : "bot_removed",
        actor: Session.name,
        subject: activity_subject,
        table_users: current_snapshot.members
      )
      return bot_update_result(:updated, current_snapshot, activity: activity)
    end

    cached = snapshot.is_a?(TableSnapshot) && table_id(snapshot.table) == id
    if cached
      return bot_update_result(:stale, snapshot) if !live_members_match?(id, snapshot.members)

      current = snapshot.table.dup
      names = GameRoomParticipants.unique(snapshot.members)
    else
      members = active_member_rows
      current = open_table(id)
      return :closed if current == nil

      names = reconcile_members(current, members)
    end
    current_count = bot_count(current)
    requested = current_count + difference.to_i
    return bot_update_result(:none, snapshot) if requested < 0
    return bot_update_result(:full, snapshot) if names.length + requested > capacity_of(current)

    updated = tables_table.update(
      id,
      "bot_count" => requested,
      "player_count" => names.length + requested,
      "updated_at" => Time.now.to_i
    )
    current.replace(updated) if updated.is_a?(Hash)
    current["bot_count"] = requested
    current["player_count"] = names.length + requested
    row.replace(current) if row.is_a?(Hash)
    if cached
      snapshot.table.replace(current)
      snapshot.members = names
      snapshot.bots = bots_for(current)
    end
    activity = append_activity(
      current,
      difference.to_i > 0 ? "bot_added" : "bot_removed",
      actor: Session.name,
      table_users: names
    )
    notify_table_changed(current, names, actor: Session.name)
    bot_update_result(:updated, snapshot, activity: activity)
  end

  def bot_update_result(status, snapshot, activity: nil)
    return status if snapshot == nil

    BotUpdateResult.new(status: status, snapshot: snapshot, activity: activity)
  end

  def live_members_match?(table_id, expected)
    return true if @transport == nil || !@transport.respond_to?(:connected_users)

    connected = @transport.connected_users(table_id)
    return true if connected == nil

    normalized_users(connected) == normalized_users(expected)
  end

  def normalized_users(users)
    users.to_a.map { |user| user.to_s.downcase }.reject(&:empty?).uniq.sort
  end

  def append_activity(row, kind, actor:, table_users: [], subject: nil)
    arguments = { table: row, kind: kind, actor: actor }
    arguments[:subject] = subject if subject != nil
    @activity_repository&.append_safely(**arguments)
  end

  def status_rank(row)
    waiting?(row) ? 0 : 1
  end

  def notify_table_changed(row, users, actor: Session.name)
    @transport.table_changed(
      table_id: table_id(row),
      users: users,
      actor: actor
    )
  end

  def member_name(row)
    insertion_user = row["__insertion_user"].to_s
    insertion_user.empty? ? row["username"].to_s : insertion_user
  end

  def member_row_id(row)
    (row["__id"] || row["id"]).to_i
  end

  def own_member?(row)
    member_name(row).casecmp(Session.name.to_s) == 0
  end

  def append_unique_user(names, user)
    value = user.to_s
    return if value.empty? || includes_user?(names, value)

    names << value
  end

  def includes_user?(names, user)
    names.any? { |name| name.to_s.casecmp(user.to_s) == 0 }
  end

  def unique_users(users)
    result = []
    users.to_a.each { |user| append_unique_user(result, user) }
    result
  end

  def normalized_name(name)
    name.to_s.strip.gsub(/\s+/, " ")
  end
end
