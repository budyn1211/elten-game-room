require_relative 'preferences'

module GameRoomAudioBall
  module SoundPack
    DEFAULT = {'up' => 'audio_ball_up', 'left' => 'audio_ball_left',
      'down' => 'audio_ball_down', 'prepare' => 'audio_ball_prepare',
      'stop' => 'audio_ball_stopped', 'goal' => nil}.freeze
    AUDIODISC = {'up' => 'audio_ball_audiodisc_up', 'left' => 'audio_ball_audiodisc_center',
      'down' => 'audio_ball_audiodisc_down', 'prepare' => 'audio_ball_audiodisc_ready',
      'stop' => 'audio_ball_audiodisc_stop', 'goal' => 'audio_ball_audiodisc_goal'}.freeze
    PACKS = {'default' => DEFAULT, 'audiodisc' => AUDIODISC}.freeze
    module_function

    def selected(program)
      values = Preferences.read(program)
      PACKS.fetch(values.is_a?(Hash) ? values['sound_pack'] : nil, DEFAULT)
    end

    def asset(role, program)
      selected(program).fetch(role)
    end
  end
end
