# Rule replay may project historical actions onto the current occupants of
# the same seats. Keep that local view for decision analysis, while the public
# accepted log and archive continue to retain their original authors/values.
module GameRoomParticipantDecisionEvents
  def self.attach(replay, events)
    replay.instance_variable_set(:@participant_decision_events, events)
  end

  def self.for(replay)
    replay.instance_variable_get(:@participant_decision_events) || replay.accepted_events
  end
end
