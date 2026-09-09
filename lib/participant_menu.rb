require_relative "game_participants"
require_relative "game_rules"

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
      Entry.new(action: :rules, label: _("Game rules"), menu_key: :ctrl_f1, help_key: "Ctrl+F1"),
      Entry.new(action: :leave, label: _("Leave"))
    ]
  end

  def management_actions(room:, game:, active:, viewer:, owner:)
    return [] if room == nil || active || !GameRoomParticipants.same?(viewer, owner)

    actions = []
    maximum = game == nil ? 0 : [room.table["max_players"].to_i, game.maximum_players.to_i].min
    actions << :add_bot if game&.supports_bots? && room.participants.length < maximum
    actions << :remove_bot if !room.bots.to_a.empty?
    actions
  end

  def bind(layout, available:, &dispatch)
    layout.form.bind_context do |menu|
      actions = available.call
      entries.each do |entry|
        next if !actions.include?(entry.action)

        menu.option(entry.label, nil, entry.menu_key) do
          dispatch.call(entry.action, nil) if available.call.include?(entry.action)
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

      _("Press %{key} for %{action}.") % { key: entry.help_key, action: entry.label }
    end
    help_fields = layout.form.fields.reject { |field| field.equal?(layout.back_button) }
    help_fields.each do |field|
      next if !field.respond_to?(:add_tip)

      existing = field.respond_to?(:get_tips) ? field.get_tips.to_a : []
      tips.each { |tip| field.add_tip(tip) if !existing.include?(tip) }
    end
  end
end
