module GameRoomPong
  # Audio-mode HandleInput: left DOWN, right DOWN, then held-key repeat.
  # Held-left wins a tie, but that must not discard a new right DOWN edge.
  class KeyboardMovement
    COUNTERS = %w[left_press right_press].freeze

    def initialize
      @counts = [0, 0]
      reset_repeat
    end

    def reset_repeat
      @direction = @tick = 0
    end

    def sync(input)
      COUNTERS.each_with_index { |key, i| @counts[i] = input[key] if input[key].is_a?(Integer) }
      reset_repeat
    end

    def step(input)
      direction = [-1, 0, 1].include?(input['move']) ? input['move'] : 0
      steps = []
      if COUNTERS.all? { |key| input[key].is_a?(Integer) }
        COUNTERS.each_with_index do |key, i|
          count = input[key]
          fresh = count >= @counts[i] ? count > @counts[i] : count > 0
          steps << (i.zero? ? -1 : 1) if fresh
          @counts[i] = count
        end
      elsif direction != @direction && !direction.zero?
        # Older/synthetic inputs have only the held direction.
        steps << direction
      end
      @tick = 0 if direction != @direction
      @direction = direction
      unless direction.zero?
        @tick += 1
        steps << direction if @tick > 4 && (@tick - 4) % 3 == 0
      end
      steps
    end
  end
end
