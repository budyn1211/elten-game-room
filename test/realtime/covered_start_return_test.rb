require_relative '../support/background_help_native'

module GameSurfaces
  module ActionEmitter; end
end
require_relative '../../lib/game_surfaces/pong_surface'
require_relative '../../lib/axel_pong/client'

# The native host runs the game and a covering forum on different UI threads.
# A covered start creates Progress on the forum thread, before the game has a
# playfield. Returning must hand its existing timer to the playfield's thread.
module EltenAPI::UI
  def loop_update; :host; end
end
class CoveredStartHostScene
  prepend EltenAPI::UI
end

class CoveredStartKeyboard
  attr_reader :now
  def initialize
    @now, @held = 0.0, []
  end

  def tick(_control); end

  def sample(keys = [])
    @now += 0.02
    state = "\0" * 256
    keys.each { |code| state.setbyte(code, 0x80) }
    events = (@held - keys).map { |code| [code, false] } +
      (keys - @held).map { |code| [code, true] }
    @held = keys
    EltenAPI::KeyboardState.update(raw_state: state, events: events, now: @now,
      pressed_implies_held: false, synthesize_repeats: false)
    $input_frame_serial = $input_frame_serial.to_i + 1
    $keyboard_state_frame_serial = $input_frame_serial
    $keyboard_state_frame_thread = Thread.current
    $lastactivecontrols = $activecontrols
    $activecontrols = []
  end
end

driver = CoveredStartKeyboard.new
$native_tutorial_driver = driver
$mainthread = $currentthread = Thread.current
scene = CoveredStartHostScene.new
program = NativeTutorialProgram.new
surface = form = nil
client = GameRoomPong::Client.allocate
engine = GameRoomPong::PeerEngine.new(side: 0, authority: true, first_server: 0)
calls = []
progress = nil
forum_thread = Thread.new do
  $currentthread = Thread.current
  progress = GameRoomRealtime::Progress.new(program: program, clock: -> { driver.now }, key: 'covered-start') do |background|
    calls << [background, Thread.current]
    client.instance_variable_set(:@background_input, background)
    if surface
      input = client.send(:playable_input, surface.input(form), active: true, moving: true)
      engine.step([input, {}])
    end
  ensure
    client.instance_variable_set(:@background_input, false)
  end
  $lastactivecontrols = [Object.new]
  driver.sample([0x27, 0x20])
  scene.send(:loop_update)
ensure
  $currentthread = $mainthread
end
forum_thread.value

begin
  assert(calls.size == 1 && calls.last == [true, forum_thread], 'Covered start did not advance on the active forum UI')
  spec = GameSurfaces::PongSpec.new(game_id: 'axel_pong', header: 'Playfield',
    players: %w[Alice Bob], viewer: 0, scores: [0, 2], finished: false)
  surface = GameSurfaces::PongSurface.new(spec)
  field = surface.fields.first
  chat = EditBox.new('Chat', text: 'draft', quiet: true)
  form = GameRoomUI::Form.new([field, chat], quiet: true)
  client.instance_variable_set(:@surface, surface)
  client.instance_variable_set(:@form, form)
  progress.attach(form)
  form.focus
  $activecontrols = [form, field]
  EltenAPI::KeyboardState.reset

  frame = ->(keys = []) do
    before = calls.size
    driver.sample(keys)
    scene.send(:loop_update)
    form.update
    assert(calls.size == before + 1, 'Bridge and native form advanced the same frame twice')
  end

  frame.call
  assert(calls.last == [false, Thread.current], 'Returned playfield still advanced as background input')
  assert(engine.turn == 0 && engine.paddles == [15.0, 15.0], 'Forum keys leaked into the returned game')
  frame.call([0x27])
  assert(engine.paddles[0] > 15, 'Fresh right arrow stopped after adopting a covered-started game')
  frame.call
  before_left = engine.paddles[0]
  frame.call([0x25])
  assert(engine.paddles[0] < before_left, 'Fresh left arrow stopped after adopting a covered-started game')
  frame.call
  frame.call([0x20])
  assert(engine.turn == 1, 'Fresh serve stopped after adopting a covered-started game')

  frame.call
  frame.call([0x09])
  assert(form.fields[form.index].equal?(chat), 'Native Tab did not enter chat')
  before_chat = engine.paddles.dup
  frame.call([0x27])
  assert(engine.paddles == before_chat && chat.text == 'draft', 'Chat input moved the paddle or lost its draft')

  # A later cover uses the same timer and neutral input, not another engine.
  driver.sample
  $lastactivecontrols = [Object.new]
  before = calls.size
  scene.send(:loop_update)
  assert(calls.size == before + 1 && calls.last.first, 'Covering the adopted game stopped its neutral progression')
  progress.detach
  driver.sample
  scene.send(:loop_update)
  assert(calls.last.first, 'Detached view stopped background progression')
  progress.attach(form)
  progress.attach(form)
  assert(form.instance_variable_get(:@timers).count { |timer| timer.equal?(progress.timer) } == 1,
    'Reattaching the same view duplicated its timer')
  form.index = 0
  $activecontrols = [form, field]
  frame.call
  assert(!calls.last.first, 'Reattached form did not reclaim foreground progress')
ensure
  progress&.close
  $lastactivecontrols = $activecontrols = []
end

puts 'PASS covered realtime start: native playfield arrows/serve return, chat isolation, one timer and subsequent covers'
