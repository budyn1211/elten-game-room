require_relative 'realtime_two_clients_test'
require_relative 'support/audio_ball_client'

class AudioBallRelayHarness < AudioBallHarness
  attr_reader :rig

  def initialize(**options)
    @rig = RelayFixture.new
    @keys = {}
    super(**options)
  end

  def add_client(name, connected: true)
    rig = @rig
    program = Program.new
    program.define_singleton_method(:communication) { rig.endpoint(name) }
    program.define_singleton_method(:release) { |_resource| }
    @audios[name] = AudioBallTestAudio.new
    client = GameRoomAudioBall::Client.new(program, @game, clock: -> { @now }, audio: @audios[name],
      channel_factory: ->(**args) { @network[name.downcase] = GameRoomRealtime::EventChannel.new(**args,
        work_factory: -> { rig.worker(name) }, event_work_factory: -> { rig.worker(name) }) })
    client.bind_screen(session_id: 300, table_id: 20, owner: @owner, viewer: name, members: -> { @viewers })
    client.start
    client.before_wait(@replay, name)
    @surfaces[name] = GameSurfaces.build(@game.surface_spec(@replay, name))
    field = @surfaces[name].fields.first
    @keys[name] = []
    keys = @keys
    field.define_singleton_method(:key_pressed?) { |code| keys[name].include?(code) }
    field.define_singleton_method(:key_held?) { |code| keys[name].include?(code) }
    @forms[name] = Form.new([field, EditBox.new('Chat')])
    client.attach_view(@forms[name], @surfaces[name])
    @clients[name] = client
    @viewers << name unless @viewers.include?(name)
    client
  end

  def advance(count = 1, seconds: 0.008, names: @viewers)
    count.times do
      @now += seconds
      @rig.now = @now
      @rig.advance_work
      names.each do |name|
        field = @surfaces[name].fields.first
        $activecontrols = [field]
        field.update
        @keys[name] = []
        @clients[name].frame
      end
    end
  ensure
    $activecontrols = nil
  end

  def key(name, command)
    @keys[name] = [{'up' => 0x57, 'left' => 0x44, 'down' => 0x53, 'prepare' => 0x41}.fetch(command)]
  end

  def press(name, *commands)
    commands.each { |command| key(name, command); advance; advance }
  end

  def wait_ready
    1500.times do
      advance
      return if @clients.values.none?(&:paused)
    end
    raise 'native Audio Ball channel never became ready'
  end

  def commit
    before = @replay.state[:rally]
    super
    @clients[@owner].instance_variable_get(:@bots).each do |bot|
      assert(bot.selected_lane == nil, 'durable point retained an armed bot lane')
    end
    raise 'native agreed point was not accepted by replay' unless @replay.state[:rally] == before + 1
    @surfaces.each { |name, surface| surface.update_spec(@game.surface_spec(@replay, name)) }
  end

  def autoplay_step
    @players.each_with_index do |name, side|
      next if GameRoomParticipants.bot?(name)
      client = @clients.fetch(name)
      engine = client.engine
      next if client.paused || !engine
      if engine.holder == side
        key(name, engine.phase == :waiting ? 'prepare' : %w[up left down][@replay.state[:rally] % 3])
      elsif engine.phase == :flying && engine.receiver == side && engine.hits < 8
        distance = (engine.position - (side == 0 ? 25.0 : 0.0)).abs
        key(name, engine.shot) if distance <= 1.4
      end
    end
    advance
    commit if @clients[@owner].context_data['audio_ball_point']
  end
end

h = AudioBallRelayHarness.new(options: {'sets_to_win' => 2})
h.wait_ready
assert(h.network.values.all? { |channel| channel.is_a?(GameRoomRealtime::EventChannel) }, 'native test replaced the real channel')
(h.points_to_win * 2).times do
  h.wait_ready
  h.win_point('Alice')
  assert(h.clients.values.all? { |client| client.instance_variable_get(:@replay).state == h.replay.state }, 'native clients disagree on durable score')
end
assert(h.replay.finished? && h.replay.state[:sets] == [2, 0], 'full native two-set match did not finish through actual fields')
assert(h.audios.values.all? { |audio| audio.calls.count([:set, 2]) == 1 }, 'native second-set speech was repeated or missing')
assert(h.rig.groups.length == 1, 'healthy native play unnecessarily reconnected')
h.close
assert(h.rig.endpoints.values.all?(&:closed?), 'native match leaked an endpoint')
puts "PASS Audio Ball: actual keyboard fields, real EventChannel and complete #{h.points_to_win * 2}-point/two-set match"

bot = GameRoomParticipants.bot_id(20, 1)
[
  {players: ['Alice', bot], owner: 'Alice', viewers: %w[Alice Watcher], server: 1},
  {players: [bot, 'Bob'], owner: 'Alice', viewers: %w[Alice Bob Watcher], server: 0}
].each do |options|
  h = AudioBallRelayHarness.new(**options)
  80_000.times do
    h.autoplay_step
    break if h.replay.finished?
  end
  assert(h.replay.finished?, 'native bot match did not finish through legal input and scoring')
  assert(h.replay.state[:sets].max == 1 && h.replay.state[:last_point][:scores].max >= h.points_to_win, 'native bot match did not obey set scoring')
  puts "PASS Audio Ball native bot match: owner=#{options[:owner]}, players=#{options[:players].join('/')}, points=#{h.replay.state[:rally]}, sets=#{h.replay.state[:sets].inspect}"
  h.close
  assert(h.rig.endpoints.values.all?(&:closed?), 'native bot match leaked an endpoint')
end
