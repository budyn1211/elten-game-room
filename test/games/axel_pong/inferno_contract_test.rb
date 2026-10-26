require_relative '../../support/realtime_channel'
require_relative '../../../lib/realtime/event_channel'
require_relative '../../support/pong_client'

game = GameRoomGames::AxelPong.new
definition = game.option_definitions.find { |option| option.key == 'difficulty' }
assert(definition.default == 2 && definition.choices.map(&:value) == (1..7).to_a,
  'Inferno changed the default or existing difficulty identifiers')
assert(game.normalize_options('difficulty' => 7)['difficulty'] == 7, 'Inferno is not a stored table option')

# These are the six published profiles, not values copied from new constants.
{
  BASE_SPEED: [0.05, 0.1, 0.15, 0.2, 0.235, 0.323],
  BOT_SPEED: [0.05, 0.1, 0.15, 0.2, 0.253, 0.323],
  BASE_LATERAL: [0.008, 0.02, 0.03, 0.04, 0.047, 0.06],
  BOT_LATERAL: [0.008, 0.02, 0.03, 0.04, 0.051, 0.065],
  WALL: [0.25, 0.30, 0.50, 0.70, 0.85, 0.85],
  INC_MIN: [0.08, 0.08, 0.04, 0.02, 0.02, 0.02],
  INC_MAX: [0.20, 0.15, 0.08, 0.05, 0.05, 0.05]
}.each do |name, expected|
  assert(GameRoomPong::Engine.const_get(name).first(6) == expected, "Existing #{name} profile changed")
end

rosters = [%w[Alice Bob], ['Alice', 'bot:20:1'],
  %w[Alice Bob Carol Dave], ['Alice', 'Bob', 'Carol', 'bot:20:1']]
rosters.each do |players|
  [11, 'custom'].each do |target|
    h = PongHarness.new(players: players, viewers: players.reject { |name| GameRoomParticipants.bot?(name) },
      options: {'difficulty' => 7, 'team_size' => players.length == 4 ? 2 : 0,
        'target' => target, 'custom_target' => 31})
    begin
      mode = (players.length == 4 ? 'pong-doubles-' : 'pong-') +
        (players.any? { |name| GameRoomParticipants.bot?(name) } ? 'mixed-peer-1' : 'peer-2') +
        '-inferno-1' + (target == 'custom' ? '-targets-2' : '')
      assert(h.network.values.all? { |channel| channel.event_protocol == mode },
        'Inferno shares a handshake with clients unable to simulate its physics')
      h.advance(320)
      assert(h.clients.values.none?(&:paused), 'Inferno clients did not become ready')
      assert(h.clients.values.all? { |client| client.engine.level == 7 && client.engine.base_speed == 0.4 },
        'An Inferno participant silently used a lower speed')
    ensure
      h.close
    end
  end
end

ordinary = PongHarness.new(options: {'difficulty' => 6})
begin
  assert(ordinary.network.values.all? { |channel| channel.event_protocol == 'pong-peer-2' },
    'Inferno broke the existing Nightmare handshake')
ensure
  ordinary.close
end

# Exercise the actual channel invitation gate, not just a constructed label.
now, members, work = 0.0, %w[Alice Bob], ChannelWork.new
program = ChannelProgram.new('Bob')
channel = GameRoomRealtime::EventChannel.new(program: program, match: 'inferno', owner: 'Alice', viewer: 'Bob',
  clock: -> { now }, members: -> { members }, work: work, event_work: ChannelWork.new)
begin
  channel.enable_events('pong-peer-2-inferno-1')
  channel.tick; work.finish; channel.tick
  endpoint = program.endpoints.first
  session = ChannelSession.new('inferno-session', 'Bob', members)
  def session.on_reliable(&block); @event_receiver = block; end
  metadata = {'gr_realtime' => 1, 'match' => 'inferno', 'events' => 'pong-peer-2'}
  old = ChannelInvitation.new(session, metadata: metadata)
  endpoint.deliver(old); channel.tick
  assert(old.accepts.zero? && !work.operation, 'Inferno accepted an older client with different physics')
  current = ChannelInvitation.new(session, metadata: metadata.merge('events' => 'pong-peer-2-inferno-1'))
  endpoint.deliver(current); channel.tick; work.finish; channel.tick
  assert(channel.connected? && current.accepts == 1, 'Matching Inferno clients cannot connect')
ensure
  channel.close
end

puts 'PASS Inferno: stable old profiles/defaults, human/bot singles/doubles, targets and strict compatible handshake'
