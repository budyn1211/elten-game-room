require_relative "../axel_pong/audio"

module GameRoomAudioBall
  class PointAudio < GameRoomPong::Audio
    def load
      return if @loaded
      ANNOUNCEMENTS.each { |name| load_sound(name, name) }
      @loaded = true
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
  end
end
