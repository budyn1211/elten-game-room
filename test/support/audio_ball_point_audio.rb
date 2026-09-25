require_relative '../../lib/audio_ball/audio'

def _(text); text; end unless Object.private_method_defined?(:_)

module AudioBallPointTest
  class Sound
    attr_accessor :pan, :volume, :frequency, :duration
    attr_reader :plays, :seeks, :closes, :interruptions

    def initialize(program, name)
      @program, @name = program, name
      @frequency, @duration = 48_000, 0.35
      @plays, @closes, @interruptions, @seeks = 0, 0, 0, []
    end

    def position=(value); @seeks << value; end
    def length; @duration; end
    def playing?; @started && @program.now < @started + @duration; end
    def finished?; !playing?; end
    def play
      raise 'Closed point handle played' if @closes > 0
      @interruptions += 1 if playing?
      @started = @program.now
      @plays += 1
      @program.events << [@name, @started, @duration]
    end
    def pause
      @interruptions += 1 if playing?
      @started = nil
    end
    def close; @closes += 1; @started = nil; end
  end

  class Program
    attr_reader :sounds, :created, :managed, :released, :events
    attr_accessor :now, :gain, :enabled, :announcer
    def initialize(missing: [])
      @missing = missing
      @sounds, @created, @managed, @released, @events = {}, [], [], [], []
      @now, @gain, @enabled, @announcer = 0.0, 1.0, true, 100
    end
    def create_sound_from_asset(name, sample: false, loop: false)
      @created << [name, sample, loop]
      return if @missing.include?(name)
      @sounds[name] = Sound.new(self, name)
    end
    def manage(sound); @managed << sound; end
    def release(sound); @released << sound; end
    private
    def game_room_sound_enabled?(_name); @enabled; end
    def game_room_sound_volume(_name); @gain; end
    def pong_preferences; {'announcer_volume' => @announcer}; end
  end

  def self.assert(value, message); raise message unless value; end
  def self.check(name)
    yield
    puts "PASS #{name}"
  end

end
