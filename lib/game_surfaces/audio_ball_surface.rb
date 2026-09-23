require_relative '../audio_ball/keyboard'

require_relative "../game_room_localization"

module GameSurfaces
  using GameRoomLocalization::Translations
  AudioBallSpec = Struct.new(:game_id, :header, :players, :viewer, :scores, :sets, :set_number, :finished, keyword_init: true)

  class AudioBallField < Button
    KEYS = GameRoomAudioBall::Keyboard::KEYS

    def initialize(label)
      super(label)
      GameRoomAudioBall::Keyboard.install
      @pending, @blocked, @down = [], [], []
    end

    def update
      super
      down = KEYS.keys.select { |code| key_held?(code) }
      @blocked &= down
      if GameRoomAudioBall::Keyboard::MODIFIERS.any? { |code| key_held?(code) }
        @blocked |= down
      else
        candidates = KEYS.keys.select { |code| !@blocked.include?(code) && !@down.include?(code) && key_pressed?(code) }
        frame = GameRoomAudioBall::Keyboard.frame if respond_to?(:keyboard_modifier_held_when_pressed?, true)
        if frame == nil || (candidates - frame.map(&:first)).any?
          presses = candidates.length == 1 ? [[candidates.first, nil]] : []
        else
          presses = frame.equal?(@last_native_frame) ? [] : frame
        end
        presses.each do |code, modified|
          modified = modified_when_pressed?(code) if modified == nil
          @pending << KEYS.fetch(code) if @pending.length < 32 && candidates.include?(code) && !modified
        end
      end
      @last_native_frame = GameRoomAudioBall::Keyboard.frame
      @down = down
    end

    def modified_when_pressed?(code)
      return false unless respond_to?(:keyboard_modifier_held_when_pressed?, true)
      [:shift, :control, :option, :command].any? { |modifier| keyboard_modifier_held_when_pressed?(code, modifier) }
    end

    def take_input
      pending, @pending = @pending, []
      pending
    end

    def clear_input
      @pending.clear
      @blocked = KEYS.keys.select { |code| key_held?(code) }
      @down = @blocked.dup
      @last_native_frame = GameRoomAudioBall::Keyboard.frame
    end

    def focus(*args, **options)
      clear_input
      super
    end

    def blur
      @pending.clear
      super if defined?(super)
    end

    def key_processed(key)
      return true if %w[up left down right w d s a].include?(key.to_s.sub(/\Akey_/, ''))
      super
    end
  end

  class AudioBallSurface
    include ActionEmitter
    attr_reader :spec, :snapshot
    attr_accessor :on_audio_ball_command

    def _(source); GameRoomContent.utf8(super(source)); end

    def initialize(spec, state: {})
      @spec = spec
      @field = AudioBallField.new(spec.header)
      @field.add_tip(_('Up arrow: choose a defence against the first shot type, or play that shot after preparing.'))
      @field.add_tip(_('W: choose a defence against the first shot type, or play that shot after preparing.'))
      @field.add_tip(_('Left arrow: choose a defence against the second shot type, or play that shot after preparing.'))
      @field.add_tip(_('D: choose a defence against the second shot type, or play that shot after preparing.'))
      @field.add_tip(_('Down arrow: choose a defence against the third shot type, or play that shot after preparing.'))
      @field.add_tip(_('S: choose a defence against the third shot type, or play that shot after preparing.'))
      @field.add_tip(_('Right arrow: prepare a shot while holding the ball before a serve or after a defence.'))
      @field.add_tip(_('A: prepare a shot while holding the ball before a serve or after a defence.'))
      @status = _('Connecting the match.')
    end

    def fields; [@field]; end
    def state; {}; end
    def reusable_for?(spec); spec.is_a?(AudioBallSpec) && spec.game_id == @spec.game_id; end
    def update_spec(spec); @spec = spec; self; end
    def present(snapshot, status); @snapshot, @status = snapshot, status; end

    def handle_command(command, _payload = {})
      case command
      when 'hurry'
        @on_audio_ball_command&.call(command)
      when 'scores'
        speak(@spec.players.each_with_index.map do |player, side|
          _('%{player}. Points: %{points}. Sets: %{sets}.') % {
            player: GameRoomContent.utf8(player), points: @spec.scores[side], sets: @spec.sets[side] }
        end.join(' '))
      when 'server'
        server = @snapshot && @snapshot['server']
        text = [0, 1].include?(server) ? (_('%{player} serves.') % { player: GameRoomContent.utf8(@spec.players[server]) }) : ''
        speak([text, @status].reject(&:empty?).join(' '))
      else
        return false
      end
      true
    end

    def input_active?(form)
      active = form.fields[form.index] == @field
      active &&= $activecontrols.include?(@field) if defined?($activecontrols) && $activecontrols.is_a?(Array)
      active && @spec.viewer != nil && !@spec.finished
    end

    def input(form)
      actions = @field.take_input
      input_active?(form) ? actions : []
    end

    def clear_input
      @field.clear_input
    end
  end
end
