# encoding: UTF-8
module GameRoomAudioBall
  module Preferences
    DEFAULTS = {'listening_side' => 'right'}.freeze
    module_function

    def normalize(values)
      values = values.is_a?(Hash) ? values : {}
      {'listening_side' => values['listening_side'] == 'left' ? 'left' : 'right'}
    end

    def read(program)
      return DEFAULTS unless program.respond_to?(:audio_ball_preferences, true)
      program.send(:audio_ball_preferences)
    end
  end
end
