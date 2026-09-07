require_relative "invitation_shortcuts"

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
      GameRoomInvitationShortcuts.bind(
        form,
        [options, history],
        invite_online: (@invitations ? -> do
          action = :invite_online
          form.resume
        end : nil),
        invite_contacts: (@invitations ? -> do
          action = :invite_contacts
          form.resume
        end : nil),
        accept: (@invitations ? -> do
          action = :invitations
          form.resume
        end : nil),
        reject: (@invitations ? -> do
          action = :reject_invitation
          form.resume
        end : nil)
      )
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
    def initialize(values)
      @values = values.to_h
    end

    def wait
      action = nil
      sections = ListBox.new([_("Lobby announcements")], header: _("Settings"), quiet: true)
      open_button = Button.new(_("Open"))
      back_button = Button.new(_("Back"))
      form = Form.new([sections, open_button, back_button], quiet: true)
      form.accept_button = open_button
      form.cancel_button = back_button
      form.hide(open_button)
      form.hide(back_button)
      open_button.on(:press) do
        action = :lobby
        form.resume
      end
      back_button.on(:press) do
        action = :back
        form.resume
      end
      form.wait
      return nil if action != :lobby

      updated = lobby_announcements
      updated == nil ? nil : @values.merge(updated)
    end

    private

    def lobby_announcements
      legacy = @values["announce_lobby_changes"] != false
      created = CheckBox.new(
        _("Announce when a table is created"),
        checked: setting_enabled?("announce_table_created", legacy)
      )
      joined = CheckBox.new(
        _("Announce when a player joins a table"),
        checked: setting_enabled?("announce_player_joined", legacy)
      )
      left = CheckBox.new(
        _("Announce when a player leaves a table"),
        checked: setting_enabled?("announce_player_left", legacy)
      )
      computers = CheckBox.new(
        _("Announce when a computer is added or removed"),
        checked: setting_enabled?("announce_computer_changes", legacy)
      )
      save_button = Button.new(_("Save"))
      cancel_button = Button.new(_("Cancel"))
      form = Form.new([created, joined, left, computers, save_button, cancel_button], quiet: true)
      form.accept_button = save_button
      form.cancel_button = cancel_button
      action = nil
      save_button.on(:press) do
        action = :save
        form.resume
      end
      cancel_button.on(:press) { form.resume }
      form.wait
      return nil if action != :save

      {
        "announce_table_created" => created.checked,
        "announce_player_joined" => joined.checked,
        "announce_player_left" => left.checked,
        "announce_computer_changes" => computers.checked,
        "announce_lobby_changes" => [created, joined, left, computers].any?(&:checked)
      }
    end

    def setting_enabled?(key, fallback)
      @values.key?(key) ? @values[key] != false : fallback
    end
  end

  class GameRules
    def initialize(book)
      @book = book
      @section_index = 0
    end

    def wait
      loop do
        action = nil
        sections = ListBox.new(
          @book.sections.map(&:title),
          header: _("%{game} rules") % { game: @book.title },
          index: bounded_index(@section_index, @book.sections),
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

        show_section(@book.sections[@section_index]) if action == :open
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
      back_button = Button.new(_("Back to rule sections"))
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
