require_relative 'pong_client'

# Real announcement scheduling, without a sound device or live network.
class MixedGoalAudio < GameRoomPong::Audio
  attr_reader :goals, :points
  def initialize(clock)
    @goals, @points = [], []
    super(nil, clock: clock, speaker: ->(_text) {}, speech_active: -> { false })
  end
  def goal(**args); @goals << args.merge(at: @clock.call); super; end
  def point(scores, **args); @points << args.merge(scores: scores, at: @clock.call); super; end
  private
  def gain(_name); 1.0; end
end

def mixed_goal_match(players = ['Alice', 'Bob', 'Carol', 'bot:7:1'], viewers: nil)
  viewers ||= (['Alice'] + players.reject { |name| GameRoomParticipants.bot?(name) } + ['Watcher']).uniq
  options = players.length == 4 ? {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]} : {}
  h = PongHarness.new(players: players, viewers: viewers, options: options)
  h.advance(80)
  assert(h.clients.values.none?(&:paused), 'mixed match failed to prepare')
  assert(h.clients.values.all? { |c| c.is_a?(GameRoomPong::PeerPlay) }, 'mixed match did not use the unified path')
  h.clients.each_value { |client| client.instance_variable_set(:@audio, MixedGoalAudio.new(-> { h.now })) }
  h
end

def mixed_audio(h, name); h.clients.fetch(name).instance_variable_get(:@audio); end

def concede_mixed_goal(h, advance: ->(count) { h.advance(count) })
  host = h.clients['Alice'].engine
  server = h.players[host.server]
  assert(!GameRoomParticipants.bot?(server), 'fixture requires a human opening serve')
  h.press(server)
  advance.call(8)
  assert(host.turn == 1, 'mixed-match serve failed')
  receiver = host.rotation.hitter(1)
  player = h.players[receiver]
  engine = h.clients[GameRoomParticipants.bot?(player) ? 'Alice' : player].engine
  engine.ball.merge!('x' => engine.paddles[receiver] < 15 ? 29.0 : 1.0,
    'y' => engine.rotation.team(receiver).zero? ? -0.01 : 20.01)
end

def await_mixed_point(h)
  40.times do
    break if h.clients['Alice'].context_data['pong_point']
    h.advance(1)
  end
  value = h.clients['Alice'].context_data['pong_point']
  assert(value, 'human acknowledgements did not produce a point proposal')
  h.advance(2)
  value
end

def deliver_mixed_point(h, value)
  before = h.replay
  context = GameRoomGames::ActionContext.new(table_owner: 'Alice', local_data: h.clients['Alice'].context_data)
  selection = {'kind' => 'command', 'action' => 'pong_point', 'point' => value}
  assert(h.rules.action_for(selection, before, 'Alice', context: context).first == :ok,
    'early sound bypassed the normal durable rules path')
  h.accept_point(value)
  h.clients.each { |name, client| client.event({'action' => 'pong_point'}, before, h.replay, name, h.repository) }
end

def hold_mixed_point(h)
  channel = h.network['alice']
  original = channel.method(:send_event)
  channel.define_singleton_method(:send_event) do |data|
    @hold_events = JSON.parse(data).dig('d', 'action') == 'point'
    original.call(data)
  ensure
    @hold_events = false
  end
end
