require_relative 'engine'
require_relative 'bot'
require_relative 'audio'
require_relative 'mouse'
require_relative '../realtime/event_channel'
require_relative '../realtime/timer'
require_relative '../realtime/task_ui'
require_relative 'peer_play'

module GameRoomPong
  class Client
    SEND_INTERVAL = 0.04
    MAX_PHYSICS_STEPS = 4
    HANDSHAKE_TIMEOUT = 10.0
    STREAM_TIMEOUT = 4.0
    SINGLE_SERVE_DELAY = 2.7
    DOUBLES_SERVE_DELAY = SINGLE_SERVE_DELAY
    attr_reader :engine, :snapshot, :paused
    def _(source); GameRoomContent.utf8(super(source)); end

    def initialize(program, game, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, channel_factory: nil, audio: nil, mouse: nil)
      @program, @game, @clock = program, game, clock
      @channel_factory = channel_factory || ->(**args) { GameRoomRealtime::EventChannel.new(**args) }
      @audio = audio || Audio.new(program, clock: clock)
      @mouse = mouse || MouseControl.new
      @peers = {}
      @sequence = 0
      @next_send = 0.0
      @last_reconnect = -30.0
      @paused = true
      @closed = false
    end

    def bind_screen(session_id:, table_id:, owner:, viewer:, members:)
      @owner, @viewer = owner.to_s, viewer.to_s
      @connection_started_at = @clock.call
      @match = Digest::SHA256.hexdigest("GameRoom:axel_pong:#{table_id}:#{session_id}")[0, 24]
      @channel = @channel_factory.call(program: @program, match: @match, owner: @owner,
        viewer: @viewer, clock: @clock, members: members)
    end

    def start
      unless @program.respond_to?(:communication)
        alert(_('This ELTEN version does not provide Communications.'))
        return false
      end
      # Register the endpoint while loading the recordings. Session metadata
      # is selected by before_wait before any subsequent setup tick.
      @channel.tick
      @audio.load
      true
    end

    def host?; @owner.casecmp?(@viewer); end
    def refresh_due?; false; end
    def context_data; { 'pong_point' => @pending_point }; end
    def action(_selection, _replay, _viewer); false; end
    def error(_status); end
    def automatic_error(_status); end
    def event(event, before, after, viewer, _repository)
      return unless event['action'] == 'pong_point' && before && after
      rally = after.state[:rally]
      return unless rally == before.state[:rally] + 1
      return if rally <= @announced_rally.to_i
      @announced_rally = rally
      # Catch-up can contain many old points. Present the current score only.
      return if @replay && rally < @replay.state[:rally]
      side = after.players.index { |player| player.to_s.casecmp?(viewer.to_s) }
      assignment = @game.team_assignment(after.state[:options], players: after.players)
      perspective = side || observer_side(after.players)
      team = assignment ? assignment.seats[perspective] : perspective
      winner = [0, 1].find { |i| after.state[:scores][i] > before.state[:scores][i] }
      preview = @goal_preview if @goal_preview && @goal_preview[:rally] == before.state[:rally] && @goal_preview[:winner] == winner
      labels = @game.score_labels(after.state[:options], after.players)
      order = team == 1 ? [1, 0] : [0, 1]
      score_text = order.map { |i| "#{labels[i]}: #{after.state[:scores][i]}" }.join('; ') + '.'
      @audio.point(after.state[:scores], viewer: team, winner: winner, finished: after.finished?,
        goal_at: preview && preview[:at], score_text: score_text, result_text: @game.result_text(after), observer: side == nil)
      if preview
        score_at = [@clock.call, preview[:at] + 3.0].max
        @ready_at, @serve_announce_at = score_at + SINGLE_SERVE_DELAY, score_at + 2.0
        if defined?(Log) && Log.respond_to?(:debug)
          Log.debug("Game Room Pong point_confirmed rally=#{before.state[:rally]} elapsed_ms=#{((@clock.call - preview[:at]) * 1000).round}")
        end
      end
      @goal_preview = nil
    end
    def presents_game_event?(event)
      event['action'] == 'pong_point' && @audio.respond_to?(:presents_point) && @audio.presents_point
    end
    def presents_game_result?(replay)
      replay.state[:rally] == @announced_rally && @audio.respond_to?(:presents_point) && @audio.presents_point
    end
    def after_events(replay, viewer, context:); before_wait(replay, viewer); end

    def before_wait(replay, viewer)
      changed = @replay == nil || @replay.state[:rally] != replay.state[:rally]
      @replay = replay
      @players = replay.players
      @audio.prepare_players(@players.length) if @audio.respond_to?(:prepare_players)
      @side = @players.index { |p| p.to_s.casecmp?(viewer.to_s) }
      assignment = @game.team_assignment(replay.state[:options], players: @players)
      @teams = assignment ? assignment.seats : [0, 1]
      @rotation = Rotation.new(teams: @teams, rally: replay.state[:rally], first_server: first_server)
      observer_side(@players) if @side == nil
      @required = @players.reject { |p| GameRoomParticipants.bot?(p) || p.to_s.casecmp?(@viewer) }
      @channel.required_members = host? ? @required : [@owner] if @channel.respond_to?(:required_members=)
      @channel.enable_events('pong-doubles-1') if @rotation.doubles?
      if @players.none? { |p| GameRoomParticipants.bot?(p) } && !is_a?(PeerPlay)
        @channel.enable_events unless @rotation.doubles?
        extend PeerPlay
      end
      reset_rally if changed
      if replay.finished?
        @mouse.suspend
        @audio.suspend
        @channel.close
      end
    end

    def attach_view(form, surface)
      detach_view
      return unless surface.respond_to?(:present) && @replay && !@replay.finished?
      @form, @surface = form, surface
      @surface.on_pong_command = method(:local_command) if @surface.respond_to?(:on_pong_command=)
      @surface.on_input_reset = -> { @mouse.suspend } if @surface.respond_to?(:on_input_reset=)
      @timer = GameRoomRealtime::Timer.new(clock: @clock) { frame }
      @form.add_timer(@timer)
      present
    end

    def detach_view
      @timer&.stop
      @mouse.suspend
      @surface.on_pong_command = nil if @surface.respond_to?(:on_pong_command=)
      @surface.on_input_reset = nil if @surface.respond_to?(:on_input_reset=)
      @form.delete_timer(@timer) if @form && @timer
      @timer = @surface = @form = nil
      @audio.suspend
    end

    def tick
      return if @closed
      @audio.tick
      return if !@replay || @replay.finished?
      @channel.tick
    end

    def network_task_ui(**options)
      GameRoomRealtime::TaskUI.new(**options, clock: @clock, tick: -> {
        # Only an actually updated game form drives its own timer. A chat
        # control passed on its own does not. Never take game input from a
        # network/progress window or the chat-only update path.
        if !@replay || @replay.finished? || (@form && options[:ui].equal?(@form))
          tick
        else
          begin
            @network_wait = true
            frame
          ensure
            @network_wait = false
          end
        end
      })
    end

    def frame
      return if @closed || !@replay || @replay.finished?
      tick
      now = @clock.call
      if @channel.epoch && @epoch != @channel.epoch
        first_local_connection = @epoch == nil && host? && @required.empty?
        @epoch = @channel.epoch
        @epoch_since = now
        @peers.clear
        @sequence = 0
        if first_local_connection
          @engine_epoch = @epoch
        else
          reset_rally unless @rotation.doubles? && awaiting_point?
        end
      end
      receive_packets(now)
      # A live TCP socket is not proof that game callbacks still arrive.
      # A fresh session needs enough time for the native invitation retry (5s).
      # Treating that handshake as a stopped established stream (4s) would tear
      # down a healthy replacement before the other endpoint can accept it.
      deadlines = if host?
        @required.map do |user|
          received = @peers[user.downcase]&.ack_updated_at
          received ? received + STREAM_TIMEOUT : handshake_deadline
        end
      else
        received = @peers[@owner.downcase]&.received_at
        [received ? received + STREAM_TIMEOUT : handshake_deadline]
      end
      if deadlines.compact.any? { |deadline| now > deadline } && now - @last_reconnect > 10
        @last_reconnect = now
        @connection_started_at = now
        @channel.reconnect
      end
      delta = @last_frame ? now - @last_frame : 0
      @last_frame = now
      was_playable = !@paused && @snapshot && @snapshot['goal'] == nil
      raw_input = surface_input
      if host?
        healthy = @required.all? do |user|
          peer = @peers[user.downcase]
          peer && peer.fresh?(now) && peer.ack_fresh?(now) && peer.body['r'] == @replay.state[:rally]
        end
        healthy &&= @channel.connected? unless @required.empty?
        healthy = false if delta < 0
        if !healthy
          @ready_at = @rotation.doubles? ? [@ready_at, now + 1.0].max : now + 1.0
          # Do not ratify a goal first seen only after an actual stream outage.
          # Replace the channel/epoch so both clients restart this rally, and
          # old delayed snapshots cannot reintroduce that unconfirmed goal.
          if @engine.goal && !@pending_point && !@abandoned_goal
            @abandoned_goal = true
            @channel.reconnect
          end
        end
        prepare_first_serve(now, healthy)
        announce_ready(now) if healthy
        waiting = serve_announcement_waiting? || now < @ready_at || peer_service_waiting?
        set_paused(!healthy || @abandoned_goal == true || waiting, waiting: healthy && waiting)
        raw_input = sample_pointer_input(raw_input, healthy)
        local = playable_input(raw_input, active: was_playable && !@paused && @engine.goal == nil, moving: healthy)
        local['move'] = raw_input.fetch('move', 0) if healthy
        inputs = @players.each_with_index.map do |user, side|
          side == @side ? local : (@peers[user.downcase]&.body || {})
        end
        @players.each_index do |side|
          enabled = side == @side ? Preferences.read(@program)['auto_return'] : inputs[side]['auto_return']
          @engine.automatic_for(side, enabled)
        end
        each_physics_frame(now) do |frame_at|
          inputs[@side] = pointer_input(local, frame_at) if @side != nil
          if !@paused && !@engine.goal && frame_at >= @ready_at
            @bots.each { |bot| bot.step(@engine) }
            @engine.step(inputs, now_ms: (frame_at * 1000).to_i)
          elsif healthy
            @engine.position(inputs, now_ms: (frame_at * 1000).to_i)
          end
        end
        @snapshot = @engine.snapshot
        send_state(now)
        commit_goal(now)
      else
        peer = @peers[@owner.downcase]
        # The durable point may arrive before the next live snapshot. A fresh
        # peer from the previous rally is not proof that this rally is ready.
        healthy = @channel.connected? && peer && peer.fresh?(now) && @snapshot &&
          peer.body['r'] == @replay.state[:rally]
        waiting = healthy && peer.body['waiting'] == true
        prepare_first_serve(now, healthy)
        announce_ready(now) if healthy && (!@paused || waiting)
        local_wait = @rotation.doubles? && (serve_announcement_waiting? || now < @ready_at || now < @host_ready_at)
        set_paused(!healthy || peer.body['paused'] != false || local_wait, waiting: waiting || healthy && local_wait)
        raw_input = sample_pointer_input(raw_input, healthy)
        local = playable_input(raw_input, active: was_playable && !@paused && @snapshot['goal'] == nil, moving: healthy)
        local['move'] = raw_input.fetch('move', 0) if healthy
        # A human may face a bot run by an observing table owner. In this
        # case predict only local paddle input, never a second ball/score.
        if @mouse.active?
          each_physics_frame(now) { |at| local = pointer_input(local, at) }
          local = local.merge('paddle' => @mouse.position) if @mouse.position
        end
        send_input(now, local, peer)
      end
      @mouse.finish_frame
      present
    end

    def close
      return if @closed
      @closed = true
      detach_view
      @channel&.close
      @audio.close
    end

    def show_settings
      return if @settings_open
      opened_here = true
      @settings_open = true
      @mouse.suspend
      @program.send(:show_pong_settings, tick: -> { frame }, clock: @clock)
    ensure
      if opened_here
        @mouse.suspend
        @settings_open = false
      end
    end

    private

    def observer_side(players = @players)
      side = players.to_a.index { |player| player.to_s.casecmp?(@observed_player.to_s) }
      @observed_player = players.to_a.first unless side
      side || 0
    end

    def audio_side
      @side || observer_side
    end

    def handshake_deadline
      [@epoch_since, @connection_started_at].compact.max + HANDSHAKE_TIMEOUT
    end

    def awaiting_point?
      @pending_point || (@goal_preview && @goal_preview[:rally] == @replay.state[:rally])
    end

    def preview_goal(winner)
      return if @goal_preview && @goal_preview[:rally] == @replay.state[:rally]
      @goal_preview = { rally: @replay.state[:rally], winner: winner, at: @clock.call }
      @audio.goal(viewer: @rotation ? @rotation.team(audio_side) : audio_side, winner: winner)
    end

    def local_command(command)
      case command
      when 'echo'
        mode = @audio.cycle_echo
        speak({'off' => _('Side-wall cues: off.'), 'noise' => _('Side-wall cues: noise.'),
          'tone' => _('Side-wall cues: tones.')}[mode])
      when 'perspective_first', 'perspective_second', 'perspective_third', 'perspective_fourth'
        return true unless @side == nil && @surface && @form && !@replay.finished?
        return true unless @surface.fields.include?(@form.fields[@form.index.to_i])
        seat = %w[perspective_first perspective_second perspective_third perspective_fourth].index(command)
        return true unless @players[seat]
        @observed_player = @players[seat]
        present
        speak(_('Perspective: %{player}.') % { player: @game.participant_name(@observed_player) })
      when 'crowd'
        if @audio.toggle_crowd
          speak(@audio.crowd ? _('Crowd on.') : _('Crowd off.'))
        end
      when 'hurry'
        unless respond_to?(:request_hurry) && request_hurry
          speak(_('You can hurry your opponent only while waiting for their serve.'))
        end
      end
      true
    end

    def sample_pointer_input(raw, healthy)
      now = @clock.call
      # A modal dialog may suspend this form's timer completely. Never treat
      # motion during that gap as a new game movement on resuming the form.
      if @mouse_sample_at && (now < @mouse_sample_at || now - @mouse_sample_at > Engine::STEP * MAX_PHYSICS_STEPS + 0.000001)
        @mouse.suspend
      end
      @mouse_sample_at = now
      active = healthy && !@settings_open && !@network_wait && @side != nil && @surface && @form &&
        @surface.respond_to?(:input_active?) && @surface.input_active?(@form)
      @mouse.sample(active: active)
      # Keep independent counters: a recreated keyboard field may restart at
      # zero, while mouse clicks must neither vanish nor become extra presses.
      key_count = raw['press']
      keys = if key_count
        key_count >= @pointer_key_count.to_i ? key_count - @pointer_key_count.to_i : key_count
      else
        raw['hit'] && !@pointer_key_held ? 1 : 0
      end
      @pointer_key_count, @pointer_key_held = key_count, raw['hit']
      clicks = @mouse.clicks - @pointer_click_count.to_i
      @pointer_click_count = @mouse.clicks
      @pointer_press = @pointer_press.to_i + keys + [clicks, 0].max
      # ShootBall uses a DOWN edge; the separate goal-line rescue also checks
      # a held left button, exactly like the original held-key rescue.
      raw.merge('press' => @pointer_press, 'hit' => raw['hit'] == true || @mouse.held?)
    end

    def pointer_input(input, at)
      return input unless @side != nil && @snapshot
      position = @engine ? @engine.paddles[@side] : @snapshot['p'][@side]
      @mouse.step(input, position: position, now_ms: (at * 1000).to_i)
    end

    def each_physics_frame(now)
      elapsed = @physics_updated_at && now - @physics_updated_at
      # ELTEN's callbacks do not fall exactly on the original 16 ms grid.
      # Keep the fractional remainder instead of scheduling "now + 16 ms",
      # which turned normal 10/20 ms UI callbacks into 20% slower gameplay.
      # A real suspension is different: discard that time, never replay a
      # whole missed rally or carry a catch-up debt into later callbacks.
      if !@physics_at || (elapsed && (elapsed < 0 || elapsed > Engine::STEP * MAX_PHYSICS_STEPS + 0.000001))
        @physics_at = now
      end
      @physics_updated_at = now
      MAX_PHYSICS_STEPS.times do
        break if now + 0.000001 < @physics_at
        frame_at = @physics_at
        @physics_at += Engine::STEP
        yield frame_at
      end
    end

    def first_server
      human = @players.index { |p| !GameRoomParticipants.bot?(p) }
      return human || 0 if @teams.length == 2 && @players.any? { |p| GameRoomParticipants.bot?(p) }
      # One shared once-per-match choice, like original time parity, but not
      # separately sampled from each computer's potentially incorrect clock.
      @match[-1].to_i(16) % 2
    end

    def playable_input(raw, active:, moving: active)
      active = active == true && !@settings_open
      held = raw['hit'] == true
      increment = if raw.key?('press')
        value = raw['press'] >= @raw_press.to_i ? raw['press'] - @raw_press.to_i : raw['press']
        @raw_press = raw['press']
        value
      else
        held && !@was_hit ? 1 : 0
      end
      @was_hit = held
      # Always consume the raw counter, including the pause and the frame
      # announcing readiness. Only new presses made during play are retained.
      # A held key must be released after the pause, not served by key repeat.
      @hit_blocked = true if !active && held
      @hit_blocked = false unless held
      @total_press = @total_press.to_i + increment if active && !@hit_blocked
      input = { 'move' => active ? raw['move'] : 0, 'hit' => active && !@hit_blocked && held,
        'press' => [@total_press.to_i - @press_base.to_i, 0].max }
      input['aim'] = moving ? raw['aim'] : 0 if raw.key?('aim')
      @raw_directions ||= {}
      @direction_totals ||= {}
      movement_active = moving && !@settings_open && (!@surface || !@surface.respond_to?(:input_active?) || @surface.input_active?(@form))
      KeyboardMovement::COUNTERS.each do |key|
        next unless raw.key?(key)
        count, previous = raw[key], @raw_directions[key].to_i
        delta = count >= previous ? count - previous : count
        @raw_directions[key] = count
        @direction_totals[key] = @direction_totals[key].to_i + (movement_active ? delta : 0)
        input[key] = @direction_totals[key] - (@direction_base || {})[key].to_i
      end
      input
    end

    def reset_rally
      options = @replay.state[:options]
      bots = @players.each_index.select { |i| GameRoomParticipants.bot?(@players[i]) }
      seed = Digest::SHA256.hexdigest("#{@match}:#{@epoch}:#{@replay.state[:rally]}")[0, 12].to_i(16)
      previous = @snapshot
      feedback = @engine&.movement_feedback if @engine && @engine_rally == @replay.state[:rally] - 1 && @engine_epoch == @epoch
      @engine = Engine.new(level: options['difficulty'], arcade: options['arcade'], automatic: local_automatic,
        rally: @replay.state[:rally], bots: bots, rng: Random.new(seed), first_server: first_server, teams: @teams,
        paddles: previous && previous['p'], shields: previous && previous['shields'], movement_feedback: feedback) if host?
      @engine_rally, @engine_epoch = @replay.state[:rally], @epoch
      @bots = bots.map { |side| Bot.new(side, level: options['difficulty'], rng: Random.new(seed + side + 1)) }
      @snapshot = host? ? @engine.snapshot : nil
      reset_rally_feedback
    end

    def reset_rally_feedback
      @serve_speech = @serve_speech_token = nil
      @mouse.reset_rally
      @pending_point = @goal_sequence = nil
      @abandoned_goal = false
      @press_base = @total_press.to_i
      @direction_base = (@direction_totals || {}).dup
      @audio.reset
      @last_frame = nil
      @physics_at = @physics_updated_at = nil
      @next_send = 0.0
      initial = @replay.state[:rally].zero?
      @initial_rally = initial
      @initial_ready_since = nil
      @host_ready_at = 0.0
      @ready_at = initial ? Float::INFINITY : @clock.call + (3.0 + SINGLE_SERVE_DELAY)
      @serve_announce_at = initial ? Float::INFINITY : @clock.call + 5.0
      if @goal_preview && @goal_preview[:rally] == @replay.state[:rally] - 1
        score_at = [@clock.call, @goal_preview[:at] + 3.0].max
        @ready_at, @serve_announce_at = score_at + SINGLE_SERVE_DELAY, score_at + 2.0
      end
      @server_announced = false
      @paused = true
    end

    def receive_packets(now)
      @channel.take_packets.each do |user, packet|
        body = packet['d']
        next unless body['r'] == @replay.state[:rally]
        valid = host? ? valid_input?(body) : valid_state?(body)
        next unless valid
        peer = (@peers[user] ||= GameRoomRealtime::PeerState.new)
        next unless peer.receive(packet, now: now, last_sent: @sequence)
        unless host?
          @snapshot = body['state']
          if @rotation.doubles? && @snapshot['b']['dy'].zero? && body['ready_in']
            @host_ready_at = [@host_ready_at, now + body['ready_in']].max
          end
        end
      end
    end

    def valid_input?(body)
      [-1, 0, 1].include?(body['move']) && [true, false].include?(body['hit']) &&
        (!body.key?('auto_return') || [true, false].include?(body['auto_return'])) &&
        (!body.key?('serve_wait') || [true, false].include?(body['serve_wait'])) &&
        (!body.key?('aim') || [-1, 0, 1].include?(body['aim'])) &&
        KeyboardMovement::COUNTERS.all? { |key| !body.key?(key) || valid_input_count?(body[key]) } &&
        body['press'].is_a?(Integer) && body['press'].between?(0, 2**31 - 1) &&
        (!body.key?('paddle') || finite?(body['paddle'], 1, 29)) &&
        (!body.key?('pointer_seq') || (finite?(body['paddle'], 1, 29) &&
          finite?(body['pointer_before'], 1, 29) &&
          body['pointer_seq'].is_a?(Integer) && body['pointer_seq'].between?(1, 2**31 - 1) &&
          body['pointer_edges'].is_a?(Integer) && body['pointer_edges'].between?(0, 2**31 - 1))) &&
        (!body.key?('pointer_keys') || (body.key?('pointer_seq') && finite?(body['pointer_start'], 1, 29) &&
          body['pointer_keys'].is_a?(Array) && body['pointer_keys'].length <= 3 &&
          body['pointer_keys'].all? { |direction| [-1, 1].include?(direction) }))
    end

    def valid_state?(body)
      data = body['state']
      return false unless [true, false].include?(body['paused']) && data.is_a?(Hash)
      return false if body.key?('ready_in') && !finite?(body['ready_in'], 0, 10)
      return false if body.key?('waiting') && ![true, false].include?(body['waiting'])
      return false if body.key?('serve_wait') && ![true, false].include?(body['serve_wait'])
      return false unless data['tick'].is_a?(Integer) && data['tick'].between?(0, 2**40)
      return false unless @players.each_index.include?(data['server']) && [nil, 0, 1].include?(data['goal'])
      if @rotation.doubles?
        return false unless data['teams'] == @teams && @players.each_index.include?(data['receiver'])
        rotation = Rotation.new(teams: @teams, rally: body['r'], first_server: first_server)
        return false unless data['server'] == rotation.server && data['receiver'] == rotation.receiver
      end
      return false unless [true, false].include?(data['invisible'])
      return false unless data['p'].is_a?(Array) && data['p'].length == @players.length && data['p'].all? { |n| finite?(n, 1, 29) }
      return false if data.key?('edges') && !(data['edges'].is_a?(Array) && data['edges'].length == @players.length &&
        data['edges'].all? { |n| valid_input_count?(n) })
      return false unless data['shields'].is_a?(Array) && data['shields'].length == @players.length && data['shields'].all? { |n| n.is_a?(Integer) && n.between?(0, 625) }
      b = data['b']
      return false unless valid_ball?(b)
      data['fx'].is_a?(Array) && data['fx'].length <= 8 && data['fx'].all? do |fx|
        fx.is_a?(Array) && fx.length == 5 && fx[0].is_a?(Integer) && fx[0] >= 0 &&
          %w[step edge serve hit wall shield_on shield_off shield_hit invisible goal].include?(fx[1]) &&
          (fx[2] == nil || @players.each_index.include?(fx[2])) && finite?(fx[3], 0, 30) && finite?(fx[4], -1000, 1020)
      end
    end

    def valid_ball?(b)
      b.is_a?(Hash) && finite?(b['x'], 0, 30) && finite?(b['y'], -1000, 1020) &&
        finite?(b['speed'], 0, 1000) && finite?(b['lateral'], 0, 1) &&
        [-1, 0, 1].include?(b['dx']) && [-1, 0, 1].include?(b['dy'])
    end

    def finite?(n, lo, hi); n.is_a?(Numeric) && n.finite? && n.between?(lo, hi); end

    def valid_input_count?(n); n.is_a?(Integer) && n.between?(0, 2**31 - 1); end

    def send_state(now)
      return if now < @next_send
      @next_send = now + SEND_INTERVAL
      @sequence += 1
      body = { 'r' => @replay.state[:rally], 'paused' => @paused,
        'waiting' => @waiting_for_serve == true, 'state' => @snapshot }
      if @rotation.doubles?
        body['ready_in'] = [[@ready_at - now, 0.0].max, 10.0].min if @ready_at.finite?
      end
      packet = GameRoomRealtime::Protocol.encode(match: @match, epoch: @epoch, sequence: @sequence, kind: 'state', body: body)
      sent = @channel.send(packet)
      @goal_sequence ||= @sequence if @engine.goal != nil && (sent || @required.empty?)
    end

    def send_input(now, input, peer)
      return unless @epoch && now >= @next_send
      @next_send = now + SEND_INTERVAL
      @sequence += 1
      # Spectators acknowledge for diagnostics, but can never move a paddle.
      body = { 'r' => @replay.state[:rally], 'move' => input['move'], 'hit' => input['hit'], 'press' => input['press'] }
      body['auto_return'] = Preferences.read(@program)['auto_return'] == true
      body['serve_wait'] = serve_announcement_waiting? || now < @ready_at if @rotation.doubles?
      body['paddle'] = input['paddle'] if input.key?('paddle')
      %w[aim left_press right_press pointer_before pointer_seq pointer_edges pointer_start pointer_keys].each do |key|
        body[key] = input[key] if input.key?(key)
      end
      @channel.send(GameRoomRealtime::Protocol.encode(match: @match, epoch: @epoch,
        sequence: @sequence, kind: 'input', body: body, ack: peer ? peer.sequence : 0))
    end

    def commit_goal(now)
      return unless @engine.goal != nil && @goal_sequence && !@abandoned_goal
      return unless @required.all? do |user|
        peer = @peers[user.downcase]
        peer && peer.fresh?(now) && peer.ack >= @goal_sequence
      end
      @pending_point = "#{@replay.state[:rally]}:#{@engine.goal}"
      # The existing automatic-action scheduler writes it through LiveSessions,
      # including its uncertain-write recovery. Never resume a form inside a tick.
    end

    def set_paused(value, waiting: false)
      @waiting_for_serve = waiting
      value = true unless @snapshot
      if @paused != value
        @paused = value
        if value && !waiting
          speak(_('Match paused. Waiting for synchronization.'))
        elsif !value && @snapshot['b']['dy'] != 0
          speak(_('Match resumed.'))
        end
      end
    end

    def announce_ready(now)
      return if @server_announced || now < @serve_announce_at || !@snapshot
      if @initial_rally && @players.none? { |p| GameRoomParticipants.bot?(p) } && !@initial_settings_announced
        @initial_settings_announced = true
        options = @replay.state[:options]
        difficulty = @game.option_definitions.find { |item| item.key == 'difficulty' }.choices[options['difficulty'] - 1].label
        speak(_('%{variant}. %{difficulty}. %{points} points to win.') % {
          variant: options['arcade'] ? _('Arcade') : _('Classic'), difficulty: GameRoomContent.utf8(difficulty), points: options['target'] })
        @serve_announce_at = now + 0.12
        @ready_at = [@ready_at, @serve_announce_at].max
        return
      end
      @server_announced = true
      if @rotation&.doubles?
        rally = @replay.state[:rally]
        return if rally.odd? || @serve_announced_block == rally / 2
        @serve_announced_block = rally / 2
        announce_service_pair(_('%{server} will serve against %{receiver}.') % {
          server: GameRoomContent.utf8(GameRoomParticipants.display_name(@players[@rotation.server])),
          receiver: GameRoomContent.utf8(GameRoomParticipants.display_name(@players[@rotation.receiver])) })
      else
        speak(_('%{player} serves.') % { player: GameRoomContent.utf8(GameRoomParticipants.display_name(@players[@snapshot['server']])) })
      end
      @audio.start_match
    end

    def announce_service_pair(text)
      if defined?(EltenAPI::SpeechSequence) && defined?(EltenAPI::SpeechCommands::CustomCommand) &&
          respond_to?(:speech_indexes_supported?, true) && speech_indexes_supported? &&
          respond_to?(:current_speechsequence, true)
        token = @serve_speech_token = Object.new
        completion = EltenAPI::SpeechCommands::CustomCommand.new { complete_service_speech(token) }
        @serve_speech = EltenAPI::SpeechSequence.new(text, completion)
        speak(@serve_speech)
      else
        speak(text)
        @ready_at = [@ready_at, @clock.call + DOUBLES_SERVE_DELAY].max
      end
    end

    def complete_service_speech(token)
      return if @closed || !token.equal?(@serve_speech_token)
      @serve_speech = @serve_speech_token = nil
      @ready_at = [@ready_at, @clock.call + DOUBLES_SERVE_DELAY].max
    end

    def peer_service_waiting?
      @rotation.doubles? && @engine.turn.zero? &&
        @required.any? { |user| @peers[user.downcase]&.body&.[]('serve_wait') == true }
    end

    def serve_announcement_waiting?
      if @serve_speech && !current_speechsequence.equal?(@serve_speech)
        complete_service_speech(@serve_speech_token)
      end
      @serve_speech != nil
    end

    def prepare_first_serve(now, healthy)
      return unless @initial_rally && !@server_announced
      unless healthy
        @initial_ready_since = nil
        @ready_at = @serve_announce_at = Float::INFINITY
        return
      end
      return if @initial_ready_since
      @initial_ready_since = now
      delay = @players.any? { |p| GameRoomParticipants.bot?(p) } ? 0.0 : 3.0
      @ready_at = @serve_announce_at = now + delay
    end

    def local_automatic
      @players.each_index.map { |side| side == @side && Preferences.read(@program)['auto_return'] == true }
    end

    def surface_input
      raw = @surface && @form && !@network_wait ? @surface.input(@form) : { 'move' => 0, 'hit' => false }
      @settings_open ? raw.merge('move' => 0, 'aim' => 0, 'hit' => false) : raw
    end

    def present
      status = if @waiting_for_serve
        _('Waiting for the next serve.')
      elsif @paused
        _('Match paused. Waiting for synchronization.')
      else
        _('Match in progress.')
      end
      @surface&.present(@snapshot, status)
      @audio.update(@snapshot, viewer: audio_side, paused: @paused)
    end
  end
end
