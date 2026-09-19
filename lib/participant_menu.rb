require_relative "game_participants"
require_relative "game_rules"
require_relative "context_help"

# One native global menu for the waiting room, active game and final-position
# view. Only Delete remains local to the selected row in the users list.
module GameRoomParticipantMenu
  Entry = Struct.new(:action, :label, :menu_key, :help_key, keyword_init: true)

  module_function

  def entries
    [
      Entry.new(action: :invite_online, label: _("Invite an online Elten user"), menu_key: "i", help_key: "Ctrl+I"),
      Entry.new(action: :invite_contacts, label: _("Invite someone from your contacts"), menu_key: "I", help_key: "Ctrl+Shift+I"),
      Entry.new(action: :add_bot, label: _("Add a computer"), menu_key: "o", help_key: "Ctrl+O"),
      Entry.new(action: :observe_next_game, label: _("Observe the next game"), menu_key: "O", help_key: "Ctrl+Shift+O"),
      Entry.new(action: :play_next_game, label: _("Play in the next game"), menu_key: "O", help_key: "Ctrl+Shift+O"),
      Entry.new(action: :rules, label: _("Game rules"), menu_key: :ctrl_f1, help_key: "Ctrl+F1"),
      Entry.new(action: :table_options, label: _("Read the table variant and settings"), menu_key: "r", help_key: "Ctrl+R"),
      Entry.new(action: :edit_options, label: _("Change settings for the next game"), menu_key: "x", help_key: "Ctrl+X"),
      Entry.new(action: :abort_game, label: _("End the current game without closing the table"), menu_key: "q", help_key: "Ctrl+Q"),
      Entry.new(action: :save_game, label: _("Save the game and close the table"), menu_key: "s", help_key: "Ctrl+S"),
      Entry.new(action: :leave, label: _("Leave"), menu_key: "")
    ]
  end

  def management_actions(room:, game:, active:, viewer:, owner:, restoring: false)
    return [] if room == nil || active || restoring || !GameRoomParticipants.same?(viewer, owner)

    actions = []
    maximum = game == nil ? 0 : [room.table["max_players"].to_i, game.maximum_players.to_i].min
    actions << :add_bot if game&.supports_bots? && room.participants.length < maximum
    actions << :remove_bot if !room.bots.to_a.empty?
    actions
  end

  def role_actions(room:, viewer:)
    return [] if room == nil || GameRoomParticipants.bot?(viewer)
    return [] if !GameRoomParticipants.includes?(room.members, viewer)

    room.observer?(viewer) ? [:play_next_game] : [:observe_next_game]
  end

  def lifecycle_actions(active:, viewer:, owner:, restoring: false, frozen: false, compatible: true)
    return [] unless GameRoomParticipants.same?(viewer, owner)
    return [] if restoring || frozen || !compatible
    active ? [:abort_game] : [:edit_options]
  end

  def bind(layout, available:, read_options: nil, game: nil, options: nil, &dispatch)
    supplied = available
    available = -> do
      actions = supplied.call + (read_options == nil ? [] : [:table_options])
      actions -= [:invite_online, :invite_contacts] if game && !game.table_invitations_allowed?(options.to_h)
      actions -= [:observe_next_game, :play_next_game] if game && !game.role_selection_allowed?(options.to_h)
      actions
    end
    layout.form.bind_context do |menu|
      actions = available.call
      entries.each do |entry|
        next if !actions.include?(entry.action)

        # Ctrl+X belongs to the text editor while typing. The same command is
        # still available by selecting its context-menu item with the arrows.
        focused = layout.form.fields[layout.form.index.to_i]
        key = entry.action == :edit_options && focused.is_a?(EditBox) ? "" : entry.menu_key
        menu.option(entry.label, nil, key) do
          next if !available.call.include?(entry.action)

          if entry.action == :table_options
            read_options.call
          else
            dispatch.call(entry.action, nil)
          end
        end
      end
    end

    add_context_help(layout, available.call)
    GameRoomRules.bind_ctrl_f1(layout.form, []) do
      dispatch.call(:rules, nil) if available.call.include?(:rules)
    end

    layout.users.bind_context do |menu|
      actions = available.call
      participant = layout.selected_participant
      next if !actions.include?(:remove_bot) || !GameRoomParticipants.bot?(participant)

      menu.option(_("Remove computer"), nil, :del) do
        # Keep the original row for the UI's permission/type check, even if a
        # remote update moves the selection. The repository removes one
        # numbered computer slot using its unchanged count operation.
        dispatch.call(:remove_bot, participant) if available.call.include?(:remove_bot)
      end
    end
  end

  def add_context_help(layout, actions)
    tips = entries.filter_map do |entry|
      next if !actions.include?(entry.action) || entry.help_key == nil

      GameRoomContextHelp.shortcut_tip(entry.help_key, entry.label)
    end
    help_fields = layout.form.fields.reject { |field| field.equal?(layout.back_button) }
    GameRoomContextHelp.replace(help_fields, tips)
  end
end
