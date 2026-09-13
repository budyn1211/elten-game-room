=begin Elten3AppInfo
{
  "id": "c24d98cc-9ccd-4d50-b801-459da324ff60",
  "name": "ELTEN Game Room",
  "description": "Accessible multiplayer games for ELTEN users.",
  "version": "1.1.7",
  "build_id": "217",
  "EltenAPIVersion": "3.0.3",
  "main_language": "en",
  "supported_languages": ["en", "pl"],
  "localized_descriptions": {
    "pl": "Dostępne gry wieloosobowe dla użytkowników ELTEN-a."
  },
  "author": "papierek",
  "main": "__app.rb",
  "main_class": "EltenGameRoom",
  "platforms": ["all"],
  "menu": {
    "main": "ELTEN Game Room"
  },
  "required_assets": {
    "sounds": [
      "connect", "disconnect", "chatmsg", "ding", "shuffle", "draw", "draw2",
      "farkle", "interception", "lose1", "lose3", "play", "play2", "replay",
      "reverse", "reverse3", "roll", "skip", "win1", "win2"
    ]
  }
}
=end Elten3AppInfo

require "json"
require_relative "lib/game_room_transport"
require_relative "lib/game_sync"
require_relative "lib/game_room_server_tables"
require_relative "lib/game_room_user_registry"
require_relative "lib/table_activity_repository"
require_relative "lib/game_rules"
require_relative "lib/game_room_screens"
require_relative "lib/invitation_repository"
require_relative "lib/invitation_notifications"
require_relative "lib/game_participants"
require_relative "lib/game_sounds"
require_relative "lib/game_teams"
require_relative "lib/game_bots"
require_relative "lib/lobby_repository"
require_relative "lib/game_repository"
require_relative "lib/game_lifecycle"
require_relative "lib/room_presentation"
require_relative "lib/game_rounds"
require_relative "lib/game_random"
require_relative "lib/game_scoring"
require_relative "lib/hidden_submissions"
require_relative "lib/game_shortcuts"
require_relative "lib/game_surfaces"
require_relative "lib/game_layout"
require_relative "lib/game_simulation"
require_relative "lib/game_training"
require_relative "lib/game_screen"
require_relative "lib/game_content"
require_relative "content/languages"
require_relative "content/monopoly_boards"
require_relative "content/quiz_general_en"
require_relative "content/quiz_pl_wikidata"
require_relative "content/quiz_witcher_pl"
require_relative "games/base"
require_relative "games/board_game"
require_relative "games/card_game"
require_relative "games/four_in_a_row"
require_relative "games/tic_tac_toe"
require_relative "games/chess"
require_relative "games/checkers"
require_relative "games/reversi"
require_relative "games/ludo"
require_relative "games/spades"
require_relative "games/farkle"
require_relative "games/ninety_nine"
require_relative "games/tysiac"
require_relative "games/categories"
require_relative "games/monopoly"
require_relative "games/yahtzee"
require_relative "games/uno"
require_relative "games/poker"
require_relative "games/makao"
require_relative "games/quiz_party"
require_relative "games/registry"

class EltenGameRoom < Program
  GAME_ROOM_VERSION = "1.1.7".freeze
  GAME_ROOM_BUILD_ID = 217
  GAME_ROOM_CAPABILITIES = ["invitations", "live_sessions", "live_session_stack"].freeze
  LOBBY_ACTIVITY_POLL_INTERVAL = 5.0

  SERVER_TABLES = {
    "game_room_users" => {
      "visibility" => "public",
      "columns" => {
        "username" => "string:64",
        "version" => "string:32",
        "build_id" => "integer",
        "capabilities" => "string:256",
        "registered_at" => "integer"
      },
      "permissions" => ["select", "insert", "update"],
      "indexes" => [["username"], ["registered_at"]],
      "limits" => { "max_select_limit" => 1_000 }
    },
    "table_activity" => {
      "visibility" => "public",
      "columns" => {
        "table_id" => "integer",
        "kind" => "string:16",
        "actor" => "string:64",
        "table_owner" => "string:64",
        "game" => "string:32",
        "message" => "string:512",
        "created_at" => "integer"
      },
      "permissions" => ["select", "insert"],
      "indexes" => [["table_id", "created_at"], ["created_at"]],
      "limits" => { "max_select_limit" => 2_000 }
    }
  }.freeze

  MAIN_OPTIONS = [
    _("Create a new table"),
    _("Join a table"),
    _("Game rules"),
    _("Invitations"),
    _("Leaderboards"),
    _("Settings")
  ].freeze

  GAME_REGISTRY = GameRoomGames::Registry.new([
    GameRoomGames::FourInARow,
    GameRoomGames::TicTacToe,
    GameRoomGames::Chess,
    GameRoomGames::Checkers,
    GameRoomGames::Reversi,
    GameRoomGames::Ludo,
    GameRoomGames::Spades,
    GameRoomGames::Farkle,
    GameRoomGames::NinetyNine,
    GameRoomGames::Tysiac,
    GameRoomGames::Categories,
    GameRoomGames::Monopoly,
    GameRoomGames::Yahtzee,
    GameRoomGames::Uno,
    GameRoomGames::Poker,
    GameRoomGames::Makao,
    GameRoomGames::QuizParty
  ])

  DEFAULT_SETTINGS = {
    "announce_lobby_changes" => true,
    "announce_table_created" => true,
    "announce_player_joined" => true,
    "announce_player_left" => true,
    "announce_computer_changes" => true
  }.freeze

  server_app(
    uuid: "468f59c5-c9d7-47cd-80f1-1a6fbfd1aa80",
    tables: SERVER_TABLES,
    protected: true,
    notifications: true
  )

  def self.map_notification(notification)
    metadata = notification.metadata.to_h
    case notification.type.to_s
    when "game_room.invitation"
      notification.presentation(
        title: _("Game invitation"),
        body: _("%{sender} invites you to %{table} (%{game}).") % {
          sender: metadata["sender"].to_s,
          table: metadata["table_name"].to_s,
          game: metadata["game_name"].to_s
        },
        sound: "notification",
        action: :open_invitation
      )
    when "game_room.invitation_rejected"
      notification.presentation(
        title: _("Game invitation declined"),
        body: _("%{user} declined your invitation to %{table}.") % {
          user: metadata["user"].to_s,
          table: metadata["table_name"].to_s
        },
        sound: "notification"
      )
    end
  end

  def program_main
    initialize_services
    check_server_table_access
    current = run_network_task(_("Checking your current table")) do
      @transport.start
      register_game_room_user
      row = @lobby.current_table_for(Session.name)
      establish_table_transport(row, bootstrap: true) if row != nil
      row
    end
    play_game_sound("connect") if current != nil
    run_program_interface(current)
  end

  def signaled(user, packet)
    (@transport ||= GameRoomTransport.new(self)).receive(user, packet)
  end

  def notification_action(action, notification)
    return false if action.to_s.to_sym != :open_invitation

    initialize_services
    check_server_table_access
    run_network_task(_("Connecting to Elten")) { @transport.start }
    invitation_id = notification.metadata.to_h["invitation_id"].to_i
    choices = load_pending_invitations
    return true if choices == nil

    selected = choices.find { |choice| choice[:invitation].id == invitation_id }
    if selected == nil
      revoke_invitation_notification(invitation_id, notification_id: notification.id)
      alert(_("This invitation is no longer available."))
      return true
    end

    case select_notification_invitation_action
    when :accept
      row = accept_pending_invitation(selected[:invitation], notification_id: notification.id)
      run_program_interface(row) if row != nil
    when :reject
      reject_pending_invitation(selected[:invitation], notification_id: notification.id)
    end
    true
  end

  private

  def initialize_services
    @transport ||= GameRoomTransport.new(self)
    @server_tables ||= GameRoomServerTables.new(self)
    @game_room_users ||= GameRoomUserRegistry.new(server_tables: @server_tables)
    @table_activity ||= TableActivityRepository.new(server_tables: @server_tables, transport: @transport)
    @lobby ||= LobbyRepository.new(
      self,
      transport: @transport,
      server_tables: @server_tables,
      activity_repository: @table_activity
    )
    @games ||= GameRepository.new(self, transport: @transport, server_tables: @server_tables)
    @invitations ||= InvitationRepository.new(transport: @transport)
    @invitation_notifications ||= InvitationNotifications.new(
      client: EltenLink::Client.new,
      app_uuid: self.class.server_app_uuid
    )
  end

  def check_server_table_access
    @announced_table_access_state = nil
    # Reset before entering Tasks.run: cancelling before the worker starts must
    # not retain access from an earlier invocation on this same instance.
    @server_tables.reset_access!
    run_network_task(_("Checking server table access"), silent: true) do
      @server_tables.check_access(username: Session.name)
    end
  end

  def announce_server_table_access
    state = @server_tables&.access_state
    return if ![:stamp_required, :unavailable].include?(state)
    return if @announced_table_access_state == state

    @announced_table_access_state = state
    if state == :stamp_required
      alert(_("Development mode without server table access. Global lobby history and sending invitations are unavailable."))
    else
      alert(_("Server table access could not be checked. Global lobby history and sending invitations are unavailable until you reopen Game Room."))
    end
  end

  def invitation_sending_available?
    return true if @server_tables.available?

    if @server_tables.stamp_required?
      alert(_("Sending invitations is unavailable in development mode without server table access."))
    else
      alert(_("Sending invitations is unavailable because server table access could not be confirmed."))
    end
    false
  end

  def run_program_interface(initial_table = nil)
    @lobby_activity_entries = []
    reset_lobby_activity_cursor
    current = initial_table
    loop do
      switched = catch(:game_room_table_switch) do
        show_table_screen(current) if current != nil
        show_main_menu
        return
      end
      current = switched
    end
  end

  def show_main_menu
    @last_seen_lobby_activity_id = nil
    @last_lobby_activity_poll_at = nil
    selected_index = 0
    loop do
      history_items = load_lobby_history
      result = GameRoomScreens::MainMenu.new(
        options: MAIN_OPTIONS,
        history_items: history_items,
        index: selected_index,
        invitations: true,
        refresh: (@server_tables.available? ? ->(form, history) { poll_lobby_activity(form, history) } : nil)
      ).wait
      selected_index = result.index
      case result.action
      when :open
        open_main_option(selected_index)
        reset_lobby_activity_cursor
      when :exit
        return if confirm(_("Do you want to exit ELTEN Game Room?"))
      when :invitations
        switch_to_invited_table
        reset_lobby_activity_cursor
      when :reject_invitation
        show_pending_invitations(mode: :reject)
        reset_lobby_activity_cursor
      when :refresh
        next
      end
    end
  end

  def load_lobby_history
    return [] if !@server_tables.available?

    entries = run_network_task(_("Loading Game Room history"), ui: :none, silent: true) do
      @table_activity.global_entries
    end
    capture_lobby_activity(entries.to_a)
    @lobby_activity_entries.to_a.map do |entry|
      @table_activity.text_for(entry, game_name: ->(id) { game_name(id) }, global: true)
    end.compact
  end

  def capture_lobby_activity(entries)
    newest_id = entries.map(&:id).max.to_i
    if @last_seen_lobby_activity_id == nil
      @last_seen_lobby_activity_id = newest_id
      return
    end

    new_entries = entries.select { |entry| entry.id.to_i > @last_seen_lobby_activity_id.to_i }
    @lobby_activity_entries ||= []
    known_ids = @lobby_activity_entries.each_with_object({}) do |entry, result|
      result[entry.id.to_i] = true
    end
    new_entries.each do |entry|
      @lobby_activity_entries << entry if !known_ids.key?(entry.id.to_i)
    end
    @lobby_activity_entries.sort_by! { |entry| [entry.created_at.to_i, entry.id.to_i] }
    @lobby_activity_entries = @lobby_activity_entries.last(TableActivityRepository::GLOBAL_LIMIT)

    settings = read_json("settings.json", default: DEFAULT_SETTINGS.dup)
    new_entries.each do |entry|
      next if GameRoomParticipants.same?(entry.actor, Session.name)
      next if !lobby_announcement_enabled?(entry.kind, settings)

      text = @table_activity.text_for(entry, game_name: ->(id) { game_name(id) }, global: true)
      speak(text, stop: false, break_sequence: false) if !text.to_s.empty?
    end
    @last_seen_lobby_activity_id = [@last_seen_lobby_activity_id.to_i, newest_id].max
  end

  def poll_lobby_activity(form, history)
    return false if !@server_tables.available? || @lobby_activity_polling == true

    now = monotonic_time
    if @last_lobby_activity_poll_at != nil && now - @last_lobby_activity_poll_at < LOBBY_ACTIVITY_POLL_INTERVAL
      return false
    end

    @last_lobby_activity_poll_at = now
    @lobby_activity_polling = true
    newest_id = run_network_task(_("Loading Game Room history"), ui: form, silent: true) do
      @table_activity.latest_global_id
    end
    return false if newest_id == nil || newest_id.to_i <= @last_seen_lobby_activity_id.to_i

    index = history.index.to_i
    history.options = load_lobby_history
    history.index = bounded_index(index, history.options)
    false
  ensure
    @lobby_activity_polling = false
  end

  def reset_lobby_activity_cursor
    @last_seen_lobby_activity_id = nil
    @last_lobby_activity_poll_at = nil
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rescue Exception
    Time.now.to_f
  end

  def lobby_announcement_enabled?(kind, settings)
    key = case kind.to_s
    when "created" then "announce_table_created"
    when "joined" then "announce_player_joined"
    when "left" then "announce_player_left"
    when "bot_added", "bot_removed" then "announce_computer_changes"
    end
    return false if key == nil
    return settings[key] != false if settings.key?(key)

    settings["announce_lobby_changes"] != false
  end

  def open_main_option(index)
    case index.to_i
    when 0
      show_create_table
    when 1
      show_join_table
    when 2
      show_rules_library
    when 3
      switch_to_invited_table
    when 4
      alert(_("Leaderboards will become available after the first playable game is added."))
    when 5
      show_settings
    end
  end

  def show_rules_library
    game_id = select_game(_("Game rules"), GAME_REGISTRY.ids)
    return if game_id == nil

    show_game_rules(game_definition(game_id))
  end

  def show_game_rules(game, options: nil)
    if game == nil
      alert(_("Rules for this game are not available in this version of ELTEN Game Room."))
      return
    end

    GameRoomScreens::GameRules.new(game.rule_book(options: options)).wait
  end

  def show_create_table
    game_id = select_game(_("Create a new table"), GAME_REGISTRY.ids)
    return if game_id == nil

    game = game_definition(game_id)
    game_options = configure_game_options(game)
    return if game_options == nil

    result = run_network_task(_("Creating table")) do
      created = @lobby.create_table(
        name: default_table_name,
        game: game_id,
        owner: Session.name,
        game_options: JSON.generate(game_options)
      )
      activate_table_transport(created&.table)
      created
    end
    return if result == nil

    alert(_("You are already at a table.")) if !result.created?
    if result.created?
      play_game_sound("connect")
      created_message = _("You created a room.").to_s.sub(/\.\z/, "")
      speak("#{created_message}: #{game_name(game_id)}.")
      # The first focused field is Start game. Let the creation confirmation
      # finish before its focus announcement instead of cutting it off.
      speech_wait
    end
    show_table_screen(result.table)
  end

  def show_join_table
    selected_index = 0
    loop do
      snapshots = run_network_task(_("Loading available tables")) do
        @lobby.open_table_snapshots
      end
      return if snapshots == nil
      if snapshots.empty?
        alert(_("There are no open tables."))
        return
      end

      game_ids = ordered_game_ids(snapshots)
      selected_index = [selected_index, game_ids.length - 1].min
      action = nil
      games = ListBox.new(
        game_ids.map { |game_id| game_lobby_label(game_id, snapshots) },
        header: _("Join a table"),
        index: selected_index,
        quiet: true
      )
      open_button = Button.new(_("Open"))
      back_button = Button.new(_("Back"))
      form = Form.new([games, open_button, back_button], quiet: true)
      form.accept_button = open_button
      form.cancel_button = back_button
      form.hide(open_button)
      form.hide(back_button)
      open_button.on(:press) do
        selected_index = games.index.to_i
        action = :open
        form.resume
      end
      back_button.on(:press) do
        action = :back
        form.resume
      end

      form.wait
      return if action != :open
      entered = show_tables_for_game(game_ids[selected_index])
      return if entered == true
    end
  end

  def show_tables_for_game(game_id)
    selected_index = 0
    loop do
      snapshots = run_network_task(_("Loading tables")) do
        @lobby.open_table_snapshots(game: game_id)
      end
      return false if snapshots == nil
      if snapshots.empty?
        alert(_("There are no open tables for this game."))
        return false
      end

      selected_index = [selected_index, snapshots.length - 1].min
      action = nil
      tables = ListBox.new(
        snapshots.map { |snapshot| table_join_label(snapshot) },
        header: game_name(game_id),
        index: selected_index,
        quiet: true
      )
      join_button = Button.new(_("Join"))
      back_button = Button.new(_("Back"))
      form = Form.new([tables, join_button, back_button], quiet: true)
      form.accept_button = join_button
      form.cancel_button = back_button
      form.hide(join_button)
      form.hide(back_button)
      join_button.on(:press) do
        selected_index = tables.index.to_i
        action = :join
        form.resume
      end
      back_button.on(:press) do
        action = :back
        form.resume
      end

      form.wait
      return false if action != :join

      result = run_network_task(_("Joining table")) do
        selected_table = snapshots[selected_index].table
        connected = establish_table_transport(selected_table, bootstrap: true)
        next :transport_failed if !connected

        joined = @lobby.join_table(selected_table, Session.name, announce: false)
        if joined&.entered?
          @lobby.announce_table_joined(joined.table, joined.members, actor: Session.name) if joined.status == :joined
        else
          @transport.deactivate_table(table_id: @lobby.table_id(selected_table))
        end
        joined
      end
      return false if result == nil
      if result == :transport_failed
        alert(_("The real-time connection to this table could not be established. Please try again."))
        next
      end

      case result.status
      when :joined, :already_here
        announce_joined_room(result.table) if result.status == :joined
        show_table_screen(result.table)
        return true
      when :already_at_another_table
        alert(_("You are already at another table."))
        show_table_screen(result.table)
        return true
      when :full
        alert(_("This table is full."))
      when :closed
        alert(_("This table is no longer available."))
      end
    end
  end

  def select_game(header, game_ids)
    selected_index = 0
    action = nil
    games = ListBox.new(
      game_ids.map { |game_id| game_name(game_id) },
      header: header,
      index: selected_index,
      quiet: true
    )
    select_button = Button.new(_("Select"))
    back_button = Button.new(_("Back"))
    form = Form.new([games, select_button, back_button], quiet: true)
    form.accept_button = select_button
    form.cancel_button = back_button
    form.hide(select_button)
    form.hide(back_button)
    select_button.on(:press) do
      selected_index = games.index.to_i
      action = :select
      form.resume
    end
    back_button.on(:press) { form.resume }

    form.wait
    action == :select ? game_ids[selected_index] : nil
  end

  def configure_game_options(game)
    return {} if game == nil

    selected = {}
    definitions = game.effective_option_definitions(selected).to_a
    return game.default_options if definitions.empty?
    built_language = game.default_options[GameRoomContent::LANGUAGE_OPTION_KEY].to_s
    focused_option_key = nil

    loop do
      controls = [Static.new(_("Choose game options using Tab and the arrow keys. In lists allowing multiple selections, use Space to select or clear an item."))]
      bindings = []
      defaults = remembered_game_option_defaults(game, definitions).merge(selected)
      definitions.each do |definition|
        key = definition.key.to_s
        case definition.kind.to_s
        when "boolean"
          control = CheckBox.new(
            definition.label.to_s,
            checked: defaults[key] == true
          )
          controls << control
          bindings << [definition, control]
        when "choice"
          choices = definition.choices.to_a
          default_index = choices.index do |choice|
            choice.value.to_s == defaults[key].to_s
          end.to_i
          control = ListBox.new(
            choices.map { |choice| choice.label.to_s },
            header: definition.label.to_s,
            index: default_index,
            quiet: true
          )
          controls << control
          bindings << [definition, control]
        when "multiple_choice"
          choices = definition.choices.to_a
          control = ListBox.new(
            choices.map { |choice| choice.label.to_s },
            header: definition.label.to_s,
            index: 0,
            flags: ListBox::Flags::MultiSelection,
            quiet: true
          )
          mask = defaults[key].to_i
          control.select_multiselection_indices(
            choices.each_index.select { |index| (mask & (1 << index)) != 0 }
          )
          controls << control
          bindings << [definition, control]
        when "integer"
          control = EditBox.new(
            definition.label.to_s,
            type: EditBox::Flags::Numbers,
            text: defaults[key].to_i.to_s,
            quiet: true
          )
          control.select_all if !control.text.to_s.empty?
          controls << control
          bindings << [definition, control]
        else
          raise ArgumentError, "Unsupported game option type: #{definition.kind}"
        end
      end

      action = nil
      save_button = Button.new(_("Create table"))
      cancel_button = Button.new(_("Cancel"))
      focused_binding_index = bindings.index do |definition, _control|
        definition.key.to_s == focused_option_key
      end
      form_index = focused_binding_index == nil ? 0 : focused_binding_index + 1
      form = Form.new(controls + [save_button, cancel_button], index: form_index, quiet: true)
      focused_option_key = nil
      form.accept_button = save_button
      form.cancel_button = cancel_button
      refresh_visibility = lambda do
        values = game.normalize_options(game_option_values(bindings))
        bindings.each do |definition, control|
          if game.option_visible?(definition, values)
            form.show(control)
          else
            form.hide(control)
          end
        end
      end
      bindings.each do |definition, control|
        event = definition.kind.to_s == "boolean" ? :change : :move
        control.on(event) { refresh_visibility.call } if ["boolean", "choice"].include?(definition.kind.to_s)
      end
      refresh_visibility.call
      save_button.on(:press) do
        action = :save
        form.resume
      end
      cancel_button.on(:press) do
        action = :cancel
        form.resume
      end
      language_binding = bindings.find do |definition, _control|
        definition.key.to_s == GameRoomContent::LANGUAGE_OPTION_KEY
      end
      if language_binding != nil
        language_binding[1].on(:move) do
          action = :language_changed
          form.resume
        end
      end
      form.wait
      if action == :language_changed
        options = game.normalize_options(game_option_values(bindings))
        selected = options
        built_language = options[GameRoomContent::LANGUAGE_OPTION_KEY].to_s
        definitions = game.effective_option_definitions(selected).to_a
        focused_option_key = GameRoomContent::SET_OPTION_KEY
        next
      end
      return nil if action != :save

      raw = game_option_values(bindings)
      options = game.normalize_options(raw)
      chosen_language = options[GameRoomContent::LANGUAGE_OPTION_KEY].to_s
      if chosen_language != built_language
        selected = options
        built_language = chosen_language
        definitions = game.effective_option_definitions(selected).to_a
        next
      end
      error = game.validation_error(options)
      if error == nil
        remember_multiple_choice_options(game, definitions, options)
        return options
      end

      alert(error)
    end
  end

  def game_option_values(bindings)
    bindings.each_with_object({}) do |(definition, control), raw|
      key = definition.key.to_s
      raw[key] = if definition.kind.to_s == "boolean"
        control.checked == true
      elsif definition.kind.to_s == "integer"
        control.text.to_s
      elsif definition.kind.to_s == "multiple_choice"
        choices = definition.choices.to_a
        control.multiselections.filter_map { |index| choices[index]&.value }
      else
        choices = definition.choices.to_a
        selected = choices[control.index.to_i]
        selected == nil ? definition.default : selected.value
      end
    end
  end

  def remembered_game_option_defaults(game, definitions)
    defaults = game.default_options.dup
    preferences = read_json("game_option_preferences.json", default: {})
    stored = preferences.is_a?(Hash) ? preferences[game.id.to_s] : nil
    return defaults if !stored.is_a?(Hash)

    definitions.each do |definition|
      next if definition.kind.to_s != "multiple_choice" && game.id.to_s != "makao"
      next if game.id.to_s == "makao" && definition.key.to_s == "profile"

      key = definition.key.to_s
      defaults[key] = stored[key] if stored.key?(key)
    end
    defaults
  rescue StandardError => error
    Log.warning("ELTEN Game Room could not read option preferences: #{error.class}: #{error.message}") if defined?(Log)
    game.default_options
  end

  def remember_multiple_choice_options(game, definitions, options)
    remembered = if game.id.to_s == "makao" && options["profile"].to_s == "custom"
      definitions.reject { |definition| definition.key.to_s == "profile" }
    else
      definitions.select { |definition| definition.kind.to_s == "multiple_choice" }
    end
    return if remembered.empty?

    update_json("game_option_preferences.json", default: {}) do |root|
      root = {} if !root.is_a?(Hash)
      stored = root[game.id.to_s]
      stored = {} if !stored.is_a?(Hash)
      remembered.each do |definition|
        key = definition.key.to_s
        stored[key] = options[key]
      end
      root[game.id.to_s] = stored
      root
    end
  rescue StandardError => error
    Log.warning("ELTEN Game Room could not save option preferences: #{error.class}: #{error.message}") if defined?(Log)
  end

  def show_table_screen(row)
    return if row == nil

    @table_layouts ||= {}
    table_id = @lobby.table_id(row)
    layout = nil
    quiet_reentry = false
    synchronizer = GameRoomSync::Controller.new(
      transport: @transport, table_id: table_id,
      reconnect: -> { activate_table_transport(row) }
    )
    loop do
      state = load_room_state(
        row, title: _("Updating table"), synchronizer: synchronizer,
        ui: layout&.focus_location.to_a[0] == :chat ? layout.chat : :none
      )
      return if state == nil

      snapshot = state.room
      row = snapshot.table
      owner = @lobby.owner_of(row)
      own_table = GameRoomParticipants.same?(owner, Session.name)
      play_game_sounds(room_membership_tracker(row).observe(snapshot.members))
      activity_cursor = announce_new_table_activity(state.activity_entries, after_id: layout&.activity_cursor)
      synchronizer.update_session(state.session_id(@games))
      view_spec = if state.replay != nil && state.game != nil
        state.game.game_view_spec(state.replay, Session.name)
      else
        GameRoomLayout::ViewSpec.new(history_empty_label: _("No games have been played yet"))
      end
      options = {
        view_spec: view_spec, history_items: room_history_items(state, state.activity_entries),
        user_items: room_user_rows(state), users_header: table_header(snapshot),
        phase: state.phase, own_table: own_table
      }
      if layout == nil
        layout = GameRoomLayout::Screen.new(**options)
        @table_layouts[table_id] = layout
      else
        layout.update(**options)
      end
      layout.activity_cursor = activity_cursor
      if state.active? || state.finished?
        result = run_game_screen(state.session, state.game, table: row)
        if result == :room_closed
          forget_room_membership(row)
          return
        end
        start_new_game(row) if result == :restart
        return if result == :back && leave_table_from_screen(row)

        quiet_reentry = true
        next
      end

      layout.begin_bindings
      layout.back_button.label = _("Leave")
      form = layout.form
      action = nil
      participant = nil
      dispatch = lambda do |requested, selected = nil|
        next if action != nil

        action = requested
        participant = selected
        form.resume
      end
      layout.primary_button.on(:press) { dispatch.call(:start_game) }
      layout.back_button.on(:press) { dispatch.call(:leave) }
      layout.chat.on_submit do
        if layout.chat.text.to_s.strip.empty?
          alert(_("Type a chat message first."))
        else
          dispatch.call(:chat)
        end
      end
      GameRoomParticipantMenu.bind(layout, available: -> do
        [:invite_online, :invite_contacts, :rules, :leave] +
          GameRoomParticipantMenu.role_actions(room: snapshot, viewer: Session.name) +
          GameRoomParticipantMenu.management_actions(
            room: snapshot, game: state.game, active: state.active?, viewer: Session.name, owner: owner
          )
      end, &dispatch)
      form.add_timer(FormTimer.new(GameScreen::TIMER_INTERVAL, repeat: true) do
        next if action != nil

        event = synchronizer.next_event(idle: form.keyboard_idle_frame?)
        next if event == nil

        action = :refresh
        form.resume_for_refresh
      end)
      quiet_reentry ? layout.wait_without_announcement : form.wait
      layout.begin_bindings
      quiet_reentry = false
      case action
      when :start_game
        start_new_game(row)
        quiet_reentry = true
      when :add_bot, :remove_bot
        change_room_computer(row, action, participant)
        quiet_reentry = true
      when :observe_next_game, :play_next_game
        change_observer_mode(row, action)
        quiet_reentry = true
      when :rules
        show_game_rules(state.game, options: state.game&.options_from_json(row["game_options"]))
      when :invite_online
        show_invite_users(row, source: :online)
      when :invite_contacts
        show_invite_users(row, source: :contacts)
      when :chat
        entry = run_network_task(_("Sending chat message"), ui: :none) do
          saved = @table_activity.append(table: row, kind: "chat", message: layout.chat.text)
          @lobby.announce_table_activity(row, snapshot.members, actor: Session.name) if saved != nil
          saved
        end
        if entry != nil
          play_game_sound("chatmsg")
          text = @table_activity.text_for(entry, game_name: ->(id) { game_name(id) }, global: false)
          speak(text, stop: false, break_sequence: false) if !text.to_s.empty?
          layout.chat.set_text("")
          layout.chat.index = layout.chat.check = 0
        end
        quiet_reentry = true
      when :leave
        return if leave_table_from_screen(row)
      when :refresh
        quiet_reentry = true
      end
    end
  ensure
    layout&.begin_bindings
    @table_layouts&.delete(table_id) if table_id != nil
  end

  def leave_table_from_screen(row)
    own_table = GameRoomParticipants.same?(@lobby.owner_of(row), Session.name)
    question = own_table ? _("Do you want to leave the table? The table will be closed for everyone.") : _("Do you want to leave the table?")
    return false if !confirm(question)

    result = run_network_task(_("Leaving table")) do
      left = @lobby.leave_table(row, Session.name)
      @transport.deactivate_table(table_id: @lobby.table_id(row)) if left != nil
      left
    end
    return false if result == nil

    play_game_sound("disconnect")
    forget_room_membership(row)
    true
  end

  def change_room_computer(row, action, participant)
    state = load_room_state(row, title: _("Checking the table members"))
    return if state == nil

    available = GameRoomParticipantMenu.management_actions(
      room: state.room, game: state.game, active: state.active?,
      viewer: Session.name, owner: @lobby.owner_of(state.room.table)
    )
    return if !available.include?(action)
    return if action == :remove_bot && !GameRoomParticipants.includes?(state.room.bots, participant)

    result = run_network_task(action == :add_bot ? _("Adding computer") : _("Removing computer")) do
      if action == :add_bot
        @lobby.add_bot(row, snapshot: state.room)
      else
        # Computers are numbered slots in the existing protocol. Delete on
        # any computer removes one slot; the remaining numbering is 1..N.
        @lobby.remove_bot(row, snapshot: state.room)
      end
    end
    status = result.respond_to?(:status) ? result.status : result
    alert(_("This table is full.")) if status == :full
    alert(_("This table is no longer available.")) if status == :closed
    result
  end

  def change_observer_mode(row, action)
    observing = action == :observe_next_game
    title = observing ? _("Enabling observer mode") : _("Enabling player mode")
    snapshot = run_network_task(title, ui: :none) do
      @lobby.set_observer(row, Session.name, observing)
    end
    return nil if snapshot == nil

    message = observing ? _("You will observe the next game.") : _("You will play in the next game.")
    speak(message, stop: false, break_sequence: false)
    snapshot
  end

  def show_invite_users(row, source:)
    return if !invitation_sending_available?

    payload = run_network_task(_("Loading users")) do
      snapshot = @lobby.snapshot_for(row)
      next nil if snapshot == nil

      client = EltenLink::Client.new
      users = if source == :contacts
        EltenLink::Contacts.list(client)
      else
        EltenLink::Users.online(client)
      end
      participants = snapshot.participants
      candidates = @game_room_users.registered(users).reject do |user|
        user.to_s.casecmp(Session.name.to_s) == 0 ||
          participants.any? { |participant| participant.to_s.casecmp(user.to_s) == 0 }
      end
      [snapshot, candidates]
    end
    return if payload == nil

    snapshot, candidates = payload
    if candidates.empty?
      message = source == :contacts ? _("There are no contacts available to invite.") : _("There are no online users available to invite.")
      alert(message)
      return
    end

    selected = select_invitation_recipient(
      candidates,
      source == :contacts ? _("Invite from contacts") : _("Invite an online user")
    )
    return if selected == nil

    result = run_network_task(_("Sending invitation"), ui: :none) do
      current = @lobby.snapshot_for(snapshot.table)
      next :closed if current == nil
      next :not_at_table if !current.participants.any? { |participant| participant.to_s.casecmp(Session.name.to_s) == 0 }
      next :already_here if current.participants.any? { |participant| participant.to_s.casecmp(selected.to_s) == 0 }

      created = @invitations.deliver(
        table: current.table,
        sender: Session.name,
        recipient: selected
      ) do |invitation|
        @transport.invite_user(
          table_id: @lobby.table_id(current.table),
          user: selected,
          metadata: invitation_metadata(current.table, invitation_row_id(invitation))
        )
      end
      next :failed if created == nil
      next :duplicate if !created.created?

      invitation_id = invitation_row_id(created.invitation)
      metadata = invitation_metadata(current.table, invitation_id)
      begin
        send_notification(
          selected,
          type: "game_room.invitation",
          metadata: metadata,
          expires_in: InvitationRepository::DEFAULT_TTL
        )
      rescue StandardError => error
        Log.warning("ELTEN Game Room notification delivery failed: #{error.class}: #{error.message}") if defined?(Log)
      end
      :sent
    end

    case result
    when :sent
      alert(_("Invitation sent."))
    when :failed
      alert(_("The operation could not be completed. Please try again."))
    when :duplicate
      alert(_("An invitation to this table is already pending for this user."))
    when :already_here
      alert(_("This user is already at the table."))
    when :closed, :not_at_table
      alert(_("This table is no longer available."))
    end
  end

  def select_invitation_recipient(users, header)
    action = nil
    selected_index = 0
    list = ListBox.new(users, header: header, index: selected_index, quiet: true)
    invite_button = Button.new(_("Invite"))
    back_button = Button.new(_("Back"))
    form = Form.new([list, invite_button, back_button], quiet: true)
    form.accept_button = invite_button
    form.cancel_button = back_button
    form.hide(invite_button)
    form.hide(back_button)
    invite_button.on(:press) do
      selected_index = list.index.to_i
      action = :invite
      form.resume
    end
    back_button.on(:press) { form.resume }
    form.wait
    action == :invite ? users[selected_index] : nil
  end

  def show_pending_invitations(preferred_id: nil, mode: :accept)
    choices = load_pending_invitations
    return nil if choices == nil
    if choices.empty?
      alert(_("There are no pending invitations."))
      return nil
    end

    selected = if preferred_id.to_i > 0
      choices.find { |choice| choice[:invitation].id == preferred_id.to_i }
    elsif choices.length == 1
      choices.first
    else
      select_pending_invitation(choices, mode: mode)
    end
    if selected == nil && preferred_id.to_i > 0
      alert(_("This invitation is no longer available."))
      return nil
    end
    return nil if selected == nil

    if mode == :reject
      reject_pending_invitation(selected[:invitation])
      nil
    else
      accept_pending_invitation(selected[:invitation])
    end
  end

  def load_pending_invitations
    run_network_task(_("Loading invitations")) do
      snapshots = @lobby.open_table_snapshots
      by_id = snapshots.to_h { |snapshot| [@lobby.table_id(snapshot.table), snapshot] }
      pending = @invitations.pending_for(
        Session.name,
        tables: snapshots.map(&:table)
      )
      pending.filter_map do |invitation|
        snapshot = by_id[invitation.table_id]
        if snapshot == nil || snapshot.participant_count >= @lobby.capacity_of(snapshot.table)
          @invitations.respond(invitation, recipient: Session.name, response: "expired")
          next nil
        end
        { invitation: invitation, snapshot: snapshot }
      end
    end
  end

  def select_pending_invitation(choices, mode: :accept)
    action = nil
    selected_index = 0
    invitations = ListBox.new(
      choices.map { |choice| pending_invitation_label(choice) },
      header: _("Invitations"),
      index: selected_index,
      quiet: true
    )
    join_button = Button.new(mode == :reject ? _("Reject") : _("Accept"))
    back_button = Button.new(_("Back"))
    form = Form.new([invitations, join_button, back_button], quiet: true)
    form.accept_button = join_button
    form.cancel_button = back_button
    form.hide(join_button)
    form.hide(back_button)
    join_button.on(:press) do
      selected_index = invitations.index.to_i
      action = mode
      form.resume
    end
    back_button.on(:press) { form.resume }
    form.wait
    [:accept, :reject].include?(action) ? choices[selected_index] : nil
  end

  def pending_invitation_label(choice)
    invitation = choice[:invitation]
    snapshot = choice[:snapshot]
    _("%{game}; %{table}; invited by %{sender}; %{count}/%{maximum}") % {
      game: game_name(snapshot.table["game"]),
      table: snapshot.table["name"].to_s,
      sender: invitation.sender,
      count: snapshot.participant_count,
      maximum: @lobby.capacity_of(snapshot.table)
    }
  end

  def accept_pending_invitation(invitation, notification_id: nil)
    payload = run_network_task(_("Checking invitation")) do
      snapshots = @lobby.open_table_snapshots
      current_invitation = @invitations.pending_by_id(
        invitation.id,
        Session.name,
        tables: snapshots.map(&:table)
      )
      snapshot = snapshots.find { |item| @lobby.table_id(item.table) == invitation.table_id }
      current = @lobby.current_table_for(Session.name)
      [current_invitation, snapshot, current]
    end
    return nil if payload == nil

    current_invitation, snapshot, current = payload
    if current_invitation == nil || snapshot == nil || snapshot.participant_count >= @lobby.capacity_of(snapshot.table)
      revoke_invitation_notification(invitation.id, notification_id: notification_id)
      alert(_("This invitation is no longer available."))
      return nil
    end

    if current != nil && @lobby.table_id(current) == current_invitation.table_id
      connected = run_network_task(_("Accepting invitation")) do
        accepted = establish_table_transport(current_invitation.table, invitation_id: current_invitation.id)
        if accepted
          @invitations.respond(current_invitation, recipient: Session.name, response: "accepted")
          revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
        else
          @invitations.respond(current_invitation, recipient: Session.name, response: "expired")
          revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
        end
        accepted
      end
      if connected
        alert(_("You are already at this table."))
      else
        alert(_("The real-time connection to this table could not be established. Please try again."))
      end
      return nil
    end

    if current != nil && !confirm(_("Do you want to leave your current table and join the invited table?"))
      return nil
    end

    left_current = false
    result = run_network_task(_("Accepting invitation")) do
      connected = establish_table_transport(current_invitation.table, invitation_id: current_invitation.id)
      if !connected
        @invitations.respond(current_invitation, recipient: Session.name, response: "expired")
        revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
        next :transport_failed
      end

      if current != nil
        old_table_id = @lobby.table_id(current)
        @lobby.leave_table(current, Session.name)
        @transport.deactivate_table(table_id: old_table_id)
        left_current = true
      end

      joined = @lobby.join_table(current_invitation.table, Session.name, announce: false)
      if joined.entered?
        @lobby.announce_table_joined(joined.table, joined.members, actor: Session.name) if joined.status == :joined
        @invitations.respond(current_invitation, recipient: Session.name, response: "accepted")
        revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
      elsif [:closed, :full].include?(joined.status)
        @transport.deactivate_table(table_id: current_invitation.table_id)
        @invitations.respond(current_invitation, recipient: Session.name, response: "expired")
        revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
      else
        @transport.deactivate_table(table_id: current_invitation.table_id)
      end
      joined
    end
    return nil if result == nil

    if left_current
      play_game_sound("disconnect")
      forget_room_membership(current)
    end

    if result == :transport_failed
      alert(_("The real-time connection to this table could not be established. Please try again."))
      return nil
    end

    case result.status
    when :joined, :already_here
      announce_joined_room(result.table) if result.status == :joined
      result.table
    when :full
      alert(_("This table is full."))
      nil
    when :closed
      alert(_("This table is no longer available."))
      nil
    when :already_at_another_table
      alert(_("You are already at another table."))
      nil
    end
  end

  def reject_pending_invitation(invitation, notification_id: nil)
    result = run_network_task(_("Rejecting invitation")) do
      snapshots = @lobby.open_table_snapshots
      current_invitation = @invitations.pending_by_id(
        invitation.id,
        Session.name,
        tables: snapshots.map(&:table)
      )
      next :unavailable if current_invitation == nil

      @transport.reject_invitation(
        table_id: current_invitation.table_id,
        invitation_id: current_invitation.id
      )
      @invitations.respond(current_invitation, recipient: Session.name, response: "rejected")
      revoke_invitation_notification(current_invitation.id, notification_id: notification_id)
      begin
        send_notification(
          current_invitation.sender,
          type: "game_room.invitation_rejected",
          metadata: {
            "user" => Session.name.to_s,
            "table_id" => current_invitation.table_id,
            "table_name" => current_invitation.table["name"].to_s
          },
          expires_in: 60 * 60
        )
      rescue StandardError => error
        Log.warning("ELTEN Game Room invitation rejection notification failed: #{error.class}: #{error.message}") if defined?(Log)
      end
      :rejected
    end

    case result
    when :rejected
      alert(_("Invitation rejected."))
      true
    when :unavailable
      revoke_invitation_notification(invitation.id, notification_id: notification_id)
      alert(_("This invitation is no longer available."))
      false
    else
      false
    end
  end

  def select_notification_invitation_action
    action = nil
    choices = [_("Accept invitation"), _("Reject invitation")]
    actions = ListBox.new(choices, header: _("Invitation"), index: 0, quiet: true)
    select_button = Button.new(_("Select"))
    back_button = Button.new(_("Back"))
    form = Form.new([actions, select_button, back_button], quiet: true)
    form.accept_button = select_button
    form.cancel_button = back_button
    form.hide(select_button)
    form.hide(back_button)
    select_button.on(:press) do
      action = actions.index.to_i == 0 ? :accept : :reject
      form.resume
    end
    back_button.on(:press) { form.resume }
    form.wait
    action
  end

  def revoke_invitation_notification(invitation_id, notification_id: nil)
    @invitation_notifications.revoke(invitation_id, notification_id: notification_id)
    true
  rescue StandardError => error
    Log.warning("ELTEN Game Room invitation notification cleanup failed: #{error.class}: #{error.message}") if defined?(Log)
    false
  end

  def switch_to_invited_table
    row = show_pending_invitations
    throw(:game_room_table_switch, row) if row != nil
  end

  def announce_joined_room(row)
    play_game_sound("connect")
    speak(_("You joined %{player}'s room.") % {
      player: GameRoomParticipants.display_name(@lobby.owner_of(row))
    })
    # The waiting status is the first focused field for a guest. Queue it
    # after the room confirmation instead of letting it cut that message off.
    speech_wait
  end

  def invitation_metadata(row, invitation_id)
    {
      "kind" => "game_room_invitation",
      "invitation_id" => invitation_id,
      "table_id" => @lobby.table_id(row),
      "table_name" => row["name"].to_s,
      "game" => row["game"].to_s,
      "game_name" => game_name(row["game"]),
      "sender" => Session.name.to_s,
      "expires_at" => Time.now.to_i + InvitationRepository::DEFAULT_TTL
    }
  end

  def invitation_row_id(row)
    (row["__id"] || row["id"]).to_i
  end

  def show_settings
    settings = read_json("settings.json", default: DEFAULT_SETTINGS.dup)
    updated = GameRoomScreens::Settings.new(settings).wait
    return if updated == nil

    update_json("settings.json", default: DEFAULT_SETTINGS.dup) do |state|
      updated.each { |key, value| state[key] = value }
      state
    end
    alert(_("Settings saved."))
  end

  def run_network_task(title, ui: nil, silent: false, &operation)
    options = { title: title, cancellable: true, show_after: 5.0 }
    options[:ui] = ui if ui != nil
    result = EltenAPI::Tasks.run(**options) do |progress, token|
      token.raise_if_cancelled!
      operation.call
    end
    announce_server_table_access
    result
  rescue EltenAPI::Tasks::Cancelled
    nil
  rescue StandardError => error
    raise if !GameRoomNetworkErrors.expected?(error)

    Log.warning("ELTEN Game Room network operation failed: #{error.class}: #{error.message}")
    if @server_tables&.last_error.equal?(error)
      announce_server_table_access
    else
      alert(_("The operation could not be completed. Please try again.")) if !silent
    end
    nil
  end

  def register_game_room_user
    return if !@server_tables.available?

    @game_room_users.register(
      username: Session.name,
      version: GAME_ROOM_VERSION,
      build_id: GAME_ROOM_BUILD_ID,
      capabilities: GAME_ROOM_CAPABILITIES
    )
  rescue EltenLink::Error => error
    Log.warning("ELTEN Game Room user registration failed: #{error.class}: #{error.message}") if defined?(Log)
    nil
  end

  def activate_table_transport(row)
    return false if row == nil

    @transport.activate_table(
      table_id: @lobby.table_id(row),
      owner: @lobby.owner_of(row),
      capacity: @lobby.capacity_of(row),
      user: Session.name
    )
  end

  def establish_table_transport(row, invitation_id: nil, bootstrap: false)
    return false if row == nil

    @transport.establish_membership(
      table_id: @lobby.table_id(row),
      owner: @lobby.owner_of(row),
      capacity: @lobby.capacity_of(row),
      user: Session.name,
      invitation_id: invitation_id,
      bootstrap: bootstrap,
      table: row,
      timeout: 10.0
    )
  end

  def missing_live_session_members(snapshot)
    connected = @transport.connected_users(@lobby.table_id(snapshot.table))
    return [] if connected == nil

    snapshot.members.reject do |member|
      connected.any? { |user| GameRoomParticipants.same?(user, member) }
    end
  end

  def ordered_game_ids(snapshots)
    available = snapshots.map { |snapshot| snapshot.table["game"].to_s }.uniq
    known = GAME_REGISTRY.ids.select { |game_id| available.include?(game_id) }
    known + (available - known).sort
  end

  def game_lobby_label(game_id, snapshots)
    matching = snapshots.select { |snapshot| snapshot.table["game"].to_s == game_id.to_s }
    waiting = matching.count { |snapshot| @lobby.waiting?(snapshot.table) }
    _("%{game} (%{waiting}/%{total})") % {
      game: game_name(game_id),
      waiting: waiting,
      total: matching.length
    }
  end

  def table_join_label(snapshot)
    row = snapshot.table
    label = _("%{status}; %{name}; host: %{owner}; users: %{users}; %{count}/%{maximum}") % {
      status: table_status_label(row),
      name: row["name"].to_s,
      owner: @lobby.owner_of(row),
      users: snapshot.participants.map { |participant| GameRoomParticipants.display_name(participant) }.join(", "),
      count: snapshot.participant_count,
      maximum: @lobby.capacity_of(row)
    }
    summary = game_options_summary(row)
    summary.empty? ? label : "#{label}; #{summary}"
  end

  def table_header(snapshot)
    row = snapshot.table
    label = _("Users at the table. %{status}; %{name}; %{game}; host: %{owner}; %{count}/%{maximum}") % {
      status: table_status_label(row),
      name: row["name"].to_s,
      game: game_name(row["game"]),
      owner: @lobby.owner_of(row),
      count: snapshot.participant_count,
      maximum: @lobby.capacity_of(row)
    }
    summary = game_options_summary(row)
    summary.empty? ? label : "#{label}; #{summary}"
  end

  def game_options_summary(row)
    game = game_definition(row["game"])
    return "" if game == nil

    game.combined_options_summary(game.options_from_json(row["game_options"]))
  end

  def room_history_items(state, room_activity = [])
    replay = state.replay
    game_events = replay == nil ? [] : replay.accepted_events
    @table_activity.merge_history(
      game_entries: state.history,
      game_events: game_events,
      activity_entries: room_activity,
      game_name: ->(id) { game_name(id) }
    )
  end

  def announce_new_table_activity(entries, after_id:)
    newest_id = entries.to_a.map(&:id).max.to_i
    return newest_id if after_id == nil

    entries.to_a.select { |entry| entry.id.to_i > after_id.to_i }.each do |entry|
      next if entry.kind == "chat" && GameRoomParticipants.same?(entry.actor, Session.name)

      play_game_sound("chatmsg") if entry.kind == "chat"
      text = @table_activity.text_for(entry, game_name: ->(id) { game_name(id) }, global: false)
      speak(text, stop: false, break_sequence: false) if !text.to_s.empty?
    end
    [after_id.to_i, newest_id].max
  end

  def room_history_header(state)
    return _("Current game history") if active_game?(state)
    return _("Last game history") if state.replay != nil

    _("Game history")
  end

  def room_user_rows(state)
    options = state.session == nil ? {} : state.game&.options_from_json(state.session["options"])
    RoomPresentation.game_users(
      room: state.room, game: state.game, replay: state.replay,
      players: state.players, owner: @lobby.owner_of(state.room.table), options: options
    )
  end

  def table_status_label(row)
    @lobby.playing?(row) ? _("game in progress") : _("open")
  end

  def room_players(state)
    state.players
  end

  def active_game?(state)
    state.active?
  end

  def start_new_game(row, state: nil)
    state ||= load_room_state(row, title: _("Checking the table before starting"))
    return if state == nil

    row = state.room.table
    owner = @lobby.owner_of(row)
    if !GameRoomParticipants.same?(owner, Session.name)
      alert(_("Only the table master may start a game."))
      return
    end
    if state.active?
      alert(_("A game has already started. Opening the current game."))
      return state.session
    end

    game = state.game || game_definition(row["game"])
    if game == nil
      alert(_("This game is not supported by this version of ELTEN Game Room."))
      return
    end

    participants = state.room.game_participants
    if !valid_player_count?(game, participants.length)
      alert(invalid_player_count_message(game, participants.length))
      return
    end

    options = game.options_from_json(row["game_options"])
    options_error = game.validation_error(options, player_count: participants.length)
    if options_error != nil
      alert(options_error)
      return
    end

    options = configure_team_assignment(game, options, participants)
    return if options == nil

    refreshed_room = run_network_task(_("Checking the table members")) { @lobby.snapshot_for(row, force: true) }
    return if refreshed_room == nil
    if @lobby.playing?(refreshed_room.table)
      refreshed = load_room_state(refreshed_room.table, title: _("Opening the current game"))
      return if refreshed == nil || !refreshed.active?

      alert(_("A game has already started. Opening the current game."))
      return refreshed.session
    end
    latest_participants = refreshed_room.game_participants
    if !same_participant_order?(participants, latest_participants)
      alert(_("The users at the table changed while teams were being selected. Please start again."))
      return
    end
    missing_live_members = missing_live_session_members(refreshed_room)
    if !missing_live_members.empty?
      alert(
        _("The game cannot start until these players join the real-time session: %{players}.") % {
          players: missing_live_members.map { |player| GameRoomParticipants.display_name(player) }.join(", ")
        }
      )
      return
    end
    row = refreshed_room.table

    previous_id = state.session_id(@games)
    run_network_task(_("Starting game")) do
      started = @games.start_session(
        table: row,
        game: game.id,
        players: participants,
        options: JSON.generate(options),
        recipients: refreshed_room.members,
        expected_previous_session_id: previous_id
      )
      @lobby.set_game_active(row, true, snapshot: refreshed_room) if started != nil
      started
    end
  end

  def configure_team_assignment(game, options, participants)
    assignment = game.team_assignment(options, players: participants)
    return options if assignment == nil

    player_index = 0
    loop do
      player_index = [[player_index, 0].max, assignment.players.length - 1].min
      labels = assignment.players.each_with_index.map do |participant, index|
        _("%{player}, team %{team}") % {
          player: GameRoomParticipants.display_name(participant),
          team: assignment.seats[index] + 1
        }
      end
      players = ListBox.new(
        labels,
        header: _("Players and teams"),
        index: player_index,
        quiet: true
      )
      change_button = Button.new(_("Change team"))
      automatic_button = Button.new(_("Assign automatically"))
      start_button = Button.new(_("Start game"))
      cancel_button = Button.new(_("Cancel"))
      form = Form.new(
        [players, change_button, automatic_button, start_button, cancel_button],
        quiet: true
      )
      form.accept_button = change_button
      form.cancel_button = cancel_button
      action = nil
      change_button.on(:press) do
        player_index = players.index.to_i
        action = :change
        form.resume
      end
      automatic_button.on(:press) do
        player_index = players.index.to_i
        action = :automatic
        form.resume
      end
      start_button.on(:press) do
        error = assignment.validation_error
        if error == nil
          action = :start
          form.resume
        else
          alert(error)
        end
      end
      cancel_button.on(:press) do
        action = :cancel
        form.resume
      end
      form.wait

      case action
      when :change
        selected = choose_team(assignment, assignment.seats[player_index])
        assignment.assign(player_index, selected) if selected != nil
      when :automatic
        assignment.reset
      when :start
        return game.with_team_assignment(options, players: participants, seats: assignment.seats)
      when :cancel
        return nil
      end
    end
  end

  def choose_team(assignment, current)
    teams = ListBox.new(
      Array.new(assignment.team_count) { |index| _("Team %{team}") % { team: index + 1 } },
      header: _("Choose a team"),
      index: current.to_i,
      quiet: true
    )
    select_button = Button.new(_("Select"))
    cancel_button = Button.new(_("Cancel"))
    form = Form.new([teams, select_button, cancel_button], quiet: true)
    form.accept_button = select_button
    form.cancel_button = cancel_button
    selected = nil
    select_button.on(:press) do
      selected = teams.index.to_i
      form.resume
    end
    cancel_button.on(:press) { form.resume }
    form.wait
    selected
  end

  def same_participant_order?(first, second)
    left = GameRoomParticipants.unique(first)
    right = GameRoomParticipants.unique(second)
    left.length == right.length && left.each_with_index.all? do |participant, index|
      GameRoomParticipants.same?(participant, right[index])
    end
  end

  def load_room_state(row, title:, synchronizer: nil, ui: nil)
    payload = run_network_task(title, ui: ui) do
      operation = lambda do
        room = @lobby.snapshot_for(row)
        if room == nil
          [nil, nil, []]
        else
          session = @games.session_for_table(room.table)
          [
            room,
            session == nil ? nil : @games.snapshot_for(session),
            @table_activity.entries_for(room.table, viewer: Session.name)
          ]
        end
      end
      synchronizer == nil ? operation.call : synchronizer.synchronize(&operation)
    end
    return nil if payload == nil || payload[0] == nil

    room, game_snapshot, activity_entries = payload
    game = game_snapshot == nil ? game_definition(room.table["game"]) : game_definition(game_snapshot.session["game"])
    replay = if game == nil || game_snapshot == nil
      nil
    else
      game.replay(game_snapshot.session, game_snapshot.events, @games)
    end
    players = game_snapshot == nil ? [] : @games.players_for(game_snapshot.session)
    GameRoomLifecycle::State.new(
      room: room,
      game_snapshot: game_snapshot,
      game: game,
      replay: replay,
      players: players,
      activity_entries: activity_entries
    )
  end

  def run_game_screen(session, game = nil, table:)
    game ||= game_definition(session["game"])
    if game == nil
      alert(_("This game is not supported by this version of ELTEN Game Room."))
      return
    end

    options_error = game.validation_error(game.options_from_json(session["options"]))
    if options_error != nil
      alert(options_error)
      return
    end

    synchronizer = GameRoomSync::Controller.new(
      transport: @transport,
      table_id: @lobby.table_id(table),
      session_id: @games.session_id(session),
      reconnect: -> { activate_table_transport(table) }
    )
    synchronizer.update_session(@games.session_id(session), discard_pending: true)
    GameScreen.new(
      program: self,
      repository: @games,
      game: game,
      session: session,
      table: table,
      table_owner: @lobby.owner_of(table),
      room_snapshot_provider: -> { @lobby.snapshot_for(table) },
      synchronizer: synchronizer,
      invite_online: ->(current_table) { show_invite_users(current_table, source: :online) },
      invite_contacts: ->(current_table) { show_invite_users(current_table, source: :contacts) },
      membership_tracker: room_membership_tracker(table),
      game_status_changed: ->(current_table, active) { @lobby.set_game_active(current_table, active) },
      activity_repository: @table_activity,
      game_name: ->(id) { game_name(id) },
      send_chat: ->(current_table, message, users) do
        saved = @table_activity.append(table: current_table, kind: "chat", message: message)
        @lobby.announce_table_activity(current_table, users, actor: Session.name) if saved != nil
        saved
      end,
      layout: @table_layouts&.[](@lobby.table_id(table)),
      manage_computer: ->(current_table, action, participant) { change_room_computer(current_table, action, participant) },
      manage_observer: ->(current_table, action) { change_observer_mode(current_table, action) }
    ).run
  end

  def play_game_sound(name)
    GameRoomSounds.play(self, name)
  end

  def play_game_sounds(names)
    GameRoomSounds.play_all(self, names)
  end

  def room_membership_tracker(row)
    @room_membership_trackers ||= {}
    @room_membership_trackers[@lobby.table_id(row)] ||= GameRoomSounds::MembershipTracker.new
  end

  def forget_room_membership(row)
    @room_membership_trackers&.delete(@lobby.table_id(row))
  end

  def valid_player_count?(game, count)
    return false if game == nil

    minimum = [game.minimum_players.to_i, 1].max
    maximum = [game.maximum_players.to_i, minimum].max
    count.to_i.between?(minimum, maximum)
  end

  def invalid_player_count_message(game, current_count)
    return _("This game is not supported by this version of ELTEN Game Room.") if game == nil

    minimum = [game.minimum_players.to_i, 1].max
    maximum = [game.maximum_players.to_i, minimum].max
    if minimum == maximum
      _("This game requires exactly %{required} players. There are currently %{current} users at the table.") % {
        required: minimum,
        current: current_count.to_i
      }
    else
      _("This game requires from %{minimum} to %{maximum} players. There are currently %{current} users at the table.") % {
        minimum: minimum,
        maximum: maximum,
        current: current_count.to_i
      }
    end
  end

  def bounded_index(index, items)
    return 0 if items.empty?

    [[index.to_i, 0].max, items.length - 1].min
  end

  def game_definition(game_id)
    GAME_REGISTRY.build(game_id)
  end

  def game_name(game_id)
    GAME_REGISTRY.name(game_id) || game_id.to_s
  end

  def default_table_name
    _("%{user}'s table") % { user: Session.name.to_s }
  end
end
