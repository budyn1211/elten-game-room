require_relative '../../lib/axel_pong/audio'
require_relative '../../lib/axel_pong/engine'
def assert(value, message); raise message unless value; end
class PongSound
  attr_accessor :frequency, :volume, :pan, :position
  attr_reader :plays, :closed
  def initialize; @frequency = 44100; @plays = 0; @volume = 0; end
  def play; @playing = true; @plays += 1; end
  def pause; @playing = false; end
  def playing?; @playing; end
  def close; @closed = true; end
end
class PongAudioProgram
  attr_reader :sounds, :released, :managed, :loops
  attr_accessor :gain, :enabled
  def initialize
    @sounds, @loops, @released, @managed = {}, {}, [], []
    @gain, @enabled = 1.0, true
  end
  def create_sound_from_asset(name, loop:)
    @loops[name] = loop
    @sounds[name] = PongSound.new
  end
  def manage(sound); @managed << sound; end
  def release(sound); @released << sound; end
  def game_room_sound_enabled?(_name); @enabled; end
  def game_room_sound_volume(_name); @gain; end
end
