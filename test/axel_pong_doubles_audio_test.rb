require_relative '../lib/axel_pong/audio'

class DoublesAudioSound
  attr_accessor :frequency, :volume, :pan, :position
  attr_reader :plays

  def initialize(name, played)
    @name, @played = name, played
    @frequency, @volume, @pan, @plays = 44100, 0, 0, 0
  end

  def play
    @playing = true
    @plays += 1
    @played << @name
  end

  def pause; @playing = false; end
  def playing?; @playing; end
  def finished?; !playing?; end
  def length; 2.0; end
  def close; pause; end
end

class DoublesAudioProgram
  attr_reader :sounds, :played
  attr_accessor :pong_preferences

  def initialize
    @sounds, @played = {}, []
    @pong_preferences = GameRoomPong::Preferences::DEFAULTS.dup
  end

  def create_sound_from_asset(name, loop:)
    @sounds[name] = DoublesAudioSound.new(name, @played)
  end
end

def assert(value, message)
  raise message unless value
end

def near(actual, expected, message)
  assert((actual - expected).abs < 0.000001, "#{message}: #{actual} != #{expected}")
end

def rendered_pan(delta)
  pan = (Math.sqrt([delta.abs / 25.0, 1.0].min) * (delta.negative? ? -100 : 100)).to_i / 100.0
  pan.negative? ? (1 + pan)**1.4 - 1 : 1 - (1 - pan)**1.4
end

def snapshot(teams)
  {'teams' => teams, 'p' => [5.0, 10.0, 20.0, 25.0],
    'b' => {'x' => 15.0, 'y' => 5.0, 'dy' => 1.0}, 'fx' => [], 'invisible' => false}
end

def with_audio(clock: -> { 0.0 })
  program = DoublesAudioProgram.new
  audio = GameRoomPong::Audio.new(program, clock: clock, rng: Random.new(17))
  audio.load
  yield audio, program
ensure
  audio&.close
end

failures = []
checks = 0
check = lambda do |name, &body|
  checks += 1
  body.call
  puts "PASS #{name}"
rescue StandardError => error
  failures << "#{name}: #{error.message}"
end

check.call('doubles ball depth follows teams while pan follows each local paddle') do
  [[0, 0, 1, 1], [0, 1, 0, 1], [1, 0, 1, 0]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        audio.update(state, viewer: viewer, paused: false)
        sound = program.sounds['pong_ball']
        near(sound.volume, teams[viewer].zero? ? 0.8 : 0.4, "team #{teams.inspect}, viewer #{viewer}: wrong depth")
        near(sound.pan, rendered_pan(state['b']['x'] - state['p'][viewer]), "viewer #{viewer}: wrong local paddle")
      end
    end
  end
end

check.call('doubles wall pitch and impact depth use the listener team') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        state['fx'] = [[1, 'wall', nil, 29.0, 5.0]]
        audio.update(state, viewer: viewer, paused: false)
        sound = program.sounds['pong_wall']
        depth = teams[viewer].zero? ? 5 : 15
        near(sound.volume, 0.95 - (depth - 4) * 0.06, "viewer #{viewer}: wrong wall depth")
        near(sound.frequency, 44100 * (teams[viewer].zero? ? 1.15 : 0.85), "viewer #{viewer}: wrong wall pitch")
        near(sound.pan, rendered_pan(29 - state['p'][viewer]), "viewer #{viewer}: wrong impact pan")
        state['b'].merge!('x' => 3.0, 'y' => 15.0)
        state['fx'] = []
        audio.update(state, viewer: viewer, paused: false)
        near(sound.volume, teams[viewer].zero? ? 0.4 : 0.8, "viewer #{viewer}: ringing wall used wrong end")
        near(sound.pan, rendered_pan(3 - state['p'][viewer]), "viewer #{viewer}: ringing wall did not follow ball")
        assert(sound.plays == 1, 'ringing wall restarted')
      end
    end
  end
end

check.call('doubles contacts place teammates near and opponents far without claiming local hits') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        number = 0
        %w[hit serve].each do |kind|
          teams.each_index do |source|
            state['fx'] = [[number += 1, kind, source, 1.0, 10.0]]
            before = program.played.length
            audio.update(state, viewer: viewer, paused: false)
            own = source == viewer
            name = own ? 'pong_hit' : 'pong_op_hit'
            sound = program.sounds[name]
            assert(program.played[before..].include?(name), "viewer #{viewer}, source #{source}: wrong contact voice")
            near(sound.volume, teams[source] == teams[viewer] ? 1.0 : 0.2, "viewer #{viewer}, source #{source}: wrong contact depth")
            near(sound.pan, own ? 0 : rendered_pan(state['p'][source] - state['p'][viewer]), "viewer #{viewer}, source #{source}: wrong contact position")
            near(sound.frequency, 44100, 'contact pitch changed')
          end
        end
      end
    end
  end
end

check.call('doubles edge cues use the actual participant court end') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        teams.each_index do |source|
          state['fx'] = [[source + 1, 'edge', source, 1.0, 10.0]]
          audio.update(state, viewer: viewer, paused: true)
          name = source == viewer ? 'pong_edge' : 'pong_op_edge'
          sound = program.sounds[name]
          assert(sound.playing?, "viewer #{viewer}, source #{source}: edge cue missing during pause")
          near(sound.volume, teams[source] == teams[viewer] ? 1.0 : 0.2, "viewer #{viewer}, source #{source}: wrong edge depth")
        end
      end
    end
  end
end

check.call('doubles footsteps use team samples and gains with each participant position and pitch') do
  [0, 0, 1, 1].permutation.to_a.uniq.each do |teams|
    teams.each_index do |viewer|
      [[100, 100], [40, 150], [150, 25], [0, 150], [150, 0]].each do |own_gain, opponent_gain|
        with_audio do |audio, program|
          program.pong_preferences.merge!('own_volume' => own_gain, 'opponent_volume' => opponent_gain,
            'announcer_volume' => 20)
          state = snapshot(teams)
          state['p'] = [2.0, 9.0, 18.0, 26.0]
          number = 0
          [false, true].each do |paused|
            teams.each_index do |source|
              state['fx'] = [[number += 1, 'step', source, 15, 10]]
              before = program.played.length
              audio.update(state, viewer: viewer, paused: paused)
              friendly = teams[source] == teams[viewer]
              name = friendly ? 'pong_move' : 'pong_op_move'
              sound = program.sounds[name]
              steps = program.played[before..].select { |asset| %w[pong_move pong_op_move].include?(asset) }
              context = "teams #{teams.inspect}, viewer #{viewer}, source #{source}"
              assert(steps == [name], "#{context}: wrong footstep sample #{steps.inspect}, expected #{name}")
              volume = friendly ? 0.5 * own_gain / 100.0 : 0.2 * opponent_gain / 100.0
              near(sound.volume, volume, "#{context}: wrong footstep volume group or baseline")
              pan = volume.zero? ? 0 : rendered_pan(state['p'][source] - state['p'][viewer])
              near(sound.pan, pan, "#{context}: footstep did not use the actual participant position")
              pitch = 1.3 - (state['p'][source].to_i - 15).abs * (0.6 / 14)
              near(sound.frequency, 44100 * pitch, "#{context}: footstep did not use the actual participant pitch")
            end
          end
        end
      end
    end
  end
end

check.call('doubles ringing movement cues independently follow their latest participant') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        teammate = teams.each_index.find { |seat| seat != viewer && teams[seat] == teams[viewer] }
        opponents = teams.each_index.select { |seat| teams[seat] != teams[viewer] }
        sources = {'pong_move' => teammate, 'pong_op_move' => opponents[0], 'pong_op_edge' => opponents[0]}
        state['fx'] = [[1, 'step', teammate, 15, 10], [2, 'step', opponents[0], 15, 10],
          [3, 'edge', opponents[0], 15, 10]]
        audio.update(state, viewer: viewer, paused: false)
        sources.each do |name, source|
          assert(program.sounds[name].playing?, "#{name}: movement cue missing for viewer #{viewer}")
          near(program.sounds[name].pan, rendered_pan(state['p'][source] - state['p'][viewer]), "#{name}: wrong initial source for viewer #{viewer}")
        end
        state['fx'] = [[4, 'step', opponents[1], 15, 10], [5, 'step', viewer, 15, 10]]
        audio.update(state, viewer: viewer, paused: false)
        sources['pong_op_move'] = opponents[1]
        sources['pong_move'] = viewer
        near(program.sounds['pong_move'].volume, 0.5, 'local movement level was lost')
        near(program.sounds['pong_move'].pan, 0, 'local movement was not centred')
        near(program.sounds['pong_move'].frequency, 44100 * (1.3 - (state['p'][viewer].to_i - 15).abs * (0.6 / 14)), 'local movement used a teammate paddle')
        plays = sources.keys.to_h { |name| [name, program.sounds[name].plays] }
        state['p'] = [24.0, 18.0, 7.0, 2.0]
        state['fx'] = []
        audio.update(state, viewer: viewer, paused: false)
        audio.tick
        sources.each do |name, source|
          sound = program.sounds[name]
          near(sound.pan, rendered_pan(state['p'][source] - state['p'][viewer]), "#{name}: ringing cue followed the wrong source for viewer #{viewer}")
          near(sound.volume, name == 'pong_move' ? 0.5 : 0.2, "#{name}: ringing cue changed level")
          assert(sound.plays == plays[name], "#{name}: position update replayed movement")
        end
        assert(program.sounds['pong_move'].plays == 2, 'teammate and local movement did not share the own footstep sample')
        state['fx'] = [[6, 'edge', teammate, 15, 10]]
        audio.update(state, viewer: viewer, paused: false)
        sound = program.sounds['pong_op_edge']
        near(sound.volume, 1.0, 'teammate edge was attenuated to the far end')
        near(sound.pan, rendered_pan(state['p'][teammate] - state['p'][viewer]), 'teammate edge used the previous opponent')
        state['p'] = [4.0, 28.0, 11.0, 22.0]
        audio.update(state, viewer: viewer, paused: false)
        near(sound.pan, rendered_pan(state['p'][teammate] - state['p'][viewer]), 'ringing teammate edge used the previous opponent')
        near(sound.volume, 1.0, 'ringing teammate edge moved to the far end')
        assert(sound.plays == plays['pong_op_edge'] + 1, 'repeated snapshot replayed teammate edge')
      end
    end
  end
end

check.call('doubles friendly footsteps track partner and self switches without replaying position updates') do
  [0, 0, 1, 1].permutation.to_a.uniq.each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        teammate = teams.each_index.find { |seat| seat != viewer && teams[seat] == teams[viewer] }
        sound = program.sounds['pong_move']
        [viewer, teammate, viewer, teammate].each_with_index do |source, number|
          program.pong_preferences.merge!('own_volume' => 100, 'opponent_volume' => 150)
          state['fx'] = [[number + 1, 'step', source, 15, 10]]
          audio.update(state, viewer: viewer, paused: false)
          context = "teams #{teams.inspect}, viewer #{viewer}, source #{source}"
          assert(sound.plays == number + 1, "#{context}: friendly footstep did not use the shared own sample")
          near(sound.pan, rendered_pan(state['p'][source] - state['p'][viewer]), "#{context}: fresh footstep retained the previous source")
          pitch = 1.3 - (state['p'][source].to_i - 15).abs * (0.6 / 14)
          near(sound.frequency, 44100 * pitch, "#{context}: fresh footstep retained the previous pitch")
          sound.position = 0.375
          state['p'].reverse!
          state['fx'] = []
          program.pong_preferences['own_volume'] = 40
          audio.update(state, viewer: viewer, paused: false)
          audio.tick
          near(sound.pan, rendered_pan(state['p'][source] - state['p'][viewer]), "#{context}: ringing friendly footstep followed the wrong participant")
          near(sound.volume, 0.2, "#{context}: ringing friendly footstep ignored the own volume control")
          near(sound.frequency, 44100 * pitch, "#{context}: position-only update changed the footstep pitch")
          near(sound.position, 0.375, "#{context}: position-only update rewound the footstep")
          assert(sound.plays == number + 1, "#{context}: position-only update replayed the footstep")
          program.pong_preferences['own_volume'] = 160
          audio.tick
          near(sound.volume, 0.8, "#{context}: ringing friendly footstep lost its own baseline")
          near(sound.pan, rendered_pan(state['p'][source] - state['p'][viewer]), "#{context}: gain update restored a stale position")
          assert(sound.plays == number + 1, "#{context}: gain update replayed the footstep")
        end
        audio.reset
        state['p'].reverse!
        audio.update(state, viewer: viewer, paused: true)
        assert(!sound.playing? && sound.plays == 4, 'reset resumed a stale friendly footstep')
        state['fx'] = [[1, 'step', viewer, 15, 10]]
        audio.update(state, viewer: viewer, paused: true)
        near(sound.pan, 0, 'first footstep after reset retained the teammate position')
        assert(sound.plays == 5, 'reset did not accept the new footstep sequence')
      end
    end
  end
end

check.call('doubles echo remains anchored to the local participant paddle') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        state['p'] = [1.0, 29.0, 8.0, 22.0]
        audio.cycle_echo
        audio.update(state, viewer: viewer, paused: true)
        [-1, 1].each do |direction|
          edge = direction.negative? ? 1.0 : 29.0
          distance = (state['p'][viewer] - edge).abs
          sound = program.sounds["pong_echo_noise_#{direction.negative? ? 'left' : 'right'}"]
          level = [30.0 - distance * 2, 0].max / 100
          near(sound.volume, level, "viewer #{viewer}: echo used another paddle")
          near(sound.pan, level.zero? ? 0 : rendered_pan(distance * direction), "viewer #{viewer}: echo used another edge")
        end
      end
    end
  end
end

check.call('doubles shields retain local ownership and original nonlocal mix') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      with_audio do |audio, program|
        state = snapshot(teams)
        number = 0
        teams.each_index do |source|
          own = source == viewer
          %w[shield_on shield_off shield_hit].each do |kind|
            x = state['p'][source]
            state['fx'] = [[number += 1, kind, source, x, teams[source].zero? ? 0 : 20]]
            audio.update(state, viewer: viewer, paused: false)
            name = program.played.last
            if kind == 'shield_hit'
              assert(name.start_with?(own ? 'pong_own_shield_hit' : 'pong_op_shield_hit'), 'shield impact confused teammate and local paddle')
              near(program.sounds[name].volume, own ? 1.0 : 0.91, 'shield impact gain changed')
              near(program.sounds[name].pan, rendered_pan(x - state['p'][viewer]), 'shield impact used the wrong paddle position')
            else
              assert(name == "pong_#{own ? '' : 'op_'}#{kind}", 'shield toggle confused teammate and local paddle')
              near(program.sounds[name].volume, own ? 1.0 : 0.24, 'shield toggle gain changed')
              near(program.sounds[name].pan, 0, 'shield toggle pan changed')
              near(program.sounds[name].frequency, 44100 * (own ? 1 : 0.9438743126816935), 'shield toggle pitch changed')
            end
          end
        end
      end
    end
  end
end

check.call('doubles point and goal APIs still accept teams for score order and wins') do
  [[0, 0, 1, 1], [0, 1, 0, 1]].each do |teams|
    teams.each_index do |viewer|
      [0, 1].each do |winner|
        now = 0.0
        with_audio(clock: -> { now }) do |audio, program|
          state = snapshot(teams)
          state['fx'] = [[1, 'goal', winner, 15, 20]]
          audio.update(state, viewer: viewer, paused: true)
          audio.goal(viewer: teams[viewer], winner: winner)
          goals = GameRoomPong::Audio::GOALS.sum { |name| program.sounds[name].plays }
          assert(goals == 1, 'team goal was lost or duplicated')
          audio.point([7, 3], viewer: teams[viewer], winner: winner, finished: true, goal_at: now)
          assert(GameRoomPong::Audio::GOALS.sum { |name| program.sounds[name].plays } == goals, 'durable point repeated the agreed goal')
          program.played.clear
          scores = teams[viewer].zero? ? [7, 3] : [3, 7]
          ordered = ['pong_scores', *scores.map { |score| "pong_number#{score}" }]
          result = teams[viewer] == winner ? 'pong_youwin' : 'pong_theywin'
          expected = [*ordered, result, *ordered]
          # Each recording now gates the next on its own announced length, not a
          # fixed guess, so drain the queue by ticking until it catches up.
          120.times do
            now += 0.25
            audio.tick
            break if program.played.length >= expected.length
          end
          assert(program.played == expected, "viewer #{viewer}: wrong team score/result #{program.played.inspect}")
        end
      end
    end
  end
end

abort(failures.join("\n")) unless failures.empty?
puts "PASS #{checks} doubles audio checks (stub sound handles, no device playback)"
