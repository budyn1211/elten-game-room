module GameRoomAudioBall
  module Keyboard
    KEYS = {0x26 => 'up', 0x57 => 'up', 0x25 => 'left', 0x44 => 'left',
      0x28 => 'down', 0x53 => 'down', 0x27 => 'prepare', 0x41 => 'prepare'}.freeze
    MODIFIERS = [0x10, 0x11, 0x12, 0x5B, 0x5C, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5].freeze
    FRAME = :@game_room_audio_ball_presses
    MAX_PRESSES = 32

    module_function

    def install
      return unless defined?(EltenAPI::KeyboardState)
      target = EltenAPI::KeyboardState.singleton_class
      return if target.instance_variable_get(:@game_room_audio_ball_keyboard_bridge)

      observer = self
      bridge = Module.new do
        define_method(:update) do |*args, **options, &block|
          modifiers = MODIFIERS.each_with_object({}) { |key, held| held[key] = held?(key) }
          result = super(*args, **options, &block)
          observer.capture(result, options[:events], modifiers)
          result
        end
      end
      target.prepend(bridge)
      target.instance_variable_set(:@game_room_audio_ball_keyboard_bridge, true)
    end

    def capture(result, events, modifiers)
      return if result.frozen? || !result.respond_to?(:pressed) || !events.is_a?(Array)
      return if defined?(EltenWindow) && EltenWindow.respond_to?(:keyboard_flags_driven?) && EltenWindow.keyboard_flags_driven?

      presses = []
      events.each do |code, state, press_state|
        code = code.to_i
        modifiers[code] = [true, :repeat, :held].include?(state) if MODIFIERS.include?(code)
        next unless KEYS.key?(code) && state == true && result.pressed[code] == true
        modified = if press_state != nil
          MODIFIERS.any? { |key| (press_state.to_s.getbyte(key).to_i & 0x80) != 0 }
        else
          modifiers.value?(true)
        end
        presses.shift if presses.length == MAX_PRESSES
        presses << [code, modified].freeze
      end
      result.instance_variable_set(FRAME, presses.freeze)
    rescue StandardError
      nil
    end

    def frame
      return unless defined?(EltenAPI::KeyboardState)
      EltenAPI::KeyboardState.current.instance_variable_get(FRAME)
    end
  end
end
