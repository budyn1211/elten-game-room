class GameRoomAudioTutorial
  Entry = Struct.new(:label, :asset, keyword_init: true) do
    def initialize(label:, asset:)
      super(label: GameRoomContent.utf8(label), asset: asset.to_s)
    end
  end

  def initialize(entries, program:)
    @entries = entries
    @program = program
  end

  def wait
    return if @entries.empty?

    list = ListBox.new(@entries.map(&:label), header: GameRoomContent.utf8(_("Audio tutorial")), quiet: true)
    list.on(:select) { play(@entries[list.index]) }
    list.on(:key_space) { play(@entries[list.index]) if list.send(:key_first_pressed?, :key_space) }
    list.on(:move) { stop }
    GameRoomContextHelp.replace([list], [
      GameRoomContextHelp.shortcut_tip('Enter', _("Play the selected sound")),
      GameRoomContextHelp.shortcut_tip('Space', _("Play the selected sound")),
      GameRoomContextHelp.shortcut_tip('Escape', _("Return to game rules"))
    ])
    form = GameRoomUI::Form.new([list], program: @program, quiet: false)
    form.on(:key_escape) { form.resume }
    speak(GameRoomContent.utf8(_("Welcome to the audio tutorial. Here you will learn the sounds used in this game. Use the arrow keys to browse. Press Space or Enter to play a sound.")), stop: false, break_sequence: false)
    form.wait
  ensure
    stop
  end

  private

  def play(entry)
    stop
    return unless entry

    volume = @program.respond_to?(:game_room_sound_volume, true) ? @program.send(:game_room_sound_volume, entry.asset).to_f : 1.0
    enabled = !@program.respond_to?(:game_room_sound_enabled?, true) || @program.send(:game_room_sound_enabled?, entry.asset)
    if !enabled || volume <= 0
      speak(GameRoomContent.utf8(_("This sound is muted in Game Room settings.")))
      return
    end
    @sound = @program.play_sound_from_asset(entry.asset, volume: volume, sample: false, loop: false)
    speak(GameRoomContent.utf8(_("This sound could not be played."))) unless @sound
  end

  def stop
    @sound&.close
    @sound = nil
  end
end