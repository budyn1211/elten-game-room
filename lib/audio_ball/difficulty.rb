module GameRoomAudioBall
  module Difficulty
    # One ordered scale for physics, table choices and the bot. Equal speed
    # growth keeps harder levels faster even in a long rally.
    DEFAULT = 3
    SPEED_MULTIPLIER = 1.05
    PROFILES = [
      {label: 'Very easy', duration: 4.0, hold_delay: 0.45, reaction: 0.32, error: 0.32},
      {label: 'Easy', duration: 2.2, hold_delay: 0.35, reaction: 0.25, error: 0.24},
      {label: 'Normal', duration: 1.5, hold_delay: 0.25, reaction: 0.18, error: 0.11},
      {label: 'Hard', duration: 0.9, hold_delay: 0.18, reaction: 0.12, error: 0.06},
      {label: 'Very hard', duration: 0.6, hold_delay: 0.13, reaction: 0.08, error: 0.025}
    ].map(&:freeze).freeze

    def self.valid?(level)
      level.is_a?(Integer) && (1..PROFILES.length).include?(level)
    end
  end
end
