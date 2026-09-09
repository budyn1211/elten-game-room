require_relative "game_participants"
require_relative "game_rules"

# One native global menu for the waiting room, active game and final-position
# view. Only Delete remains local to the selected row in the users list.
module GameRoomParticipantMenu
  module_function

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
      entries = [
        [:invite_online, _("Invite an online Elten user"), "i"],
        [:invite_contacts, _("Invite someone from your contacts"), "I"],
        [:add_bot, _("Add a computer"), "o"],
        [:rules, _("Game rules"), ""],
        [:leave, _("Leave"), ""]
      ]
      entries.each do |action, label, key|
        next if !actions.include?(action)

        menu.option(label, nil, key) do
          dispatch.call(action, nil) if available.call.include?(action)
        end
      end
    end

    GameRoomRules.bind_ctrl_f1(layout.form, layout.shortcut_fields) do
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
end
