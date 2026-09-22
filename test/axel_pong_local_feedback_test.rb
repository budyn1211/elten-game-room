require_relative 'support/pong_client'

class LocalFeedbackSound
  attr_accessor :frequency, :volume, :pan, :position
  def initialize; @frequency = 48_000; @volume = @pan = @position = 0; end
  def play; @playing = true; end
  def pause; @playing = false; end
  def playing?; @playing == true; end
  def finished?; !playing?; end
  def length; 2.0; end
  def close; pause; end
end

class LocalFeedbackProgram
  def create_sound_from_asset(*_args, **_options); LocalFeedbackSound.new; end
  def pong_preferences; GameRoomPong::Preferences::DEFAULTS; end
end

class LocalFeedbackMouse
  attr_accessor :delta
  def initialize; @delta = [0, 0, false]; end
  def sample; @delta; end
  def suspend; end
end

class LocalFeedbackAudio < GameRoomPong::Audio
  attr_reader :effects
  def initialize(*args, **options); super; @effects = []; end
  def play_effect(kind, source, x, y, state, viewer)
    super
    @effects << [(@clock.call * 1000).round, kind, source, source != nil ? state['p'][source] : nil]
  end
end

# The real audio dispatcher and clients run against a jittery latest-state
# channel. No audio device, live account or Windows pointer is touched.
def feedback_fixture(players, jitter: false, mouse: true)
  viewers = (['Alice'] + players.reject { |name| GameRoomParticipants.bot?(name) }).uniq
  options = players.length == 4 ? {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]} : {}
  h = PongHarness.new(players: players, viewers: viewers, options: options)
  queue, audios, backends = [], {}, {}
  viewers.each do |name|
    client = h.clients.fetch(name)
    client.define_singleton_method(:first_server) { 0 }
    client.send(:reset_rally)
    surface = h.surfaces.fetch(name)
    surface.define_singleton_method(:input_active?) { |_form| @input_active != false }
    surface.controls.merge!('left_press' => 0, 'right_press' => 0)
    backends[name] = LocalFeedbackMouse.new
    backends[name].delta = nil unless mouse
    client.instance_variable_set(:@mouse, GameRoomPong::MouseControl.new(backend: backends[name]))
    audios[name] = LocalFeedbackAudio.new(LocalFeedbackProgram.new, clock: -> { h.now })
    audios[name].load
    audios[name].prepare_players(players.length)
    client.instance_variable_set(:@audio, audios[name])
    channel, count = h.network.fetch(name.downcase), 0
    channel.define_singleton_method(:send) do |data|
      return false unless connected?
      @sent << data
      packet = JSON.parse(data)
      count += 1
      delay = jitter ? [0.016, 0.08, 0.032, 0.096, 0.048][count % 5] : 0
      @network.each do |recipient, peer|
        next if recipient == @viewer || peer.epoch != packet['e']
        next if @viewer != @owner && recipient != @owner
        queue << [h.now + delay, @viewer, peer, packet]
      end
      true
    end
  end
  advance = lambda do |frames|
    frames.times do
      h.now += 0.016
      ready, pending = queue.partition { |row| row[0] <= h.now + 0.000001 }
      queue.replace(pending)
      ready.sort_by(&:first).each { |_at, sender, peer, packet| peer.inbox[sender] = packet }
      viewers.each { |name| h.clients.fetch(name).frame }
    end
  end
  advance.call(600)
  assert(h.clients.values.none?(&:paused), 'fixture never became ready')
  yield h, advance, audios, backends
ensure
  h&.close
end

expected = [16, 112, 160, 208, 256, 304, 352, 400, 448, 496]
[
  %w[Alice Bob Carol Dave], ['Alice', 'Bob', 'bot:7:1', 'bot:7:2'], ['Bob', 'bot:7:1']
].each do |players|
  [false, true].each do |jitter|
    [false, true].each do |during_rally|
      feedback_fixture(players, jitter: jitter) do |h, advance, audios, _backends|
        humans = players.reject { |name| GameRoomParticipants.bot?(name) }
        if during_rally
          h.press(humans.first)
          advance.call(30)
          assert(h.clients['Alice'].engine.ball['dy'] != 0, 'rally did not start')
        end
        start = (h.now * 1000).round
        humans.each { |name| h.surfaces[name].controls.merge!('move' => 1, 'right_press' => 1) }
        advance.call(33)
        humans.each { |name| h.surfaces[name].controls['move'] = 0 }
        advance.call(25)
        humans.each do |name|
          side = players.index(name)
          at = audios[name].effects.select { |time, kind, source, _x| time >= start && kind == 'step' && source == side }.map { |row| row[0] - start }
          assert(at == expected, "#{players}/#{name}, jitter=#{jitter}, rally=#{during_rally}: own steps #{at.inspect}, expected #{expected.inspect}")
        end
        if players.any? { |name| GameRoomParticipants.bot?(name) }
          assert(h.clients['Bob'].engine == nil, 'feedback created another authoritative engine')
        end
      end
    end
  end
end
puts 'PASS local step cadence: four humans, mixed doubles, observing owner with single bot, before serve/during rally and jitter; no network echoes'

[false, true].each do |mouse|
  feedback_fixture(['Alice', 'Bob', 'bot:7:1', 'bot:7:2'], jitter: true, mouse: mouse) do |h, advance, audios, backends|
    client, surface, audio = h.clients['Bob'], h.surfaces['Bob'], audios['Bob']
    start = (h.now * 1000).round
    surface.controls.merge!('move' => 1, 'right_press' => 1)
    advance.call(33)
    surface.controls['move'] = 0
    advance.call(25)
    at = audio.effects.select { |time, kind, side, _x| time >= start && kind == 'step' && side == 1 }.map { |row| row[0] - start }
    assert(at == expected, "mouse capture #{mouse}: keyboard feedback #{at}")
    assert(surface.current['p'][1] == h.clients['Alice'].snapshot['p'][1],
      "mouse capture #{mouse}: idle local presentation drifted from the authoritative paddle")
    count = audio.effects.count { |_, kind, side, _| side == 1 && %w[step edge].include?(kind) }
    # Losing focus must silence input, including late server echoes. The
    # surface's real input also zeros movement in chat; deliberately keep
    # held input here to exercise the client's independent feedback guard.
    surface.instance_variable_set(:@input_active, false)
    surface.controls.merge!('move' => 1, 'right_press' => 2)
    advance.call(6)
    surface.controls['move'] = 0
    advance.call(25)
    assert(audio.effects.count { |_, kind, side, _| side == 1 && %w[step edge].include?(kind) } == count, 'chat/late packets replayed own steps')
    surface.instance_variable_set(:@input_active, true)
    advance.call(4)
    assert(audio.effects.count { |_, kind, side, _| side == 1 && %w[step edge].include?(kind) } == count, 'focus restoration made a step')
    # Presenting a different local position must not modify received state.
    if mouse
      backends['Bob'].delta = [-5, 0, false]
      advance.call(1)
      backends['Bob'].delta = [0, 0, false]
      assert(surface.current['p'][1] != client.snapshot['p'][1], 'local preview waited for owner')
      assert(!surface.current.equal?(client.snapshot), 'presentation mutated authoritative snapshot')
    end
    client.detach_view
    assert(client.instance_variable_get(:@paddle_feedback).position == nil, 'detach retained local position')
    client.attach_view(Form.new([]), surface)
    advance.call(25)
    before = audio.effects.length
    h.accept_point('0:0')
    advance.call(500)
    assert(audio.effects.drop(before).none? { |_, kind, side, _| side == 1 && %w[step edge].include?(kind) }, 'round reset replayed own steps')
    assert(client.engine == nil, 'feedback replaced owner authority')
  end
end
puts 'PASS fallback keyboard, focus, no mutable snapshot sharing, detach/attach and point reset'

# Compare movement feedback with the established engine path: both fresh
# keyboard edges, held repeat, clamping and mouse border counters.
feedback = GameRoomPong::PaddleFeedback.new
engine = GameRoomPong::Engine.new
emitted, sequence = [], 0
inputs = [
  {'move' => 0, 'left_press' => 1, 'right_press' => 1},
  *Array.new(110) { {'move' => -1, 'left_press' => 2, 'right_press' => 1} },
  {'move' => 0, 'paddle' => 1, 'pointer_seq' => 1, 'pointer_before' => 1, 'pointer_start' => 1, 'pointer_keys' => [], 'pointer_edges' => 1},
  {'move' => 0, 'paddle' => 1, 'pointer_seq' => 2, 'pointer_before' => 1, 'pointer_start' => 1, 'pointer_keys' => [1, -1], 'pointer_edges' => 1}
]
inputs.each do |input|
  own = []
  feedback.step(input, position: engine.paddles[0]) { |kind, x| own << [kind, x] }
  engine.send(:move_input, 0, input)
  effects = engine.snapshot['fx'].select { |number, *_| number > sequence }
  sequence = engine.snapshot['fx'].last&.first || sequence
  assert(own.map(&:first) == effects.map { |event| event[1] }, "movement feedback differs: #{input}")
  assert(feedback.position == engine.paddles[0], 'feedback position differs from engine')
  emitted.concat(own)
end
assert(emitted.any? { |kind, _| kind == 'edge' }, 'no border fixture')
puts 'PASS movement feedback parity with keyboard/mouse edges and original repeat; no second ball'

audio = LocalFeedbackAudio.new(LocalFeedbackProgram.new)
audio.load
audio.prepare_players(4)
state = GameRoomPong::Engine.new(teams: [0, 0, 1, 1]).snapshot
state['fx'] = [[1, 'step', 1, 15, 0], [2, 'step', 0, 15, 0], [3, 'edge', 1, 15, 0],
  [4, 'hit', 1, 15, 0], [5, 'wall', nil, 15, 10]]
original = Marshal.dump(state)
audio.play_local_movement(state, viewer: 1, kind: 'step', position: 16)
assert(Marshal.dump(state) == original, 'local movement mutated server snapshot')
2.times { audio.update(state, viewer: 1, paused: false, local_movement: true) }
assert(audio.effects.map { |_, kind, side, _| [kind, side] } == [['step', 1], ['step', 0], ['hit', 1], ['wall', nil]], 'local feedback swallowed non-movement events or echoed movement')
audio.close
puts 'PASS local/remote event separation: own steps once, teammate/strike/wall once, shared snapshot unchanged'
