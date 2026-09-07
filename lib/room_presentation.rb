require_relative "game_participants"

module RoomPresentation
  module_function

  def user_labels(members, bots: [], owner:, players:, active:, team_assignment: nil, statuses: {})
    participants = GameRoomParticipants.unique(members.to_a + bots.to_a + players.to_a)
    participants.map do |participant|
      roles = []
      roles << _("table master") if GameRoomParticipants.human?(participant) && same_user?(participant, owner)
      roles << _("computer") if GameRoomParticipants.bot?(participant)
      if active
        roles << (includes_user?(players, participant) ? _("player") : _("observer"))
      else
        roles << _("waiting for a game")
      end
      team = team_assignment&.team_number_for(participant)
      roles << _("team %{team}") % { team: team } if team != nil
      status = participant_status(statuses, participant)
      roles << status if !status.to_s.empty?
      _("%{user}, %{roles}") % {
        user: GameRoomParticipants.display_name(participant),
        roles: roles.join(", ")
      }
    end
  end

  def includes_user?(users, user)
    users.to_a.any? { |candidate| same_user?(candidate, user) }
  end

  def same_user?(first, second)
    GameRoomParticipants.same?(first, second)
  end

  def participant_status(statuses, participant)
    return nil if !statuses.respond_to?(:each)

    pair = statuses.find { |candidate, _value| same_user?(candidate, participant) }
    pair == nil ? nil : pair[1].to_s
  end
end
