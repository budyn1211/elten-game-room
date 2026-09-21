require_relative 'audio_extras'
require_relative 'preferences'

module GameRoomPong
  class Audio
    include AudioExtras
    GOALS = (1..8).map { |n| "pong_goal#{n}" }.freeze
    GOAL_VOICES = (1..4).map { |n| "pong_score#{n}" }.freeze
    ANNOUNCEMENTS = (GOALS + GOAL_VOICES + ['pong_scores'] +
      (0..21).map { |n| "pong_number#{n}" } + %w[pong_goal pong_gamestart pong_youwin pong_theywin]).freeze
    SHIELD_HITS = (1..10).flat_map { |n| ["pong_own_shield_hit#{n}", "pong_op_shield_hit#{n}"] }.freeze
    ASSETS = (%w[pong_ball pong_hit pong_op_hit pong_wall pong_move pong_op_move pong_edge pong_op_edge
      pong_shield_on pong_shield_off pong_shield_hit pong_op_shield_on pong_op_shield_off pong_invisible] +
      SHIELD_HITS + ANNOUNCEMENTS + ECHO_ASSETS + CROWD_ASSETS).freeze
    # Original default: own steps start at 50%; opponent steps settle at 20%
    # after UpdateSounds applies the far-end attenuation. The user selected
    # these proportions instead of increasing both old 25% cues by 10%.
    OWN_MOVEMENT_LEVEL = 0.5
    OPPONENT_MOVEMENT_LEVEL = 0.2
    # Original default opponent steps = 100%; depth gain .2 times 4.55.
    # Independent of the personal score-announcer regulator.
    OPPONENT_SHIELD_HIT_LEVEL = 0.91
    ANNOUNCER_LEVEL = 0.5
    WALL_PITCH = [1.3, 1.15, 1.0, 0.85, 0.7].freeze

    def initialize(program, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, rng: Random.new)
      @program, @clock, @rng = program, clock, rng
      @sounds, @frequencies = {}, {}
      @announcing, @levels, @pans, @score_queue = {}, {}, {}, []
      @echo, @crowd = 'off', false
      reset
    end

    def load
      ASSETS.each do |name|
        sound = @program.create_sound_from_asset(name, loop: name == 'pong_ball' || LOOP_ASSETS.include?(name))
        next unless sound
        @program.manage(sound) if @program.respond_to?(:manage)
        @sounds[name] = sound
        @frequencies[name] = sound.frequency
      end
    end

    def reset
      @last_effect = 0
      @movement_cue_sources = {}
      crowd_reset
      suspend
    end

    def start_match
      return if @started
      @started = true
      play_voice('pong_gamestart')
    end

    # A reliable, mutually agreed miss can sound immediately. The score and
    # match result still come exclusively from an accepted LiveSessions point.
    def goal(viewer:, winner: nil)
      clear_announcements
      crowd_reset
      return unless gain('pong_goal') > 0
      suspend
      goal = GOALS[@rng.rand(GOALS.length)]
      play_announcement(@sounds[goal] ? goal : 'pong_goal')
      play_voice(GOAL_VOICES[@rng.rand(GOAL_VOICES.length)])
      crowd_event(winner == viewer ? 'cheer' : 'epicfail') if winner != nil
    end

    # Original 500 ms voice spacing; a delayed durable write must not replay
    # the goal or add another three-second pause in front of the score.
    def point(scores, viewer:, winner: nil, finished: false, goal_at: nil)
      goal(viewer: viewer, winner: winner) unless goal_at
      return unless gain('pong_goal') > 0
      ordered = viewer == 1 ? scores.reverse : scores
      at = [@clock.call, (goal_at || @clock.call) + 3.0].max
      # The original only records numbers 0..21. Regular speech still reads
      # scores beyond this range; never play a partial, misleading score.
      if ordered.all? { |n| n.is_a?(Integer) && n.between?(0, 21) }
        ['pong_scores', *ordered.map { |n| "pong_number#{n}" }].each_with_index do |name, i|
          @score_queue << [at + i * 0.5, name]
        end
      end
      if finished
        final_at = at + 2.7
        @score_queue << [final_at, winner == viewer ? 'pong_youwin' : 'pong_theywin']
        @crowd_result = [final_at, winner == viewer ? 'won' : 'lost'] if winner != nil
        if ordered.all? { |n| n.is_a?(Integer) && n.between?(0, 21) }
          ['pong_scores', *ordered.map { |n| "pong_number#{n}" }].each_with_index do |name, i|
            @score_queue << [final_at + 0.3 + i * 0.5, name]
          end
        end
      end
    end

    def tick
      now = @clock.call
      if gain('pong_goal') <= 0
        clear_announcements
        @sounds.each_value(&:pause)
        return
      end
      if @crowd_result && now >= @crowd_result[0]
        crowd_event(@crowd_result[1])
        @crowd_result = nil
      end
      @announcing.keys.each do |name|
        sound = @sounds[name]
        finished = sound.respond_to?(:finished?) ? sound.finished? : !sound.playing?
        if finished || now >= @announcing[name]
          sound.pause
          @announcing.delete(name)
        end
      end
      @levels.each do |name, level|
        apply_mix(name, @pans[name], level) if @sounds[name]&.playing?
      end
      # A delayed UI tick must not start/cut three voices in the same frame.
      if @score_queue.first && now >= @score_queue.first[0]
        scheduled, name = @score_queue.shift
        play_voice(name)
        lag = now - scheduled
        @score_queue.each { |entry| entry[0] += lag } if lag > 0.05
      end
    end

    def update(snapshot, viewer:, paused:)
      return suspend unless snapshot
      paddle, ball = snapshot['p'][viewer], snapshot['b']
      pan, volume = spatial(paddle, ball['x'], ball['y'], court_side(snapshot, viewer))
      level = paused || snapshot['invisible'] || ball['dy'] == 0 ? 0 : volume
      loop_sound('pong_ball', pan: pan, level: level)
      update_echo(paddle)
      update_crowd(paused)
      # Update an already ringing impact before processing fresh effects:
      # a new wall contact still starts with its original impact curve.
      if @sounds['pong_wall']&.playing?
        @pans['pong_wall'], @levels['pong_wall'] = pan, volume
        apply_mix('pong_wall', pan, volume)
      end
      snapshot['fx'].each do |number, kind, side, x, y|
        next if number <= @last_effect
        @last_effect = number
        next if paused && !%w[step edge].include?(kind)
        play_effect(kind, side, x, y, snapshot, viewer)
        crowd_event('chant') if kind == 'serve'
        crowd_event('increase') if kind == 'hit'
      end
      update_movement_cues(snapshot, viewer)
    end

    def silence
      suspend
      clear_announcements
    end

    def suspend
      @sounds.each { |name, sound| sound.pause unless ANNOUNCEMENTS.include?(name) }
    end

    def close
      silence
      @sounds.each_value do |sound|
        @program.release(sound) if @program.respond_to?(:release)
        sound.close
      end
      @sounds.clear
    end

    private

    def court_side(snapshot, participant)
      snapshot['teams'] ? snapshot['teams'][participant] : participant
    end

    def update_movement_cues(snapshot, viewer)
      %w[pong_move pong_op_move pong_op_edge].each do |name|
        next unless @sounds[name]&.playing?
        source = @movement_cue_sources[name]
        next if source == nil
        pan, = spatial(snapshot['p'][viewer], snapshot['p'][source],
          court_side(snapshot, source) * 20, court_side(snapshot, viewer))
        @pans[name] = pan
        apply_mix(name, pan, @levels[name])
      end
    end

    # Match SoundMgr._apply_panvol: scale L/R by the master first, then
    # saturate each channel independently. ELTEN/BASS uses linear balance;
    # recover volume + pan from those channel gains without global changes.
    # Keep raw pan/level separately so a later volume change is reversible.
    def apply_mix(name, pan, level)
      volume = [level * personal_gain(name) * gain(name), 0.0].max
      left = [volume * (pan > 0 ? (1 - pan)**1.4 : 1), 1.0].min
      right = [volume * (pan < 0 ? (1 + pan)**1.4 : 1), 1.0].min
      volume = [left, right].max
      pan = volume.zero? ? 0 : (right >= left ? 1 - left / right : right / left - 1)
      @sounds[name].pan, @sounds[name].volume = pan, volume
    end

    def play_effect(kind, side, x, y, snapshot, viewer)
      paddle = snapshot['p'][viewer]
      own = side == viewer
      viewer_side = court_side(snapshot, viewer)
      distance = (viewer_side.zero? ? y : 20 - y).clamp(0, 20)
      pan, volume = spatial(paddle, x, y, viewer_side)
      pitch = 1.0
      case kind
      when 'step', 'edge'
        return if side == nil
        own = court_side(snapshot, side) == viewer_side if kind == 'step'
        x = snapshot['p'][side]
        pan, volume = spatial(paddle, x, court_side(snapshot, side) * 20, viewer_side)
        name = kind == 'step' ? (own ? 'pong_move' : 'pong_op_move') : (own ? 'pong_edge' : 'pong_op_edge')
        @movement_cue_sources[name] = side if kind == 'step' || !own
        volume = own ? OWN_MOVEMENT_LEVEL : OPPONENT_MOVEMENT_LEVEL if kind == 'step'
        pitch = 1.3 - (x.to_i - 15).abs.clamp(0, 14) * (0.6 / 14) if kind == 'step'
      when 'hit', 'serve'
        @sounds['pong_ball'].position = 0 if @sounds['pong_ball']
        name = own ? 'pong_hit' : 'pong_op_hit'
        pan, volume = own ? [0, 1.0] : spatial(paddle, snapshot['p'][side], court_side(snapshot, side) * 20, viewer_side)
      when 'wall'
        name = 'pong_wall'
        pitch = WALL_PITCH[(distance / 4).to_i.clamp(0, 4)]
        volume = distance <= 3 ? 1.0 : [0.95 - (distance - 4) * 0.06, 0].max
      when 'shield_on', 'shield_off'
        name = "pong_#{own ? '' : 'op_'}#{kind}"
        pan, volume = 0, own ? 2.0 : 0.24
        pitch = 0.9438743126816935 unless own
      when 'shield_hit'
        @sounds['pong_ball'].position = 0 if @sounds['pong_ball']
        name = "pong_#{own ? 'own' : 'op'}_shield_hit#{@rng.rand(10) + 1}"
        name = 'pong_shield_hit' unless @sounds[name]
        pan = panorama(x - paddle)
        volume = own ? 2.0 : OPPONENT_SHIELD_HIT_LEVEL
      when 'invisible'
        name = 'pong_invisible'
      else
        return
      end
      play_sound(name, pan: pan, level: volume, pitch: pitch)
    end

    def clear_announcements
      @announcing.each_key { |name| @sounds[name]&.pause }
      @announcing.clear
      @score_queue.clear
      @voice = @crowd_result = nil
    end

    def play_voice(name)
      @sounds[@voice]&.pause if @voice
      @announcing.delete(@voice)
      @voice = play_announcement(name)
    end

    def play_announcement(name)
      sound = play_sound(name, level: ANNOUNCER_LEVEL)
      return unless sound
      duration = sound.respond_to?(:length) ? sound.length.to_f : 3.0
      duration = 3.0 unless duration.finite? && duration > 0
      @announcing[name] = @clock.call + duration.clamp(0.1, 30.0) + 0.25
      name
    end

    def play_sound(name, pan: 0, level: 1.0, pitch: 1.0)
      sound = @sounds[name]
      return unless sound && gain(name) > 0
      @pans[name], @levels[name] = pan, level
      apply_mix(name, pan, level)
      sound.frequency = @frequencies[name] * pitch
      sound.position = 0
      sound.play
      sound
    end

    def loop_sound(name, pan: 0, level:)
      sound = @sounds[name]
      return unless sound
      @pans[name], @levels[name] = pan, level
      apply_mix(name, pan, level)
      if sound.volume > 0
        sound.play unless sound.playing?
      else
        sound.pause if sound.playing?
      end
    end

    def spatial(paddle, x, y, side)
      delta = x - paddle
      pan = panorama(delta)
      distance = side.zero? ? y : 20 - y
      [pan, (1.0 - distance * 0.04).clamp(0, 1)]
    end

    def panorama(delta)
      (Math.sqrt([delta.abs / 25.0, 1.0].min) * (delta.negative? ? -100 : 100)).to_i / 100.0
    end

    def personal_gain(name)
      key = if ANNOUNCEMENTS.include?(name)
        'announcer_volume'
      elsif name == 'pong_move'
        'own_volume'
      elsif %w[pong_op_move pong_op_edge].include?(name)
        'opponent_volume'
      end
      key ? Preferences.read(@program).fetch(key, 100) / 100.0 : 1.0
    end

    def gain(asset)
      return 0.0 if @program.respond_to?(:game_room_sound_enabled?, true) && !@program.send(:game_room_sound_enabled?, asset)
      @program.respond_to?(:game_room_sound_volume, true) ? @program.send(:game_room_sound_volume, asset) : 1.0
    end
  end
end
