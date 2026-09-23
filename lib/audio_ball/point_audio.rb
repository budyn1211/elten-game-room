require_relative "../axel_pong/audio"
require_relative "sound_pack"

module GameRoomAudioBall
  class PointAudio < GameRoomPong::Audio
    def load
      return if @loaded
      ANNOUNCEMENTS.each { |name| load_sound(name, name) }
      refresh_preferences
      @loaded = true
    end

    def refresh_preferences
      asset = SoundPack.asset('goal', @program)
      return if defined?(@goal_asset) && @goal_asset == asset
      @goal_asset = asset
      load_sound(@goal_asset, @goal_asset) if @goal_asset && !@sounds[@goal_asset]
    end

    def goal(viewer:, winner: nil)
      return super unless @goal_asset && @sounds[@goal_asset]
      clear_announcements
      return unless presentation_enabled?
      suspend
      play_announcement(@goal_asset)
      play_voice(GOAL_VOICES[@rng.rand(GOAL_VOICES.length)])
    end

    def announce(text)
      at = [@clock.call, @score_queue.last ? @score_queue.last[0] : 0].max
      @score_queue << [at, {speech: text}]
      tick
    end

    def presentation_enabled?
      gain('pong_goal') > 0 && personal_gain('pong_scores') > 0
    end

    def cancel
      clear_announcements
    end

    private

    # Reuse the recordings and sequencer, not Pong's unrelated Ctrl+P settings.
    # The inherited gain still applies the shared Game Room game-volume controls.
    def personal_gain(_name)
      1.0
    end
  end
end
