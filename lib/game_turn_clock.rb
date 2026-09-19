# Optional clock envelope for turn-based card games. Games retain ownership
# of their phases and timeout consequences; this module only records time.
require_relative "game_session_clock"

module GameRoomTurnClock
  module_function

  def enabled?(state)
    state[:options].to_h["thinking_time"].to_i > 0
  end

  def logical_now(state, context = nil)
    now = if context && context.now != nil
      context.now.to_i
    else
      GameRoomSessionClock.for_state(state).to_i
    end
    # Sending a new action cannot precede the accepted state on which it is
    # based. Keep strict turn/revision/time validation on received events.
    [now, state[:turn_started].to_i, state[:time].to_i].max
  end

  def encode(state, value, context = nil)
    return value unless enabled?(state)
    "#{value}~#{state[:turn_number].to_i.to_s(36)}:#{logical_now(state, context).to_s(36)}"
  end

  # Preserve the original wire event in accepted_events. Only the rule engine
  # sees the payload with its clock envelope removed.
  def decode(state, event)
    return [event, nil] unless enabled?(state)
    value, separator, clock = event["value"].to_s.rpartition("~")
    parts = clock.split(":", -1)
    return nil if separator.empty? || parts.length != 2 || parts.any? { |part| !/\A[0-9a-z]+\z/.match?(part) }
    turn, time = parts.map { |part| part.to_i(36) }
    return nil unless turn == state[:turn_number].to_i && time >= state[:turn_started].to_i
    [event.merge("value" => value), time]
  end

  def payload(state, event)
    enabled?(state) ? event["value"].to_s.rpartition("~").first : event["value"].to_s
  end

  def expired?(state, now)
    enabled?(state) && now != nil && state[:turn_deadline].to_i > 0 && now.to_i >= state[:turn_deadline]
  end

  def advance(state, time, running:)
    return unless enabled?(state) && time != nil
    state[:turn_number] = state[:turn_number].to_i + 1
    state[:turn_started] = time
    state[:turn_deadline] = running ? time + state[:options]["thinking_time"].to_i : 0
  end

  def attach_session(state, session)
    return unless enabled?(state)
    GameRoomSessionClock.attach(state, session)
  end
end
