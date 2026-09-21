host_source = ENV['ELTEN_HOST_SOURCE'] || File.expand_path('../../elten3', __dir__)
host_speech = File.join(host_source, 'src/eapi/speech.rb')
require host_speech if ENV['ELTEN_HOST_SOURCE'] || File.file?(host_speech)
require_relative 'support/pong_client'

players = %w[Alice Bob Carol Dave]
clock = 8.0
speech_client = GameRoomPong::Client.new(Program.new, GameRoomGames::AxelPong.new,
  clock: -> { clock }, audio: PongTestAudio.new)
rotation = GameRoomPong::Rotation.new(teams: [0, 0, 1, 1], rally: 2, first_server: 0)
speech_client.instance_variable_set(:@players, players)
speech_client.instance_variable_set(:@rotation, rotation)
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 2}))
speech_client.instance_variable_set(:@snapshot, {'server' => rotation.server, 'receiver' => rotation.receiver})
speech_client.instance_variable_set(:@serve_announce_at, 5.2)
speech_client.instance_variable_set(:@ready_at, 7.2)
$spoken_messages.clear
speech_client.send(:announce_ready, clock)
assert($spoken_messages == ['Dave will serve against Bob.'], 'doubles service did not name both participants')
assert(speech_client.instance_variable_get(:@ready_at) == 13.4, 'late service speech did not retain its 5.4-second delay')
speech_client.instance_variable_set(:@server_announced, false)
speech_client.send(:announce_ready, clock)
assert($spoken_messages.length == 1, 're-render repeated the same service block')
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 3}))
speech_client.instance_variable_set(:@server_announced, false)
speech_client.send(:announce_ready, clock)
assert($spoken_messages.length == 1, 'second serve repeated the service pairing')

unless defined?(EltenAPI::SpeechCommands::CustomCommand)
  module EltenAPI
    module SpeechCommands
      class CustomCommand
        def initialize(&block); @block = block; end
        def execute; @block.call; end
      end
    end
  end
end
unless defined?(EltenAPI::SpeechSequence)
  module EltenAPI
    class SpeechSequence
      attr_reader :commands
      def initialize(*commands); @commands = commands; end
      def to_s; @commands.grep(String).join; end
      def texts; [to_s, '']; end
      def indexes; [1, 2]; end
      def execute(index); @commands.last.execute if index >= 2; end
    end
  end
end

def indexed_speech(client)
  client.define_singleton_method(:speech_indexes_supported?) { true }
  client.define_singleton_method(:current_speechsequence) { @test_sequence }
  client.define_singleton_method(:speak) { |value| @test_sequence = value.is_a?(EltenAPI::SpeechSequence) ? value : nil }
end

speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 4}))
speech_client.instance_variable_set(:@server_announced, false)
indexed_speech(speech_client)
speech_client.send(:announce_ready, clock)
sequence = speech_client.current_speechsequence
assert(sequence.is_a?(EltenAPI::SpeechSequence), 'doubles speech ignored host completion indexes')
clock = 20.0
assert(speech_client.send(:serve_announcement_waiting?), 'long speech unlocked service before completion')
assert(sequence.texts == [sequence.to_s, ''], 'completion command was not indexed after the service text')
sequence.execute(sequence.indexes.first)
assert(speech_client.send(:serve_announcement_waiting?), 'first speech index prematurely unlocked service')
sequence.execute(sequence.indexes.last)
assert(!speech_client.send(:serve_announcement_waiting?) && speech_client.instance_variable_get(:@ready_at) == 25.4,
  'service did not wait 5.4 seconds from actual completion')
clock = 21.0
sequence.commands.last.execute
assert(speech_client.instance_variable_get(:@ready_at) == 25.4, 'repeated speech callback extended service delay')
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 6}))
speech_client.instance_variable_set(:@server_announced, false)
speech_client.send(:announce_ready, clock)
cancelled = speech_client.current_speechsequence
speech_client.speak('Another message')
assert(!speech_client.send(:serve_announcement_waiting?) && speech_client.instance_variable_get(:@ready_at) == 26.4,
  'interrupted speech left service waiting indefinitely')
clock = 24.0
cancelled.commands.last.execute
assert(speech_client.instance_variable_get(:@ready_at) == 26.4, 'cancelled completion affected a newer announcement')
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 8}))
speech_client.instance_variable_set(:@server_announced, false)
speech_client.send(:announce_ready, clock)
stale = speech_client.current_speechsequence
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 9}))
speech_client.send(:reset_rally_feedback)
deadline = speech_client.instance_variable_get(:@ready_at)
clock = 40.0
stale.commands.last.execute
assert(speech_client.instance_variable_get(:@ready_at) == deadline, 'old-rally speech callback delayed a newer rally')
speech_client.instance_variable_set(:@replay, Struct.new(:state).new({rally: 10}))
speech_client.instance_variable_set(:@server_announced, false)
speech_client.send(:announce_ready, clock)
stale = speech_client.current_speechsequence
speech_client.instance_variable_set(:@closed, true)
stale.commands.last.execute
assert(speech_client.instance_variable_get(:@ready_at) == deadline, 'speech callback changed a closed client')

h = PongHarness.new(players: players, viewers: players, options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
begin
  h.advance(550)
  assert(h.clients.values.all? { |client| client.snapshot && client.snapshot['p'].length == 4 },
    'four clients did not receive four independent paddles')
  assert(h.clients.values.none?(&:paused), 'four-client handshake never resumed')
  assert(h.clients.values.all? { |client| client.snapshot['teams'] == [0, 0, 1, 1] },
    'client ignored the chosen team assignment')
  players.each { |name| h.surfaces[name].controls['move'] = 1 }
  h.advance(10)
  players.each { |name| h.surfaces[name].controls['move'] = 0 }
  h.advance(8)
  assert(h.clients.values.all? { |client| client.snapshot['p'].all? { |x| x > 15 } },
    'a local or remote partner paddle did not move')
  messages = $spoken_messages.grep(/will serve against/).length
  h.network.each_value { |channel| channel.epoch = 'speech-replacement' }
  h.advance(550)
  assert($spoken_messages.grep(/will serve against/).length == messages, 'reconnect repeated a service block announcement')
  h.accept_point('0:0')
  h.advance(380)
  assert($spoken_messages.grep(/will serve against/).length == messages, 'second serve announced the same pairing')
  h.accept_point('1:0')
  host = h.clients['Alice']
  assert((host.instance_variable_get(:@serve_announce_at) - h.now - 5.0).abs < 0.000001,
    'post-goal pairing did not keep the standard score-plus-two-second announcement schedule')
  h.advance(230)
  assert($spoken_messages.grep(/will serve against/).length == messages, 'post-goal pairing was announced too early')
  h.now += 2.5
  h.clients.each_value(&:frame)
  assert(h.clients.values.all?(&:paused), 'delayed pairing speech collapsed the 5.4-second pause')
  assert($spoken_messages.grep(/will serve against/).length == messages + h.clients.length,
    'changed service block was not announced once on every client')
  h.advance(337)
  assert(h.clients.values.all?(&:paused), 'delayed pairing speech unlocked service too early')
  h.advance(5)
  assert(h.clients.values.none?(&:paused), 'delayed pairing speech never unlocked service')
ensure
  h.close
end
h = PongHarness.new(players: %w[Bob Carol Dave Erin], options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
begin
  host = h.clients['Alice']
  server_name = h.players[host.engine.server]
  server = h.clients[server_name]
  indexed_speech(host)
  indexed_speech(server)
  h.advance(400)
  assert(h.clients.values.all?(&:paused), 'ongoing authority speech did not hold all clients')
  assert(host.current_speechsequence && server.current_speechsequence, 'indexed pairing was not announced')
  h.press(server_name, move: 1)
  h.advance(8)
  assert(server.engine.turn.zero? && server.engine.paddles[host.engine.server] > 15,
    'speech pause blocked movement or allowed an early serve')
  h.surfaces[server_name].controls['move'] = 0
  host.current_speechsequence.commands.last.execute
  h.advance(140)
  assert(server.paused && server.engine.turn.zero?, 'server bypassed its own unfinished announcement')
  server.current_speechsequence.commands.last.execute
  h.advance(337)
  assert(server.paused, 'server unlocked before 5.4 seconds after speech completion')
  h.advance(4)
  assert(!server.paused && server.engine.turn.zero?, 'speech completion failed to unlock without replaying a paused press')
  h.press(server_name)
  h.advance(8)
  assert(h.players.all? { |name| h.clients[name].engine.turn == 1 }, 'four-client serve failed after speech completion')
ensure
  h.close
end
h = PongHarness.new(players: players, options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
begin
  h.advance(550)
  h.accept_point('0:0')
  h.accept_point('1:0')
  h.advance(660)
  host = h.clients['Alice']
  rotation = host.engine.rotation
  teammate = (rotation.members(rotation.team(rotation.server)) - [rotation.server]).first
  assert(!h.clients[players[teammate]].request_hurry, 'server teammate was allowed to hurry their own team')
  assert(!h.clients[players[rotation.server]].request_hurry, 'server hurried themselves')
  assert(!h.clients['Watcher'].request_hurry, 'observer controlled the service timer')
  requester = rotation.members(1 - rotation.team(rotation.server)).first
  assert(h.clients[players[requester]].request_hurry, 'opposing team could not hurry the server')
  h.advance(8)
  warning = "#{players[rotation.server]}, serve within ten seconds or your opponent receives a point."
  assert($spoken_messages.include?(warning), 'hurry warning did not name the actual serving participant')
  h.advance(640)
  assert(host.context_data['pong_point'] == "2:#{1 - rotation.team(rotation.server)}:timeout",
    'service timeout did not concede the point to the opposing team')
ensure
  h.close
end
h = PongHarness.new(players: players, options: {'team_size' => 2, 'team_seats' => [1, 0, 1, 0]})
begin
  h.advance(550)
  captures = {}
  h.clients.each do |name, client|
    captures[name] = []
    audio = client.instance_variable_get(:@audio)
    audio.define_singleton_method(:goal) { |**args| captures[name] << [:goal, args] }
    audio.define_singleton_method(:point) { |_scores, **args| captures[name] << [:point, args] }
    client.send(:preview_goal, 1)
  end
  before = h.replay
  h.accept_point('0:1')
  h.clients.each do |name, client|
    client.event({'action' => 'pong_point'}, before, h.replay, name, h.repository)
    seat = players.index(name) || 0
    assert(captures[name].all? { |_, args| args[:viewer] == [1, 0, 1, 0][seat] && args[:winner] == 1 },
      'point audio used a participant seat instead of its team')
    assert(client.instance_variable_get(:@audio).updates.last[1] == seat, 'continuous audio lost the local participant perspective')
  end
ensure
  h.close
end
h = PongHarness.new(players: ['bot:7:1', 'bot:7:2', 'bot:7:3', 'Bob'], viewers: %w[Alice Bob Watcher],
  options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
begin
  host = h.clients['Alice']
  h.clients.each_value do |client|
    match = client.instance_variable_get(:@match)
    [0, 1].each do |team|
      client.instance_variable_set(:@match, match[0...-1] + team.to_s)
      assert(client.send(:first_server) == team, 'doubles bot match replaced shared team parity with human-first service')
    end
    client.instance_variable_set(:@match, match)
  end
  indexed_speech(host)
  indexed_speech(h.clients['Bob'])
  h.advance(180)
  assert(host.engine.paddles.length == 4 && host.engine.turn.zero?, 'bot served before indexed announcement completion')
  host.current_speechsequence.commands.last.execute
  h.advance(337)
  assert(host.engine.turn.zero?, 'bot served before the 5.4-second completion delay')
  h.advance(120)
  assert(host.engine.turn.zero?, 'bot served while the sole human was still hearing the pairing')
  h.clients['Bob'].current_speechsequence.commands.last.execute
  h.advance(337)
  assert(host.engine.turn.zero?, 'bot ignored the sole human 5.4-second completion delay')
  h.advance(120)
  assert(host.engine.turn > 0 && h.clients.values.all? { |client| client.snapshot['p'].length == 4 },
    'four-participant owner simulation or guest snapshots failed with bots')
  assert(h.clients['Bob'].engine == nil && !host.is_a?(GameRoomPong::PeerPlay), 'bot match acquired competing peer simulations')
ensure
  h.close
end
h = PongHarness.new(players: %w[Bob Carol Alice Dave], options: {'team_size' => 2})
begin
  h.advance(550)
  h.clients.each_value do |client|
    assert(client.engine.hit_width(2) == 4.0 && [0, 1, 3].all? { |seat| client.engine.hit_width(seat) == 4.5 },
      'owner seated after the first pair assigned invalid guest physics roles')
  end
ensure
  h.close
end
%w[Alice Bob].each do |human|
  players = [human, 'bot:7:1', 'bot:7:2', 'bot:7:3']
  h = PongHarness.new(players: players, viewers: ['Alice', human, 'Watcher'].uniq,
    options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
  begin
    host = h.clients['Alice']
    assert(host.engine.rotation.members(0) == [0, 1], 'sole human did not receive one allied bot')
    assert(h.clients.values.all? { |client| client.instance_variable_get(:@required).none? { |name| GameRoomParticipants.bot?(name) } },
      'one-human doubles required a bot network identity')
    serves, returns = [], []
    8.times do |rally|
      700.times do
        break unless host.paused || h.clients[human].paused
        h.advance(1)
      end
      assert(!host.paused, 'one-human doubles did not become ready')
      engine = host.engine
      serves << engine.server
      h.press(human) if engine.server.zero?
      450.times do
        break unless engine.turn.zero?
        h.advance(1)
      end
      assert(engine.turn == 1 && engine.goal == nil,
        "#{human} rally #{rally}: participant #{engine.server} did not serve (turn #{engine.turn}, paused #{h.clients[human].paused})")
      4.times do
        turn = engine.turn
        seat = engine.rotation.hitter(turn)
        human_turn = seat.zero?
        distance = human_turn ? 3.0 : -0.01
        engine.ball.merge!('x' => engine.paddles[seat],
          'y' => engine.rotation.team(seat).zero? ? distance : GameRoomPong::Engine::DEPTH - distance)
        h.press(human) if human_turn
        40.times do
          break if engine.turn != turn
          h.advance(1)
        end
        assert(engine.turn == turn + 1 && engine.goal == nil, "one-human doubles participant #{seat} failed its prescribed return")
        assert(engine.events.any? { |event| event[1] == 'hit' && event[2] == seat }, 'return was not produced by the actual participant controller')
        returns << seat unless human_turn
      end
      loser = engine.rotation.hitter(engine.turn)
      engine.ball.merge!('x' => engine.paddles[loser] < 15 ? 29.0 : 1.0,
        'y' => engine.rotation.team(loser).zero? ? -0.01 : 20.01)
      40.times do
        break if host.context_data['pong_point']
        h.advance(1)
      end
      value = "#{rally}:#{1 - engine.rotation.team(loser)}"
      assert(host.context_data['pong_point'] == value, 'one-human doubles point failed the human acknowledgement barrier')
      if rally.zero?
        h.network.each_value { |channel| channel.epoch = 'bot-point-replacement' }
        h.advance(12)
        assert(host.context_data['pong_point'] == value && host.engine.goal != nil,
          'one-human doubles reconnect discarded an agreed point')
      end
      context = GameRoomGames::ActionContext.new(table_owner: 'Alice', local_data: host.context_data)
      status, = h.rules.action_for({'kind' => 'command', 'action' => 'pong_point', 'point' => value},
        h.replay, 'Alice', context: context)
      assert(status == :ok, 'one-human doubles bypassed the durable action path')
      h.accept_point(value)
      assert(h.replay.state[:rally] == rally + 1, 'one-human doubles did not durably advance its service block')
    end
    assert(serves.uniq.sort == [0, 1, 2, 3] && returns.uniq.sort == [1, 2, 3],
      'one-human doubles skipped a bot service or return role')
  ensure
    h.close
  end
end
puts 'PASS Pong doubles clients: indexed service, four paddles, team audio, hurry and eight durable points for both one-human/three-bot owner roles'
