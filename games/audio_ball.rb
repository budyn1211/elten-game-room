# encoding: UTF-8
require_relative 'base'

module GameRoomGames
  class AudioBall < Base
    include PublicHistoryAnnouncements

    POINTS_TO_WIN = 7
    SET_BREAK = 5

    def id; 'audio_ball'; end
    def name; _('Audio Ball'); end
    def supports_bots?; true; end
    def supports_bot_move_delay?; false; end
    def supports_saved_games?; false; end
    def shortcut_features; []; end

    def _(source); GameRoomContent.utf8(super(source)); end
    def participant_name(player); GameRoomContent.utf8(super(player)); end

    def build_client(program, **_services)
      require_relative '../lib/audio_ball/audio'
      require_relative '../lib/audio_ball/client'
      GameRoomAudioBall::Client.new(program, self)
    end

    def option_definitions
      [
        OptionDefinition.new(key: 'mode', label: _('Game mode'), kind: :choice, default: 'classic',
          choices: [OptionChoice.new(value: 'classic', label: _('Classic'))]),
        OptionDefinition.new(key: 'difficulty', label: _('Difficulty and ball speed'), kind: :choice, default: 2,
          choices: [_('Easy'), _('Normal'), _('Hard')].each_with_index.map { |label, i| OptionChoice.new(value: i + 1, label: label) }),
        OptionDefinition.new(key: 'sets_to_win', label: _('Sets to win'), kind: :choice, default: 1,
          choices: [1, 2, 3].map { |count| OptionChoice.new(value: count, label: count.to_s) })
      ]
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      owner = session['__insertion_user'].to_s
      owner = session['player_one'].to_s if owner.empty?
      owner = players.first.to_s if owner.empty?
      state = { options: options_from_json(session['options']), owner: owner,
        scores: [0, 0], sets: [0, 0], set_number: 1, rally: 0,
        first_server: nil, server: nil, last_point: nil, set_resume_at: nil }
      accepted = []
      history = [starting_history(players)]
      winner = nil
      events.each do |event|
        break if winner
        author = event['__insertion_user'] || repository.actor_of(event, session)
        next unless valid_roster?(players) && same_user?(author, owner)
        value = event['value']
        next unless value.is_a?(String) && value.length <= 64
        case event['action']
        when 'audio_ball_start'
          next unless state[:first_server] == nil && /\A[01]\z/.match?(value)
          state[:first_server] = value.to_i
          accepted << event
        when 'audio_ball_point'
          match = point_match(value, state[:rally])
          next unless state[:first_server] != nil && match && set_ready?(state, event['created_at'])
          side = match[1].to_i
          state[:scores][side] += 1
          state[:rally] += 1
          state[:set_resume_at] = nil
          state[:last_point] = { winner: side, scores: state[:scores].dup,
            set_number: state[:set_number], set_finished: false, match_finished: false, timeout: match[2] != nil }
          accepted << event
          event_id = repository.event_id(event)
          if match[2]
            history << HistoryEntry.new(key: "timeout:#{event_id}", event_id: event_id, actor: players[1 - side], kind: :move,
              text: _('%{player} did not hit the ball in time. The opponent receives a point.') % { player: participant_name(players[1 - side]) })
          end
          history << HistoryEntry.new(key: "point:#{event_id}", event_id: event_id, actor: players[side], kind: :move,
            text: _('%{player} scores. %{first}: %{one}; %{second}: %{two}.') % {
              player: participant_name(players[side]), first: participant_name(players[0]), one: state[:scores][0],
              second: participant_name(players[1]), two: state[:scores][1] })
          if state[:scores][side] >= POINTS_TO_WIN && state[:scores][side] - state[:scores][1 - side] >= 2
            state[:sets][side] += 1
            state[:last_point][:set_finished] = true
            history << HistoryEntry.new(key: "set:#{event_id}", event_id: event_id, actor: players[side], kind: :set,
              text: _('%{player} wins set %{set}. Sets: %{first}: %{one}; %{second}: %{two}.') % {
                player: participant_name(players[side]), set: state[:set_number], first: participant_name(players[0]),
                one: state[:sets][0], second: participant_name(players[1]), two: state[:sets][1] })
            if state[:sets][side] >= state[:options]['sets_to_win']
              winner = players[side]
              state[:last_point][:match_finished] = true
              history << result_history(event_id: event_id, winner: winner)
            else
              state[:set_number] += 1
              state[:scores] = [0, 0]
              state[:set_resume_at] = event['created_at'].to_i + SET_BREAK if event['created_at']
            end
          end
        end
      end
      state[:server] = (state[:first_server] + state[:rally] / 2) % 2 unless state[:first_server] == nil
      Replay.new(board: nil, players: players, current_player: nil, winner: winner, draw: false,
        accepted_events: accepted, history: history, state: state)
    end

    def action_for(selection, replay, actor, context: nil)
      return [:finished, nil] if replay.finished?
      return [:invalid, nil] unless valid_roster?(replay.players) && owner_authority?(replay, actor, context)
      return [:invalid, nil] unless selection['kind'] == 'command'
      if selection['action'] == 'audio_ball_start' && replay.state[:first_server] == nil && context.random_source
        first_server = context.random_source.roll(count: 1, sides: 2).values.first - 1
        return [:ok, event_plan('audio_ball_start', first_server)]
      end
      if selection['action'] == 'audio_ball_point' && replay.state[:first_server] != nil
        return [:invalid, nil] unless set_ready?(replay.state, context.now)
        point = selection['point']
        expected = context.local_data&.[]('audio_ball_point')
        return [:ok, event_plan('audio_ball_point', point)] if point == expected && point_match(point, replay.state[:rally])
      end
      [:invalid, nil]
    end

    def automatic_action(replay, actor, context: nil)
      return nil if replay.finished? || !valid_roster?(replay.players) || !owner_authority?(replay, actor, context)
      return { 'kind' => 'command', 'action' => 'audio_ball_start' } if replay.state[:first_server] == nil
      return nil unless set_ready?(replay.state, context.now)
      point = context.local_data&.[]('audio_ball_point')
      return { 'kind' => 'command', 'action' => 'audio_ball_point', 'point' => point } if point_match(point, replay.state[:rally])
      nil
    end

    def automatic_action_due?(replay, actor, context: nil)
      automatic_action(replay, actor, context: context) != nil
    end

    def options_error(_options, player_count: nil)
      _('Audio Ball requires exactly two players.') if player_count != nil && player_count != 2
    end

    def participant_scores(replay)
      scores = replay.state[replay.state[:options]['sets_to_win'] > 1 ? :sets : :scores]
      replay.players.each_with_index.to_h { |player, index| [player, scores[index]] }
    end

    def surface_spec(replay, viewer)
      GameSurfaces::AudioBallSpec.new(game_id: id, header: _('Audio Ball playfield'),
        players: replay.players.map { |player| participant_name(player) }, viewer: player_index(replay.players, viewer),
        scores: replay.state[:scores], sets: replay.state[:sets], set_number: replay.state[:set_number], finished: replay.finished?)
    end

    def custom_game_shortcuts(replay, viewer)
      shortcuts = [
        surface_shortcut(key: 's', modifiers: [:shift], label: _('read points and sets'), command: 'scores'),
        surface_shortcut(key: 't', label: _('read the server and connection status'), command: 'server')
      ]
      if !replay.finished? && player_index(replay.players, viewer) != nil
        shortcuts << surface_shortcut(key: 'w', modifiers: [:control], label: _('hurry the opponent holding the ball'), command: 'hurry')
      end
      shortcuts
    end

    def rule_sections
      # Generated from docs/rulebooks/audio_ball.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:court, GameRoomRules.translate("Three shots, one opponent"),
          GameRoomRules.translate("Audio Ball is an audio game for exactly two players, one against one. Play another person or a bot. Classic is currently the only mode. You score a point when the opponent fails to defend your shot. Headphones help you follow the ball and distinguish the three shot sounds."),
          GameRoomRules.translate("The playing area is 25 steps wide. By default, each player hears their own end on the right and the opponent's end on the left. You can reverse your listening perspective in the personal settings without changing the opponent's sound.")),
        rule_section(:shots, GameRoomRules.translate("Choose a lane, defend, then hit"),
          GameRoomRules.translate("There are three lanes, one for each shot sound. After the opponent hits a new ball, Up arrow or W selects the first lane, Left arrow or D the second, and Down arrow or S the third. You only need to press once for that incoming flight. After releasing the key, you stay in the selected lane. If the ball matches that lane, you defend automatically when it is no more than two steps from your end. You do not need to hold the key or press it again at contact."),
          GameRoomRules.translate("Every new incoming hit clears the previous defensive choice. You must press a lane key again even when the opponent repeats exactly the same shot. Without that new press, the ball passes you. Your previous defence, your own attack, a key already held down, or a choice made before the opponent hits do not arm the next defence. During the current flight, the latest accepted choice replaces the previous one. If you are in the wrong lane, you can still change it before the ball passes."),
          GameRoomRules.translate("After defending, you hold the ball. Press Right arrow or A to prepare, then press one of the three shot keys to hit. The server must also prepare before serving. A defence only catches the ball: it does not automatically send it back. An attack does not select the lane for a later incoming ball. Keep focus on the Audio Ball playfield when using these controls. Each new attack needs a fresh press; a selected defensive lane or a key still held after preparation does not hit automatically.")),
        rule_section(:pace, GameRoomRules.translate("Ball speed and holding the ball"),
          GameRoomRules.translate("Difficulty and ball speed offers Easy, Normal and Hard; Normal is the default. The first flight takes 1.5 seconds on Easy, 1.2 seconds on Normal and 0.9 seconds on Hard. Each later shot in the rally increases speed by 10 percent on Easy and Normal, or 8 percent on Hard. A new point returns to the initial speed."),
          GameRoomRules.translate("You have unlimited time while holding the ball, before a serve or after a defence, unless the opponent presses Ctrl+W. That warning gives the holder ten seconds to actually hit the ball. Preparing does not cancel the warning or restart its timer; only hitting does. If time runs out, the opponent receives a point. Repeated warnings do not extend the active deadline. Observers cannot hurry either player.")),
        rule_section(:match, GameRoomRules.translate("Service, sets and victory"),
          GameRoomRules.translate("The first server is chosen at random once for the match, also against a bot. Service changes after every two completed points. This two-point sequence continues between sets and at deuce; it never changes to one serve each."),
          GameRoomRules.translate("Every set requires at least 7 points and a two-point lead. At 6:6, 7:6 is not enough; 8:6 wins the set. Sets to win can be 1, 2 or 3, with 1 as the default. The first player to win that many sets wins the match. Points start at zero in the next set, while won sets remain. The final set's score stays available after the match."),
          GameRoomRules.translate("There is a five-second break between sets. The game announces the first set, second set and later sets, together with the server. Shift+S reads points and won sets; T reads the server and connection status. Unfinished Audio Ball matches cannot be saved."),
          GameRoomRules.translate("Goals use Axel Pong goal effects and goal-announcer recordings. The recorded score introduction is followed by your number and the opponent's number, without overlapping the voices. Scores from 0 to 21 use Pong recordings; if either score is higher or a required recording is missing, Elten speech reads the complete score instead. Observers hear the table's player order. Ordinary points have a 5.7-second restart pause; the break between sets remains five seconds. Set and match information is announced without making gameplay depend on a speech completion callback.")),
        rule_section(:personal, GameRoomRules.translate("Your listening side"),
          GameRoomRules.translate("Ctrl+P and Audio Ball settings in the table menu open your personal settings before or during a match. Right is the default: your attacks travel from right to left and incoming balls from left to right. Choose Left to reverse both flight and preparation sounds only for you. The change is saved locally and does not alter player identities, controls, scores or table rules."),
          GameRoomRules.translate("Save keeps the selected listening side for future matches; Cancel preserves the previous setting. The match continues while the settings window is open. A defence already armed for the current ball remains active, but a new opponent hit requires a new playfield press. Dialog keys do not arm or change a defence. Close the window to return to the playfield controls.")),
        rule_section(:controls, GameRoomRules.translate("Audio Ball keyboard shortcuts"),
          GameRoomRules.translate("Up arrow: select the first lane for this incoming ball, or make the first shot after preparing."),
          GameRoomRules.translate("W: select the first lane for this incoming ball, or make the first shot after preparing."),
          GameRoomRules.translate("Left arrow: select the second lane for this incoming ball, or make the second shot after preparing."),
          GameRoomRules.translate("D: select the second lane for this incoming ball, or make the second shot after preparing."),
          GameRoomRules.translate("Down arrow: select the third lane for this incoming ball, or make the third shot after preparing."),
          GameRoomRules.translate("S: select the third lane for this incoming ball, or make the third shot after preparing."),
          GameRoomRules.translate("Right arrow: prepare to serve or to hit after defending."),
          GameRoomRules.translate("A: prepare to serve or to hit after defending."),
          GameRoomRules.translate("Shift+S: read points and won sets."),
          GameRoomRules.translate("T: read the server and connection status."),
          GameRoomRules.translate("Ctrl+W: give the opponent holding the ball ten seconds to hit."),
          GameRoomRules.translate("Ctrl+P: choose your listening side."))
      ]
    end

    private

    def set_ready?(state, now)
      state[:set_resume_at] == nil || now == nil || now.to_f >= state[:set_resume_at]
    end

    def point_match(value, rally)
      /\A#{rally}:([01])(:timeout)?\z/.match(value) if value.is_a?(String) && value.length <= 64
    end

    def valid_roster?(players)
      players.length == 2 && GameRoomParticipants.unique(players).length == 2
    end

    def owner_authority?(replay, actor, context)
      context && same_user?(context.table_owner, replay.state[:owner]) &&
        (same_user?(actor, context.table_owner) || same_user?(actor, replay.players.first))
    end
  end
end
