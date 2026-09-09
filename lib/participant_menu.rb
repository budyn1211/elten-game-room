require_relative "game_participants"

# One native menu for the waiting room, active game and final-position view.
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
    # Keep invitation and computer shortcuts local to the users list,
    # including when another field contributes to the global menu.
    layout.users.disable_contextinglobal
    layout.users.bind_context do |menu|
      actions = available.call
      participant = layout.selected_participant
      entries = [
        [:invite_online, _("Invite an online Elten user"), "i"],
        [:invite_contacts, _("Invite someone from your contacts"), "I"],
        [:add_bot, _("Add a computer"), "o"],
        [:remove_bot, _("Remove computer"), :del],
        [:leave, _("Leave"), ""]
      ]
      entries.each do |action, label, key|
        next if !actions.include?(action)
        next if action == :remove_bot && !GameRoomParticipants.bot?(participant)

        menu.option(label, nil, key) do
          # Keep the original row for the UI's permission/type check, even
          # if a remote update moves the selection. The repository removes
          # one numbered computer slot using its unchanged count operation.
          dispatch.call(action, participant) if available.call.include?(action)
        end
      end
    end
  end
end
