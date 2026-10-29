require_relative '../support/dealt_card_games'
require_relative '../../lib/game_sounds'
require_relative '../../tools/support/release_files'
include GameRoomTest::Assertions

observed = Hash.new(0)
{'bouillabaisse' => [{}], 'scopa' => [{}, {'escoba' => true}, {'scopone' => true}, {'muerto' => true}]}.each do |id, variants|
  variants.each do |options|
    table = GameRoomTest::DealtCardTable.new(id, options: options, seed: 8)
    opening = table.replay
    cues = GameRoomSounds.event_cue(game: table.game, event: table.events.last, before_replay: nil,
      after_replay: opening, repository: table.repository, viewer: 'Alice', include_result: false)
    assert_equal(id == 'scopa' ? 'scopa_deal' : 'shuffle', cues, 'Opening deal lost its deal cue')
    while table.state[:phase] == :playing
      before = Marshal.load(Marshal.dump(table.replay))
      table.play
      event = table.events.last
      history = GameRoomSounds.history_for_event(table.replay, event, table.repository)
      cues = Array(GameRoomSounds.event_cue(game: table.game, event: event, before_replay: before,
        after_replay: table.replay, repository: table.repository, viewer: 'Alice', include_result: false))
      assert(!cues.include?('draw') && !cues.include?('draw2'), "#{id}: collection sounds like drawing a card")
      assert_equal(history.any? { |entry| entry.kind == :scopa }, cues.include?('scopa'), 'Scopa cue is missing or plays for another event')
      assert_equal(history.any? { |entry| entry.kind == :take }, cues.include?('scopa_take'), 'Capture cue is missing or plays for another event')
      assert_equal(cues.uniq, cues, 'Independent cues played more than once')
      assert(cues.include?('play'), 'Playing a card became silent')
      history.each { |entry| observed[entry.kind] += 1 }
      if (trick = history.find { |entry| entry.kind == :trick })
        assert_equal("#{trick.actor} wins the trick.", trick.text, 'Bouillabaisse has the old collection message')
        assert(!cues.include?('shuffle'), 'Taking a trick sounds like a deal')
      end
      assert_equal(history.any? { |entry| entry.kind == :redeal }, cues.include?('scopa_deal'), 'New hands must sound like a deal, not a draw')
      # Earlier history, including a scopa, must not add cues to an unrelated event.
      silent = GameRoomSounds.event_cue(game: table.game, event: {'id' => 10000, 'action' => 'unknown'},
        before_replay: table.replay, after_replay: table.replay, repository: table.repository,
        viewer: 'Observer', include_result: false)
      assert(silent.nil?, 'A stale scopa was sounded again')
    end
  end
end
[:scopa, :take, :trick, :redeal, :score_breakdown].each { |kind| assert(observed[kind].positive?, "Scenario never reached #{kind}") }

# Awarding the table's leftovers is not a played capture and must stay silent.
table = GameRoomTest::DealtCardTable.new('scopa', options: {'score_limit' => 1000})
state = table.state
state[:current_player], state[:last_capturer] = 'Alice', 'Bob'
state[:hands], state[:table], state[:stock] = {'Alice' => ['AC'], 'Bob' => []}, ['TD'], []
state[:taken], state[:scopas] = {'Alice' => [], 'Bob' => []}, {'Alice' => 0, 'Bob' => 0}
before = Marshal.load(Marshal.dump(table.replay))
event = {'id' => 1000, 'actor' => 'Alice', 'action' => 'play', 'value' => 'AC'}
history = []
assert(table.game.send(:apply_replay_event, state, event, table.session, table.repository, history), 'Final non-capturing play rejected')
assert_equal(%w[TD AC], state[:taken]['Bob'], 'The scenario did not award the leftovers')
cues = table.game.event_sound_cues(event: event, before_replay: before, after_replay: table.replay,
  history: history, viewer: 'Alice', random_variant: GameRoomSounds.method(:random_variant))
assert_equal(['play'], cues, 'Automatic leftover award sounds like a played capture or a scopa')

root = File.expand_path('../..', __dir__)
standalone = JSON.parse(File.read(File.join(root, 'manifest.json'), encoding: 'UTF-8'))
source = File.binread(File.join(root, '__app.rb'))
embedded = JSON.parse(source.split('=begin Elten3AppInfo', 2).last.split('=end Elten3AppInfo', 2).first)
assert_equal(standalone, embedded, 'Sound registration split the manifests')
%w[scopa scopa_deal scopa_take].each do |asset|
  assert(GameRoomSounds::ASSET_NAMES.include?(asset), "#{asset} is not playable")
  assert(standalone.fetch('required_assets').fetch('sounds').include?(asset), "#{asset} is not a required resource")
  path = "Audio/#{asset}.opus"
  assert(GameRoomReleaseFiles.allowed?(path), "Release inventory drops #{path}")
  header = File.binread(File.join(root, path), 128)
  assert(header.start_with?('OggS') && header.include?('OpusHead'), "#{asset} is not encoded as Opus")
end

puts 'PASS dealt-card feedback: real play/capture/trick/redeal/scopa events, no draw cue, independent/deduplicated sounds and required Opus resource'
