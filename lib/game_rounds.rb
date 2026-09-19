require_relative "game_room_clock"
module GameRoomRounds
  PhaseDefinition = Struct.new(
    :id,
    :label,
    :allowed_actions,
    :duration,
    :terminal,
    keyword_init: true
  )

  PhaseState = Struct.new(
    :id,
    :round,
    :started_at,
    :deadline,
    :metadata,
    keyword_init: true
  ) do
    def expired?(now = GameRoomClock.now.to_i)
      deadline.to_i > 0 && now.to_i >= deadline.to_i
    end

    def remaining_seconds(now = GameRoomClock.now.to_i)
      return nil if deadline.to_i <= 0

      [deadline.to_i - now.to_i, 0].max
    end
  end

  class PhaseFlow
    attr_reader :initial_id

    def initialize(definitions, transitions: nil, initial: nil)
      @definitions = {}
      definitions.to_a.each do |definition|
        id = definition.id.to_s
        raise ArgumentError, "phase ids must not be empty" if id.empty?
        raise ArgumentError, "phase ids must be unique" if @definitions.key?(id)

        @definitions[id] = definition
      end
      raise ArgumentError, "a phase flow requires phases" if @definitions.empty?

      @initial_id = (initial || @definitions.keys.first).to_s
      raise ArgumentError, "the initial phase is not defined" if !@definitions.key?(@initial_id)
      @transitions = build_transitions(transitions)
    end

    def start(round: 1, now: GameRoomClock.now.to_i, metadata: {})
      build_state(@initial_id, round: round, now: now, metadata: metadata)
    end

    def transition(state, target, now: GameRoomClock.now.to_i, metadata: nil)
      from = state.id.to_s
      destination = target.to_s
      raise ArgumentError, "the current phase is not defined" if !@definitions.key?(from)
      raise ArgumentError, "the target phase is not defined" if !@definitions.key?(destination)
      if !@transitions.fetch(from, []).include?(destination)
        raise ArgumentError, "transition from #{from} to #{destination} is not allowed"
      end

      build_state(
        destination,
        round: state.round.to_i,
        now: now,
        metadata: metadata == nil ? state.metadata.to_h : metadata
      )
    end

    def definition(state_or_id)
      id = state_or_id.respond_to?(:id) ? state_or_id.id : state_or_id
      @definitions[id.to_s]
    end

    def allowed_action?(state_or_id, action)
      phase = definition(state_or_id)
      return false if phase == nil

      allowed = phase.allowed_actions.to_a.map(&:to_s)
      allowed.include?("*") || allowed.include?(action.to_s)
    end

    def terminal?(state_or_id)
      phase = definition(state_or_id)
      phase != nil && phase.terminal == true
    end

    def next_phases(state_or_id)
      id = state_or_id.respond_to?(:id) ? state_or_id.id : state_or_id
      @transitions.fetch(id.to_s, []).dup
    end

    private

    def build_transitions(transitions)
      source = transitions
      if source == nil
        ids = @definitions.keys
        source = {}
        ids.each_with_index { |id, index| source[id] = index + 1 < ids.length ? [ids[index + 1]] : [] }
      end
      result = {}
      @definitions.each_key do |id|
        targets = source[id] || source[id.to_sym] || []
        normalized = targets.to_a.map(&:to_s).uniq
        unknown = normalized.reject { |target| @definitions.key?(target) }
        raise ArgumentError, "phase transition references unknown phases: #{unknown.join(', ')}" if unknown.any?

        result[id] = normalized
      end
      result
    end

    def build_state(id, round:, now:, metadata:)
      definition = @definitions.fetch(id.to_s)
      duration = definition.duration.to_i
      PhaseState.new(
        id: id.to_s,
        round: [round.to_i, 1].max,
        started_at: now.to_i,
        deadline: duration > 0 ? now.to_i + duration : nil,
        metadata: metadata.to_h
      )
    end
  end
end
