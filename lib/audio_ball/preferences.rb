# encoding: UTF-8
module GameRoomAudioBall
  module Preferences
    SOUND_PACKS = %w[default audiodisc].freeze
    DEFAULTS = {'listening_side' => 'right', 'sound_pack' => 'default'}.freeze
    module_function

    def normalize(values)
      values = values.is_a?(Hash) ? values : {}
      {'listening_side' => values['listening_side'] == 'left' ? 'left' : 'right',
        'sound_pack' => SOUND_PACKS.include?(values['sound_pack']) ? values['sound_pack'] : 'default'}
    end

    def read(program)
      return DEFAULTS unless program.respond_to?(:audio_ball_preferences, true)
      program.send(:audio_ball_preferences)
    end
  end
end
