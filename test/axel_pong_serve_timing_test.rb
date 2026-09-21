host_source = ENV['ELTEN_HOST_SOURCE'] || File.expand_path('../../elten3', __dir__)
require File.join(host_source, 'src/eapi/speech.rb')
require_relative 'support/pong_client'

def timing_check(name)
  return if ARGV.first && !name.match?(Regexp.new(ARGV.first))
  yield
  puts "PASS #{name}"
end

def advance_to(harness, target, names: harness.clients.keys)
  while harness.now < target
    harness.now = [harness.now + 0.016, target].min
    names.each { |name| harness.clients.fetch(name).frame }
  end
end

def track_service_speech(client, indexed: true)
  messages = []
  client.define_singleton_method(:speech_indexes_supported?) { indexed }
  client.define_singleton_method(:current_speechsequence) { @timing_sequence }
  client.define_singleton_method(:speak) do |value|
    messages << [@clock.call, value]
    @timing_sequence = value.is_a?(EltenAPI::SpeechSequence) ? value : nil
  end
  messages
end

def finish_service_speech(client)
  sequence = client.current_speechsequence
  assert(sequence.is_a?(EltenAPI::SpeechSequence), 'service did not use the native speech sequence')
  sequence.execute(sequence.indexes.last)
end

timing_check('native host speech dispatch releases only on the final index plus 5.4 seconds') do
  h = PongHarness.new(players: ['Alice', 'bot:7:1', 'bot:7:2', 'bot:7:3'], viewers: ['Alice'],
    options: {'team_size' => 2})
  begin
    output = Struct.new(:sequence).new
    def output.indexed_supported?; true; end
    def output.speak_sequence(sequence); self.sequence = sequence; end
    host = h.clients.fetch('Alice')
    host.extend(EltenAPI::Speech)
    host.define_singleton_method(:speech_output) { output }
    host.define_singleton_method(:nvda_output) { nil }
    assert(File.expand_path(host.method(:speak).source_location.first) == File.expand_path(File.join(host_source, 'src/eapi/speech.rb')),
      'native dispatch test replaced the host speech implementation')
    advance_to(h, 20.0)
    sequence = output.sequence
    assert(sequence && host.send(:current_speechsequence).equal?(sequence), 'native speech dispatch lost the tracked sequence')
    sequence.execute(sequence.indexes.first)
    assert(host.paused && host.send(:serve_announcement_waiting?), 'native first index unlocked the service')
    sequence.execute(sequence.indexes.last)
    advance_to(h, 25.399)
    assert(host.paused && host.engine.turn.zero?, 'native completion unlocked before 5.4 seconds')
    advance_to(h, 25.401)
    assert(!host.paused, 'native speech completion never unlocked the service')
  ensure
    h.close
  end
end

timing_check('second doubles serve matches Single timing without an announcement') do
  [false, true].each do |preview|
    single = PongHarness.new(players: ['Alice', 'bot:7:1'], viewers: ['Alice'])
    doubles = PongHarness.new(players: ['Alice', 'bot:7:1', 'bot:7:2', 'bot:7:3'], viewers: ['Alice'],
      options: {'team_size' => 2})
    begin
      messages = {}
      [single, doubles].each do |h|
        advance_to(h, 10.0)
        host = h.clients.fetch('Alice')
        before = h.replay
        host.send(:preview_goal, 0) if preview
        h.accept_point('0:0')
        host.event({'action' => 'pong_point'}, before, h.replay, 'Alice', h.repository) if preview
        messages[h] = track_service_speech(host)
        assert((host.instance_variable_get(:@ready_at) - 15.7).abs < 0.000001,
          'second serve did not use the standard 2.7-second post-score pause')
        advance_to(h, 15.699)
        assert(host.paused, 'second serve ended the standard pause early')
        advance_to(h, 15.701)
        assert(!host.paused, 'second serve added a speech delay to the standard pause')
      end
      assert(messages[doubles].empty?, 'second doubles serve repeated the pairing announcement')
      assert(messages[single].length == 1 && messages[single].first.last.to_s.end_with?(' serves.'),
        'Single lost its ordinary service announcement')
      assert(single.clients['Alice'].instance_variable_get(:@ready_at) == doubles.clients['Alice'].instance_variable_get(:@ready_at),
        'second doubles deadline diverged from Single')
    ensure
      single.close
      doubles.close
    end
  end
end

timing_check('Single initial timing and human-first bot service stay unchanged') do
  h = PongHarness.new(viewers: %w[Alice Bob])
  begin
    messages = h.clients.to_h { |name, client| [name, track_service_speech(client)] }
    advance_to(h, 0.2)
    h.clients.each do |name, client|
      since = client.instance_variable_get(:@initial_ready_since)
      assert(since && (client.instance_variable_get(:@serve_announce_at) - since - 3.0).abs < 0.000001,
        "#{name}: Single lost the initial three-second preparation")
    end
    advance_to(h, 3.0)
    assert(messages.values.all?(&:empty?) && h.clients.values.all?(&:paused), 'Single spoke or resumed before preparation')
    advance_to(h, 3.4)
    assert(h.clients.values.none?(&:paused), 'Single gained a doubles speech-completion delay')
    messages.each_value do |spoken|
      assert(spoken.length == 2 && spoken.none? { |_, value| value.is_a?(EltenAPI::SpeechSequence) },
        'Single settings and server speech acquired indexed doubles handling')
    end
  ensure
    h.close
  end
  [['Alice', 'bot:7:1'], ['bot:7:1', 'Alice']].each do |players|
    h = PongHarness.new(players: players, viewers: ['Alice'])
    begin
      messages = track_service_speech(h.clients['Alice'])
      advance_to(h, 0.016)
      assert(!h.clients['Alice'].paused && h.clients['Alice'].engine.server == players.index('Alice'),
        'Single bot startup no longer serves human-first without the human-match delay')
      assert(messages.length == 1 && messages.first.last == 'Alice serves.', 'Single bot startup speech changed')
    ensure
      h.close
    end
  end
end

timing_check('reconnect invalidates native callbacks without repeating the service block') do
  h = PongHarness.new(players: %w[Alice Bob Carol Dave], options: {'team_size' => 2})
  begin
    advance_to(h, 10.0)
    h.accept_point('0:0')
    h.accept_point('1:0')
    messages = h.clients.to_h { |name, client| [name, track_service_speech(client)] }
    advance_to(h, 16.0)
    stale = h.clients.transform_values(&:current_speechsequence)
    assert(stale.values.all? { |sequence| sequence.is_a?(EltenAPI::SpeechSequence) }, 'reconnect fixture never began indexed speech')
    h.network.each_value { |channel| channel.epoch = 'timing-replacement' }
    advance_to(h, 16.2)
    deadlines = h.clients.transform_values { |client| client.instance_variable_get(:@ready_at) }
    advance_to(h, 20.0)
    stale.each_value { |sequence| sequence.commands.last.execute }
    h.clients.each do |name, client|
      assert(client.instance_variable_get(:@ready_at) == deadlines[name], 'old-generation speech callback changed new readiness')
    end
    advance_to(h, 22.0)
    assert(h.clients.values.none?(&:paused), 'old speech callback left the reconnected match blocked')
    assert(messages.values.all? { |spoken| spoken.length == 1 }, 'reconnect repeated the pairing announcement')
  ensure
    h.close
  end
end

timing_check('guest readiness excludes the owner completion wait') do
  [%w[Alice Bob Carol Dave], ['bot:7:1', 'bot:7:2', 'bot:7:3', 'Bob']].each do |players|
    humans = players.reject { |name| GameRoomParticipants.bot?(name) }
    h = PongHarness.new(players: players, viewers: (['Alice'] + humans).uniq,
      options: {'team_size' => 2})
    begin
      advance_to(h, 10.0)
      h.accept_point('0:0')
      h.accept_point('1:0')
      h.clients.each { |name, client| track_service_speech(client, indexed: name == 'Alice') }
      host = h.clients.fetch('Alice')
      advance_to(h, 22.0)
      finish_service_speech(host)
      advance_to(h, 24.0)
      (humans - ['Alice']).each do |name|
        body = JSON.parse(h.network.fetch(name.downcase).sent.last).fetch('d')
        assert(h.clients[name].paused, 'guest ignored the owner completion wait')
        assert(body['serve_wait'] == false, 'guest fed the owner completion wait back into local readiness')
      end
      advance_to(h, 27.399)
      assert(host.paused && host.engine.turn.zero?, 'remote serve preceded the owner completion delay')
      advance_to(h, 27.6)
      assert(h.clients.values.none?(&:paused), 'independent readiness never released the match')
    ensure
      h.close
    end
  end
end

timing_check('owner readiness never postpones peer pairing announcements') do
  [%w[Alice Bob Carol Dave], %w[Bob Carol Dave Erin], ['bot:7:1', 'bot:7:2', 'bot:7:3', 'Bob']].each do |players|
    humans = players.reject { |name| GameRoomParticipants.bot?(name) }
    h = PongHarness.new(players: players, viewers: (['Alice'] + humans + ['Watcher']).uniq,
      options: {'team_size' => 2, 'team_seats' => [0, 0, 1, 1]})
    begin
      advance_to(h, 10.0)
      h.accept_point('0:0')
      h.accept_point('1:0')
      host = h.clients.fetch('Alice')
      server_name = players[host.engine.server]
      late_name = (humans - ['Alice', server_name]).last || humans.last
      messages = h.clients.to_h do |name, client|
        [name, track_service_speech(client, indexed: [late_name, 'Watcher'].include?(name))]
      end
      advance_to(h, 15.2)
      h.clients.each_key do |name|
        pairing = messages[name].select { |_, value| value.to_s.include?('will serve against') }
        assert(pairing.length == 1 && pairing.first.first.between?(15.0, 15.1),
          "#{name}: owner readiness postponed the independently scheduled pairing")
      end
      advance_to(h, 30.0)
      assert((humans + ['Alice']).uniq.all? { |name| h.clients[name].paused },
        'a required human hearing a long announcement did not hold the service barrier')
      assert(host.engine.turn.zero?, 'a remote human or bot served during required human speech')
      h.press(server_name) if humans.include?(server_name)
      finish_service_speech(h.clients.fetch(late_name))
      advance_to(h, 35.399)
      assert(host.engine.turn.zero? && host.paused, 'remote serve bypassed the late human completion delay')
      advance_to(h, 35.6)
      assert(!host.paused && humans.none? { |name| h.clients[name].paused },
        'readiness feedback deadlocked after every required human completed the delay')
      assert(h.clients.fetch('Watcher').send(:serve_announcement_waiting?),
        'observer fixture completed its speech instead of being excluded from the barrier')
      if humans.include?(server_name)
        assert(host.engine.turn.zero?, 'a press during the speech pause was replayed')
        h.press(server_name)
      end
      advance_to(h, 36.6)
      assert(host.engine.turn > 0, 'service never resumed after the independent completion barriers')
    ensure
      h.close
    end
  end
end

timing_check('post-score pairing keeps the Single announcement schedule') do
  [false, true].each do |preview|
    h = PongHarness.new(players: ['Alice', 'bot:7:1', 'bot:7:2', 'bot:7:3'], viewers: ['Alice'],
      options: {'team_size' => 2})
    begin
      host = h.clients.fetch('Alice')
      messages = track_service_speech(host)
      advance_to(h, 1.0)
      h.accept_point('0:0')
      before = h.replay
      host.send(:preview_goal, 0) if preview
      h.accept_point('1:0')
      host.event({'action' => 'pong_point'}, before, h.replay, 'Alice', h.repository) if preview
      messages.clear
      assert((host.instance_variable_get(:@serve_announce_at) - 6.0).abs < 0.000001,
        'doubles moved its announcement earlier than score time plus two seconds')
      assert((host.instance_variable_get(:@ready_at) - 6.7).abs < 0.000001,
        'base readiness no longer used the standard post-score delay')
      advance_to(h, 5.999)
      assert(messages.empty?, 'pairing interrupted the post-goal score schedule')
      advance_to(h, 6.0)
      assert(messages.length == 1 && host.current_speechsequence, 'pairing missed its scheduled dispatch')
    ensure
      h.close
    end
  end
end

timing_check('non-indexed fallback waits 5.4 seconds from dispatch') do
  h = PongHarness.new(players: ['Alice', 'bot:7:1', 'bot:7:2', 'bot:7:3'], viewers: ['Alice'],
    options: {'team_size' => 2})
  begin
    host = h.clients.fetch('Alice')
    messages = track_service_speech(host, indexed: false)
    advance_to(h, 0.016)
    dispatched_at, text = messages.find { |_, value| value.to_s.include?('will serve against') }
    assert(text.is_a?(String), 'non-indexed fallback dispatched an indexed sequence')
    assert((host.instance_variable_get(:@ready_at) - dispatched_at - 5.4).abs < 0.000001,
      'non-indexed fallback did not start the full delay after dispatch')
    advance_to(h, dispatched_at + 5.399)
    assert(host.paused, 'fallback allowed an early serve')
    advance_to(h, dispatched_at + 5.401)
    assert(!host.paused, 'fallback never unlocked the serve')
  ensure
    h.close
  end
end

timing_check('indexed completion waits twice the shared Single delay') do
  h = PongHarness.new(players: ['Alice', 'bot:7:1', 'bot:7:2', 'bot:7:3'], viewers: ['Alice'],
    options: {'team_size' => 2})
  begin
    host = h.clients.fetch('Alice')
    track_service_speech(host)
    advance_to(h, 20.0)
    assert(host.paused && host.engine.turn.zero?, 'long indexed speech allowed a serve')
    sequence = host.current_speechsequence
    assert(sequence.texts == [sequence.to_s, ''], 'native completion did not follow the full service text')
    sequence.execute(sequence.indexes.first)
    assert(host.send(:serve_announcement_waiting?), 'first native speech index unlocked the serve')
    finish_service_speech(host)
    assert((host.instance_variable_get(:@ready_at) - 25.4).abs < 0.000001,
      'service did not wait 5.4 seconds after actual speech completion')
    assert(GameRoomPong::Client::SINGLE_SERVE_DELAY == 2.7 &&
      GameRoomPong::Client::DOUBLES_SERVE_DELAY == 2 * GameRoomPong::Client::SINGLE_SERVE_DELAY,
      'doubles delay was not derived from the shared standard Single delay')
    advance_to(h, 25.399)
    assert(host.paused && host.engine.turn.zero?, 'serve unlocked before the full completion delay')
    advance_to(h, 25.401)
    assert(!host.paused, 'serve did not unlock after the completion delay')
    deadline = host.instance_variable_get(:@ready_at)
    sequence.commands.last.execute
    assert(host.instance_variable_get(:@ready_at) == deadline, 'repeated callback moved the deadline')
  ensure
    h.close
  end
end
