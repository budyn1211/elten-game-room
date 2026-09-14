require_relative "context_help"

module GameRoomScreens
  MenuResult = Struct.new(:action, :index, keyword_init: true)

  class MainMenu
    def initialize(options:, history_items: [], index: 0, invitations: false, refresh: nil)
      @options = options
      @history_items = history_items.to_a.map(&:to_s)
      @index = index.to_i
      @invitations = invitations == true
      @refresh = refresh
    end

    def wait
      action = nil
      options = ListBox.new(
        @options,
        header: _("ELTEN Game Room"),
        index: @index,
        quiet: true
      )
      history = ListBox.new(
        @history_items,
        header: _("Game Room history"),
        index: [@history_items.length - 1, 0].max,
        quiet: true,
        empty_label: _("No Game Room events yet")
      )
      open_button = Button.new(_("Open"))
      exit_button = Button.new(_("Exit"))
      form = Form.new([options, history, open_button, exit_button], quiet: true)
      form.accept_button = open_button
      form.cancel_button = exit_button
      form.hide(open_button)
      form.hide(exit_button)
      open_button.on(:press) do
        @index = options.index.to_i
        action = :open
        form.resume
      end
      exit_button.on(:press) do
        action = :exit
        form.resume
      end
      if @invitations
        invitation_entries = [
          [:invitations, _("Accept invitation"), "j", "Ctrl+J"],
          [:reject_invitation, _("Reject invitation"), "J", "Ctrl+Shift+J"]
        ]
        options.disable_contextinglobal
        options.bind_context do |menu|
          invitation_entries.each do |requested, label, key, _help_key|
            menu.option(label, nil, key) do
              next if action != nil

              @index = options.index.to_i
              action = requested
              form.resume
            end
          end
        end
        help_tips = invitation_entries.map do |_requested, label, _key, help_key|
          _("Press %{key} for %{action}.") % { key: help_key, action: label }
        end
        GameRoomContextHelp.replace([options, history], help_tips)
      end
      if @refresh != nil
        form.add_timer(FormTimer.new(0.5, repeat: true) do
          changed = if @refresh.arity == 0
            @refresh.call
          elsif @refresh.arity == 1
            @refresh.call(form)
          else
            @refresh.call(form, history)
          end
          next if action != nil || !changed

          @index = options.index.to_i
          action = :refresh
          form.resume
        end)
      end
      form.wait
      MenuResult.new(action: action, index: @index)
    end
  end

  class Settings
    INVITATION_POLICIES = %w[contacts nobody everyone].freeze

    def initialize(values, games:)
      @values = values.to_h
      @games = games.to_a
    end

    def wait
      action = nil
      sections = ListBox.new(
        [_("Lobby messages"), _("Notification settings"), _("Sounds"), _("Widget")],
        header: _("Settings"), quiet: true
      )
      lobby_games = multiple_game_list(_("Games covered by lobby messages"), @values["lobby_games"])
      created = CheckBox.new(
        _("Announce when a table is created"),
        checked: setting_enabled?("announce_table_created")
      )
      joined = CheckBox.new(
        _("Announce when a player joins a table"),
        checked: setting_enabled?("announce_player_joined")
      )
      left = CheckBox.new(
        _("Announce when a player leaves a table"),
        checked: setting_enabled?("announce_player_left")
      )
      computers = CheckBox.new(
        _("Announce when a computer is added or removed"),
        checked: setting_enabled?("announce_computer_changes")
      )
      invitation_policy = ListBox.new(
        [_("From contacts"), _("From nobody"), _("From everyone")],
        header: _("Show invitation notifications from"),
        index: [INVITATION_POLICIES.index(@values["invitation_notifications"].to_s).to_i, 0].max,
        quiet: true
      )
      game_sounds = CheckBox.new(
        _("Game sounds"), checked: setting_enabled?("game_sounds")
      )
      room_sounds = CheckBox.new(
        _("Sounds when someone enters or leaves a room"),
        checked: setting_enabled?("room_membership_sounds")
      )
      chat_sounds = CheckBox.new(
        _("Chat sounds"), checked: setting_enabled?("chat_sounds")
      )
      invitation_sounds = CheckBox.new(
        _("Invitation and Game Room notification sounds"),
        checked: setting_enabled?("invitation_sounds")
      )
      widget_enabled = CheckBox.new(
        _("Show Game Room on the ELTEN main screen"),
        checked: setting_enabled?("widget_enabled")
      )
      widget_games = multiple_game_list(_("Games shown on the main screen"), @values["widget_games"])
      widget_unavailable = CheckBox.new(
        _("Show full or unavailable tables"),
        checked: setting_enabled?("widget_show_unavailable")
      )
      save_button = Button.new(_("Save"))
      cancel_button = Button.new(_("Cancel"))

      groups = [
        [lobby_games, created, joined, left, computers],
        [invitation_policy],
        [game_sounds, room_sounds, chat_sounds, invitation_sounds],
        [widget_enabled, widget_games, widget_unavailable]
      ]
      form = Form.new([sections] + groups.flatten + [save_button, cancel_button], quiet: true)
      form.accept_button = save_button
      form.cancel_button = cancel_button
      refresh_section = lambda do
        groups.flatten.each { |control| form.hide(control) }
        groups[sections.index.to_i].to_a.each { |control| form.show(control) }
      end
      sections.on(:move) { refresh_section.call }
      refresh_section.call
      save_button.on(:press) do
        action = :save
        form.resume
      end
      cancel_button.on(:press) { form.resume }
      form.wait
      return nil if action != :save

      {
        "lobby_games" => selected_game_ids(lobby_games),
        "announce_table_created" => created.checked,
        "announce_player_joined" => joined.checked,
        "announce_player_left" => left.checked,
        "announce_computer_changes" => computers.checked,
        "announce_lobby_changes" => [created, joined, left, computers].any?(&:checked),
        "invitation_notifications" => INVITATION_POLICIES[invitation_policy.index.to_i] || "everyone",
        "game_sounds" => game_sounds.checked,
        "room_membership_sounds" => room_sounds.checked,
        "chat_sounds" => chat_sounds.checked,
        "invitation_sounds" => invitation_sounds.checked,
        "widget_enabled" => widget_enabled.checked,
        "widget_games" => selected_game_ids(widget_games),
        "widget_show_unavailable" => widget_unavailable.checked
      }
    end

    private

    def multiple_game_list(header, selected)
      control = ListBox.new(
        @games.map { |game| game.fetch(:name).to_s },
        header: header,
        flags: ListBox::Flags::MultiSelection,
        quiet: true
      )
      wanted = selected.to_a.map(&:to_s)
      control.select_multiselection_indices(
        @games.each_index.select { |index| wanted.include?(@games[index].fetch(:id).to_s) }
      )
      control
    end

    def selected_game_ids(control)
      control.multiselections.filter_map { |index| @games[index]&.fetch(:id)&.to_s }
    end

    def setting_enabled?(key)
      @values[key] != false
    end
  end

  class GameRules
    def initialize(book)
      @book = book
      @documents = book.documents
      @section_index = 0
    end

    def wait
      loop do
        action = nil
        sections = ListBox.new(
          @documents.map(&:title),
          header: _("%{game} rules") % { game: @book.title },
          index: bounded_index(@section_index, @documents),
          quiet: true
        )
        open_button = Button.new(_("Open"))
        back_button = Button.new(_("Back"))
        form = Form.new([sections, open_button, back_button], quiet: true)
        form.accept_button = open_button
        form.cancel_button = back_button
        form.hide(open_button)
        form.hide(back_button)
        open_button.on(:press) do
          @section_index = sections.index.to_i
          action = :open
          form.resume
        end
        back_button.on(:press) do
          action = :back
          form.resume
        end
        form.wait
        return if action == :back

        show_section(@documents[@section_index]) if action == :open
      end
    end

    private

    def show_section(section)
      content = EditBox.new(
        _("%{game}: %{section}") % { game: @book.title, section: section.title },
        type: EditBox::Flags::ReadOnly | EditBox::Flags::MultiLine,
        text: section.text,
        quiet: true
      )
      back_button = Button.new(_("Back"))
      form = Form.new([content, back_button], quiet: true)
      form.cancel_button = back_button
      form.hide(back_button)
      back_button.on(:press) { form.resume }
      form.wait
    end

    def bounded_index(index, items)
      return 0 if items.empty?

      [[index.to_i, 0].max, items.length - 1].min
    end
  end
end
