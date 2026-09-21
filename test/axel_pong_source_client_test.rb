require_relative 'support/pong_client'

# No wall-clock sleeps, real accounts, or hardware input: all timing is driven
# through the actual client frames and protocol encoders.
[%w[Alice Bob], %w[Bob Carol]].each do |players|
  h = PongHarness.new(players: players)
  begin
    # One participant is late. Elapsed time since opening the form is not
    # allowed to consume the first-serve countdown.
    h.advance(120, names: ['Alice'])
    $spoken_messages.clear
    h.advance(160)
    assert(h.clients.values.all?(&:paused), 'first countdown started before peers were ready')
    assert($spoken_messages.empty?, 'announced start before the three-second countdown')
    h.advance(50)
    assert(h.clients.values.none?(&:paused), 'first countdown failed to end')
    speakers = h.clients.size
    difficulty = h.rules.option_definitions.find { |option| option.key == 'difficulty' }.choices[1].label
    settings = GameRoomContent.utf8(_('%{variant}. %{difficulty}. %{points} points to win.')) % {
      variant: _('Classic'), difficulty: difficulty, points: 11 }
    server = GameRoomContent.utf8(_('%{player} serves.')) % {player: players[h.clients['Alice'].engine.server]}
    assert($spoken_messages.count(settings) == speakers, 'start settings missing/duplicated')
    assert($spoken_messages.count(server) == speakers, 'first server missing/duplicated')
    h.advance(30)
    assert($spoken_messages.length == speakers * 2, 'first start was repeated')
    h.accept_point('0:0')
    $spoken_messages.clear
    h.advance(310)
    assert($spoken_messages.empty? && h.clients.values.all?(&:paused), 'ordinary point pause changed')
    h.advance(12)
    assert($spoken_messages.length == speakers, 'ordinary point did not announce server only')
    h.advance(50)
    assert(h.clients.values.none?(&:paused), 'ordinary 5.7-second pause changed')
  ensure
    h.close
  end
end

# A stalled callback cannot collapse settings and serve into the same frame.
h = PongHarness.new
begin
  h.advance(150)
  h.now += 0.8
  $spoken_messages.clear
  h.clients.each_value(&:frame)
  assert($spoken_messages.length == h.clients.size && h.clients.values.all?(&:paused), 'start gap collapsed after delayed UI frame')
  h.advance(7)
  assert(h.clients.values.all?(&:paused), '120 ms gap was shortened')
  h.advance(2)
  assert(h.clients.values.none?(&:paused), 'start did not resume after announcement gap')
ensure
  h.close
end

[%w[Alice Bob], %w[Bob Carol], ['Alice', 'bot:7:1'], ['Bob', 'bot:7:1']].each do |players|
  actor = players.first
  h = PongHarness.new(players: players, preferences: {actor => {'auto_return' => true}})
  begin
    h.advance(220)
    # An observing owner must use the human's personal choice, not its own.
    client = h.clients[actor]
    e = client.engine || h.clients['Alice'].engine
    e.ball.merge!('x' => 15, 'y' => 10)
    assert(e.hit_width(0) > 4, 'personal automatic return not applied') if !players.last.start_with?('bot:')
    assert(e.instance_variable_get(:@automatic)[0] == true, 'human preference missing at authority')
    assert(e.instance_variable_get(:@automatic)[1] == false, 'personal setting affected opponent')
    h.programs[actor].pong_preferences['auto_return'] = false
    h.advance(5)
    assert(e.instance_variable_get(:@automatic)[0] == false, 'saved setting not applied to running rally')
    invalid = {'move'=>0, 'hit'=>false, 'press'=>0, 'auto_return'=>'true'}
    assert(!client.send(:valid_input?, invalid), 'invalid remote preference accepted')
  ensure
    h.close
  end
end

# Bot startup has no human-network countdown; carry actual client feedback,
# not only Engine constructor fixtures, through an accepted point.
h = PongHarness.new(players: ['Alice', 'bot:7:1'])
begin
  h.advance(5)
  assert(!h.clients['Alice'].paused, 'invented countdown in local bot match')
  first = h.clients['Alice'].engine
  first.move_to(1, first.paddles[1] + 0.6)
  expected = first.movement_feedback
  h.accept_point('0:0')
  assert(h.clients['Alice'].engine.movement_feedback == expected, 'bot sound distance reset at first durable point')
  h.clients['Alice'].instance_variable_set(:@epoch, 'replacement')
  h.clients['Alice'].send(:reset_rally)
  assert(h.clients['Alice'].engine.movement_feedback[:distance] == [0.0, 0.0], 'reconnect carried obsolete movement feedback')
ensure
  h.close
end
puts 'PASS source client: first start/countdown, slow UI gap, later serves, independent preferences in four roles, bot step carry/reset'
