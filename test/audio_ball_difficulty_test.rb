require_relative 'support/audio_ball_client'

expected = [[1, 4.0, 1.05], [2, 1.3, 1.10], [3, 0.9, 1.08], [4, 0.6, 1.04]]
game = GameRoomGames::AudioBall.new
choices = game.option_definitions.find { |definition| definition.key == 'difficulty' }.choices
assert(choices.map(&:value) == [1, 2, 3, 4], 'table creation does not offer four difficulty levels')
assert(game.default_options['difficulty'] == 2, 'adding Impossible changed the Normal default')
expected.each do |level, initial, factor|
  assert(game.normalize_options('difficulty' => level)['difficulty'] == level, 'a valid difficulty was normalized to another level')
  [0, 1].each do |server|
    engine = GameRoomAudioBall::Engine.new(level: level, server: server)
    12.times do |hit|
      side = engine.holder
      assert(engine.press(side, 'prepare') && engine.press(side, 'up'), 'difficulty prevented a prepared hit')
      duration = initial / factor**hit
      assert((engine.duration - duration).abs < duration * 1e-10, "level #{level} hit #{hit + 1} has the wrong full-flight duration")
      restored = GameRoomAudioBall::Engine.new
      assert(restored.restore(engine.snapshot), 'the difficulty snapshot cannot round-trip through another engine')
      assert(restored.level == level && restored.duration == engine.duration, 'restoring a snapshot changed its level or speed')
      engine.step(engine.duration * 0.96)
      assert(engine.press(engine.receiver, engine.shot), 'difficulty prevented a legal matching defense')
    end
    assert(GameRoomAudioBall::Engine.new(level: level, server: server).duration == initial, 'a new rally did not reset the initial speed')
    bot = GameRoomAudioBall::Bot.new(server, level: level, rng: Random.new(17))
    engine = GameRoomAudioBall::Engine.new(level: level, server: server)
    assert(bot.step(engine, seconds: 1.0) && engine.phase == :prepared, 'bot cannot prepare at this difficulty')
    assert(bot.step(engine, seconds: 1.0) && engine.phase == :flying, 'bot cannot attack at this difficulty')
  end
  h = AudioBallHarness.new(options: {'difficulty' => level})
  h.advance(12)
  h.press('Alice', 'prepare', 'left')
  h.advance(3)
  assert(h.clients.values.all? { |client| client.engine.level == level && client.engine.duration == initial }, 'clients disagree about the selected difficulty or initial speed')
  h.close
end
assert(GameRoomAudioBall::Bot::HOLD_DELAY[3] == GameRoomAudioBall::Bot::HOLD_DELAY[2] &&
  GameRoomAudioBall::Bot::REACTION_TIME[3] == GameRoomAudioBall::Bot::REACTION_TIME[2] &&
  GameRoomAudioBall::Bot::ERROR_CHANCE[3] == GameRoomAudioBall::Bot::ERROR_CHANCE[2],
  'new ball-speed level unexpectedly changed the hardest existing bot strategy')
assert(game.normalize_options('difficulty' => 5)['difficulty'] == 2, 'an unsupported difficulty was accepted')
puts 'PASS Audio Ball four difficulties: exact initial durations, speed multipliers, both seats, snapshots, new rallies, client options and playable bots'
