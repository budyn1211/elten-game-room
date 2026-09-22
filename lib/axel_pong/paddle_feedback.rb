require_relative 'keyboard'

module GameRoomPong
  # Presentation only for a human whose authoritative engine runs elsewhere
  # (a match containing bots). Consume the already computed mouse/keyboard
  # frame, without simulating another ball or modifying the outgoing input.
  class PaddleFeedback
    attr_reader :position

    def initialize; reset; end

    def reset
      @keyboard = KeyboardMovement.new
      @position = nil
      @pointer_sequence = @edges = 0
    end

    def suspend(input = {})
      @position = nil
      @keyboard.sync(input)
    end

    def step(input, position:, &effect)
      @position ||= position
      if input['paddle'].is_a?(Numeric)
        @keyboard.sync(input)
        if input['pointer_seq'].to_i > @pointer_sequence
          @pointer_sequence = input['pointer_seq']
          @position = input['pointer_start'] if input['pointer_start'].is_a?(Numeric)
          # Preserve opposite DOWN edges, even when their final position is
          # unchanged. Mouse displacement follows keyboard displacement.
          Array(input['pointer_keys']).each { |direction| move(@position + direction, &effect) }
          move(input['pointer_before'], &effect) if input['pointer_before'].is_a?(Numeric)
          move(input['paddle'], &effect)
          edges = input.fetch('pointer_edges', 0)
          effect.call('edge', @position) if edges > @edges
          @edges = edges
        else
          move(input['paddle'], &effect)
        end
      else
        # Keyboard audio must also work if native mouse capture is unavailable.
        directions = @keyboard.step(input)
        # Unlike absolute pointer targets, held keys are timed by the owner.
        # Reconcile silently at rest instead of retaining a positional drift.
        @position = position if directions.empty? && input.fetch('move', 0).to_i.zero?
        directions.each { |direction| move(@position + direction, &effect) }
      end
    end

    private

    def move(wanted)
      previous = @position
      @position = wanted.clamp(1.0, 29.0)
      if @position != previous
        yield 'step', @position
      elsif wanted != previous
        yield 'edge', @position
      end
    end
  end
end
