require_relative 'audio_ball_client'
host = ENV['ELTEN_HOST_SOURCE'] || File.expand_path('../../../elten3', __dir__)
require File.join(host, 'src/eapi/keyboard')
require File.join(host, 'src/ui/input')

module EltenWindow
  def self.keyboard_key_held?(_code); false; end
end

class AudioBallNativeKeys < AudioBallHarness
  attr_reader :field
  def initialize(native: 'Bob', level: 2)
    @native = native
    @server_name = native == 'Alice' ? 'Bob' : 'Alice'
    super(viewers: %w[Alice Bob], server: native == 'Alice' ? 1 : 0, options: {'difficulty' => level})
    @raw_keys, @key_events = [], []
    surface = GameSurfaces.build(@game.surface_spec(@replay, native))
    @field = surface.fields.first
    @field.extend(EltenAPI::UI)
    @surfaces[native] = surface
    @forms[native] = Form.new([@field, EditBox.new('Chat')])
    @clients[native].attach_view(@forms[native], surface)
    EltenAPI::KeyboardState.reset
  end

  def keys(codes)
    @key_events = (@raw_keys - codes).map { |code| [code, false] } +
      (codes - @raw_keys).map { |code| [code, true] }
    @raw_keys = codes
  end

  def tap(code, modifiers: [])
    state = "\0" * 256
    (@raw_keys + modifiers + [code]).each { |key| state.setbyte(key, 0x80) }
    @key_events.concat(modifiers.map { |key| [key, true] })
    @key_events.concat([[code, true, state], [code, false]])
    @key_events.concat(modifiers.reverse.map { |key| [key, false] })
  end

  def poll_keys
    state = "\0" * 256
    @raw_keys.each { |code| state.setbyte(code, 0x80) }
    EltenAPI::KeyboardState.update(raw_state: state, events: @key_events, now: @now,
      synthesize_repeats: false, pressed_implies_held: false)
    @key_events = []
    $input_frame_serial = $input_frame_serial.to_i + 1
    $keyboard_state_frame_serial = $input_frame_serial
    $keyboard_state_frame_thread = Thread.current
  end

  def advance(count = 1, seconds: 0.016, names: %w[Alice Bob])
    count.times do
      @now += seconds
      poll_keys
      $activecontrols = [@field]
      @field.update
      names.each { |name| @clients[name].frame }
    end
  ensure
    $activecontrols = nil
  end

  def remaining
    engine = @clients[@native].engine
    endpoint = @players.index(@native).zero? ? GameRoomAudioBall::Engine::WIDTH : 0.0
    engine.phase == :flying ? engine.duration * (engine.position - endpoint).abs / GameRoomAudioBall::Engine::WIDTH : 0.0
  end

  def approach(shot, seconds_left)
    advance(12)
    press(@server_name, 'prepare', shot)
    ((GameRoomAudioBall::Engine::INITIAL_DURATION.max / 0.016).ceil + 50).times do
      break if @clients[@native].engine.phase == :flying && remaining <= seconds_left
      advance
    end
    assert(@clients[@native].engine.phase == :flying && remaining <= seconds_left,
      "native keyboard setup missed flight: #{@native}, server=#{@server_name}, states=#{@clients.transform_values { |client| [client.paused, client.engine.phase, client.engine.server, client.engine.turn] }}")
  end
end
