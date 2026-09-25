require_relative 'game_participants'

# Shared event-history vocabulary of tile/round games, with game-owned assets.
module GameRoomRoundCues
  module_function

  def for_event(history, replay, viewer, assets:)
    cues = []
    %i[deal draw play].zip(assets).each do |kind, cue|
      cues << cue if history.any? { |entry| entry.kind == kind }
    end
    result = history.find { |entry| entry.kind == :round_result }
    if result && !result.actor.to_s.empty? && GameRoomParticipants.includes?(replay.players, viewer)
      winners = result.value.is_a?(Array) ? result.value : [result.actor]
      cues << (winners.any? { |player| GameRoomParticipants.same?(player, viewer) } ? 'win1' : 'lose1')
    end
    cues
  end
end
