module GameRoomPong
  module AudioExtras
    ECHO_ASSETS = %w[pong_echo_noise_left pong_echo_noise_right pong_echo_tone_left pong_echo_tone_right].freeze
    # Both original distributions omit Sounds/Crowd. Fill this and the manifest
    # together only when recordings are available; do not advertise a dead switch.
    CROWD_ASSETS = [].freeze
    LOOP_ASSETS = (ECHO_ASSETS.first(2) + %w[pong_crowd_loop pong_crowd_chant]).freeze
    attr_reader :echo, :crowd

    def cycle_echo
      @echo = %w[off noise tone][(%w[off noise tone].index(@echo) + 1) % 3]
      @echo_at = 0.0
      ECHO_ASSETS.each { |name| @sounds[name]&.pause }
      @echo
    end

    def toggle_crowd
      return false unless @sounds['pong_crowd_loop'] && @sounds['pong_crowd_chant']
      @crowd = !@crowd
      @sounds.each { |name, sound| sound.pause if name.start_with?('pong_crowd_') } unless @crowd
      true
    end

    private

    def update_echo(paddle)
      return if @echo == 'off'
      return if @echo == 'tone' && @clock.call < @echo_at.to_f
      [-1, 1].each_with_index do |direction, side|
        edge = direction.negative? ? 1.0 : 29.0
        distance = (paddle - edge).abs
        pan = panorama(distance * direction)
        volume = [30.0 - distance * 2, 0].max / 100
        name = "pong_echo_#{@echo}_#{side.zero? ? 'left' : 'right'}"
        if @echo == 'noise'
          loop_sound(name, pan: pan, level: volume)
        else
          play_sound(name, pan: pan, level: volume)
        end
      end
      # Complete a 150 ms pulse instead of cutting it at every 16 ms frame.
      @echo_at = @clock.call + 0.15 if @echo == 'tone'
    end

    def crowd_reset
      @chant_level = 0.0
      @sounds['pong_crowd_chant']&.pause
    end

    def update_crowd(paused)
      return unless @crowd
      loop_sound('pong_crowd_loop', level: paused ? 0 : 1.0)
      loop_sound('pong_crowd_chant', level: paused ? 0 : @chant_level)
    end

    def crowd_event(action)
      return unless @crowd
      case action
      when 'chant' then @chant_level = 0.1
      when 'increase'
        @chant_level = [@chant_level + 0.05, 1.0].min
        play_sound("pong_crowd_ok#{@rng.rand(2) + 1}") if @chant_level > 0.4
      when 'cheer' then play_sound("pong_crowd_cheer#{@rng.rand(5) + 1}")
      when 'epicfail' then play_sound("pong_crowd_epicfail#{@rng.rand(2) + 1}")
      when 'won', 'lost' then play_sound("pong_crowd_#{action}")
      end
    end
  end
end
