require_relative 'ui'

class Program
  def self.server_app(**_options); end
end

require_relative '../../__app'

def assert(value, message)
  raise message unless value
end

class TutorialSound
  attr_reader :closed
  def close; @closed = true; end
end

class TutorialProgram
  attr_reader :plays
  attr_accessor :volume, :enabled, :missing
  def initialize
    @plays, @volume, @enabled = [], 0.4, true
  end
  def play_sound_from_asset(name, **options)
    sound = missing ? nil : TutorialSound.new
    @plays << [name, options, sound]
    sound
  end
  private
  def game_room_sound_volume(_name); volume; end
  def game_room_sound_enabled?(_name); enabled; end
end

Form.prepend(Module.new do
  def initialize(fields, **options)
    @tutorial_opening_header = fields.first.header
    super
  end
end)

class Form
  class << self; attr_accessor :tutorial_driver; end
  def wait; Form.tutorial_driver.call(self); end
  def resume; @resumed = true; end
end
