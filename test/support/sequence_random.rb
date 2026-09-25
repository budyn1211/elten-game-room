require_relative '../../lib/game_random'

module GameRoomRandom
  class SequenceSource < Source
    def initialize(values)
      @values = values.to_a.dup
    end

    def source_name
      "test_sequence"
    end

    protected

    def next_value(_sides)
      raise RangeError, "the deterministic random sequence is exhausted" if @values.empty?

      @values.shift
    end
  end
end
