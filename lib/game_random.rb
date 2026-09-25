require "securerandom"

module GameRoomRandom
  # ELTEN overrides Array#shuffle with a no-argument, unseeded method.
  # Keep event replay independent of that host override. Descending
  # Fisher-Yates preserves MRI's seeded order and subsequent RNG state.
  def self.shuffle(values, random:)
    shuffled = values.to_a.dup
    (shuffled.length - 1).downto(1) do |index|
      other = random.rand(index + 1)
      shuffled[index], shuffled[other] = shuffled[other], shuffled[index]
    end
    shuffled
  end

  Roll = Struct.new(:values, :sides, :source, :proof, keyword_init: true)

  class Source
    MAX_DICE = 100
    MAX_SIDES = 1_000

    def roll(count:, sides:)
      dice_count = count.to_i
      side_count = sides.to_i
      raise ArgumentError, "dice count is outside the supported range" if !dice_count.between?(1, MAX_DICE)
      raise ArgumentError, "die sides are outside the supported range" if !side_count.between?(2, MAX_SIDES)

      values = Array.new(dice_count) do
        value = next_value(side_count).to_i
        raise RangeError, "random source returned a value outside the die range" if !value.between?(1, side_count)

        value
      end
      Roll.new(values: values, sides: side_count, source: source_name, proof: proof_for(values, side_count))
    end

    def authoritative?
      false
    end

    def source_name
      "unknown"
    end

    protected

    def next_value(_sides)
      raise NotImplementedError, "a random source must implement next_value"
    end

    def proof_for(_values, _sides)
      nil
    end
  end

  class LocalSecureSource < Source
    def source_name
      "local_secure"
    end

    protected

    def next_value(sides)
      SecureRandom.random_number(sides) + 1
    end
  end

  # A reproducible source for simulations, regression tests and training runs.
  # Duplicating it also duplicates the current generator state, which lets a
  # search branch be explored without changing the real match.
  class SeededSource < Source
    attr_reader :seed

    def initialize(seed)
      @seed = seed.to_i
      @random = Random.new(@seed)
    end

    def initialize_copy(original)
      super
      @random = original.instance_variable_get(:@random).dup
    end

    def source_name
      "seeded"
    end

    protected

    def next_value(sides)
      @random.rand(sides) + 1
    end
  end

end
