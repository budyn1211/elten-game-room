# encoding: UTF-8
require_relative 'base'
require_relative '../lib/axel_pong/engine'

module GameRoomGames
  class AxelPong < Base
    include PublicHistoryAnnouncements

    def id; 'axel_pong'; end
    def name; _('Axel Pong'); end
    def supports_bots?; true; end
    def supports_bot_move_delay?; false; end
    def supports_saved_games?; false; end
    def shortcut_features; []; end

    def _(source); GameRoomContent.utf8(super(source)); end
    def participant_name(player); GameRoomContent.utf8(super(player)); end

    def option_definitions
      [
        OptionDefinition.new(key: 'arcade', label: _('Arcade: shields and invisible ball'), kind: :boolean, default: false),
        OptionDefinition.new(key: 'difficulty', label: _('Difficulty and ball speed'), kind: :choice, default: 2,
          choices: [_('Easy'), _('Normal'), _('Hard'), _('Insane'), _('Impossible'), _('Nightmare')].each_with_index.map { |label, i| OptionChoice.new(value: i + 1, label: label) }),
        OptionDefinition.new(key: 'target', label: _('Points to win'), kind: :choice, default: 11,
          choices: [7, 11, 21].map { |n| OptionChoice.new(value: n, label: n.to_s) })
      ]
    end

    def build_client(program, **_services)
      require_relative '../lib/axel_pong/client'
      GameRoomPong::Client.new(program, self)
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      owner = session['__insertion_user'].to_s
      owner = session['player_one'].to_s if owner.empty?
      owner = players.first.to_s if owner.empty?
      options = options_from_json(session['options'])
      scores = [0, 0]
      accepted = []
      history = [starting_history(players)]
      winner = nil
      events.each do |event|
        break if winner
        author = event['__insertion_user'] || repository.actor_of(event, session)
        next unless event['action'] == 'pong_point' && same_user?(author, owner)
        match = /\A(\d{1,8}):([01])(:timeout)?\z/.match(event['value'].to_s)
        next unless match && match[1].to_i == accepted.length && players.length == 2
        side = match[2].to_i
        scores[side] += 1
        accepted << event
        event_id = repository.event_id(event)
        if match[3]
          history << HistoryEntry.new(key: "timeout:#{event_id}", event_id: event_id, actor: players[1 - side], kind: :move,
            text: _('%{player} did not serve in time. The opponent receives a point.') % { player: participant_name(players[1 - side]) })
        end
        history << HistoryEntry.new(key: "point:#{event_id}", event_id: event_id, actor: players[side], kind: :move,
          text: _('%{player} scores. %{first}: %{one}; %{second}: %{two}.') % {
            player: participant_name(players[side]), first: participant_name(players[0]), one: scores[0],
            second: participant_name(players[1]), two: scores[1] })
        if scores[side] >= options['target'] && (scores[0] - scores[1]).abs >= 2
          winner = players[side]
          history << result_history(event_id: event_id, winner: winner)
        end
      end
      Replay.new(board: nil, players: players, current_player: nil, winner: winner, draw: false,
        accepted_events: accepted, history: history,
        state: { options: options, scores: scores, rally: accepted.length, owner: owner })
    end

    def action_for(selection, replay, actor, context: nil)
      return [:finished, nil] if replay.finished?
      authority = context && same_user?(context.table_owner, replay.state[:owner]) &&
        (same_user?(actor, context.table_owner) || same_user?(actor, replay.players.first))
      return [:invalid, nil] unless authority &&
        selection['kind'] == 'command' && selection['action'] == 'pong_point'
      point = selection['point']
      expected = context&.local_data&.[]('pong_point')
      return [:invalid, nil] unless point.is_a?(String) && point == expected &&
        /\A#{replay.state[:rally]}:[01](:timeout)?\z/.match?(point)
      [:ok, event_plan('pong_point', point)]
    end

    def automatic_action(replay, _actor, context: nil)
      point = context&.local_data&.[]('pong_point')
      return nil if replay.finished? || point == nil
      { 'kind' => 'command', 'action' => 'pong_point', 'point' => point }
    end

    def automatic_action_due?(replay, actor, context: nil)
      automatic_action(replay, actor, context: context) != nil
    end

    def surface_spec(replay, viewer)
      GameSurfaces::PongSpec.new(game_id: id, players: replay.players.map { |p| participant_name(p) },
        viewer: player_index(replay.players, viewer), scores: replay.state[:scores],
        header: _('Pong playfield'), finished: replay.finished?)
    end

    def custom_game_shortcuts(replay, viewer)
      shortcuts = [
        surface_shortcut(key: 's', label: _('read scores'), command: 'scores'),
        surface_shortcut(key: 't', label: _('read the server and connection status'), command: 'server'),
        surface_shortcut(key: 'c', label: _('read your paddle position'), command: 'position'),
        surface_shortcut(key: 'e', label: _('read active shields and invisible ball'), command: 'effects'),
        surface_shortcut(key: 'e', modifiers: [:shift], label: _('switch echolocation: off, noise, tones'), command: 'echo')
      ]
      if !replay.finished? && replay.players.any? { |p| same_user?(p, viewer) } &&
          replay.players.none? { |p| GameRoomParticipants.bot?(p) }
        shortcuts << surface_shortcut(key: 'w', modifiers: [:control], label: _('hurry the opponent before a serve'), command: 'hurry')
      end
      if defined?(GameRoomPong::Audio::CROWD_ASSETS) && !GameRoomPong::Audio::CROWD_ASSETS.empty?
        shortcuts << surface_shortcut(key: 'c', modifiers: [:shift], label: _('toggle the crowd'), command: 'crowd')
      end
      shortcuts
    end

    def rule_sections
      # Generated from docs/rulebooks/axel_pong.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:origin, GameRoomRules.translate("About this adaptation"),
          GameRoomRules.translate("Axel Pong is not an original project by papierek. The game was originally called Dragon-Pong, was later improved by Axel and balteam, and has now been ported to ELTEN with their permission.")),
        rule_section(:court, GameRoomRules.translate("Follow the ball by sound"),
          GameRoomRules.translate("Axel Pong is an audio paddle game for two players. Move your paddle along your end of the court and return the ball before it passes you. You score one point when your opponent misses. You can play with another person or add a bot to the table. Headphones make it much easier to hear where the ball is."),
          GameRoomRules.translate("Each player hears the court from their own end. A ball to your left sounds on the left; a ball to your right sounds on the right. It grows louder as it approaches you. A side-wall bounce has a higher pitch near your end and a lower pitch near the opponent. Paddle steps also have a pitch cue for position. There is no need to announce every movement: use C when you want to check your paddle's position.")),
        rule_section(:rally, GameRoomRules.translate("Serving and returning"),
          GameRoomRules.translate("Keep focus on the Pong playfield. Hold Left or Right to move, and press Up or Space to serve or hit. To serve diagonally, hold a direction while serving. A return is possible only when the ball is approaching your end and your paddle is close enough to it. A centred hit goes straight; an off-centre hit sends the ball diagonally. Hits speed up the ball, while lateral motion gradually weakens and loses more speed at a wall."),
          GameRoomRules.translate("The first server is chosen at the start of a human match; against a bot, the human starts. Service changes after every two completed points. Choose a target of 7, 11 or 21, with a lead of at least two points required to win. At 10\u201310 in an 11-point match, 11\u201310 is not enough; 12\u201310 wins. After a point there is a three-second break for the goal recording, followed by the score and a further 2.7-second serve delay. You can reposition your paddle during this pause, but serving requires a new press after it ends."),
          GameRoomRules.translate("Automatic return is a personal setting, off by default. When enabled, your paddle returns a reachable ball automatically near your end. You still position the paddle and serve yourself. Open Pong settings with Ctrl+P to change it; your opponent chooses independently."),
          GameRoomRules.translate("The first serve of a human match becomes available after both sides are ready and a three-second countdown. You hear the variant, difficulty and target, then who serves. A bot match starts without this countdown. This does not change the break after subsequent points.")),
        rule_section(:mouse, GameRoomRules.translate("Moving with the mouse"),
          GameRoomRules.translate("On Windows, mouse control is always available in the Pong playfield; you do not need to enable it. Move the mouse mainly left or right to move your paddle in steps; a large sweep does not jump across the court. Click the left mouse button to serve or return the ball. Holding it can also return a reachable ball just before it passes your goal, but it does not automatically serve after the pause between points. Up, Space and the arrow keys still work. As in the original audio mode, a click hits before the mouse movement from the same frame is applied."),
          GameRoomRules.translate("Mouse movement works only while the Pong playfield and the ELTEN window are active. The pointer is kept near the centre of that window so the screen edge does not stop you. Chat, settings, help, another application or a lost connection suspends mouse control. Returning to play discards movement made elsewhere. This option adds no graphics and changes no Windows mouse settings. There is no mouse on/off switch.")),
        rule_section(:arcade, GameRoomRules.translate("Classic and Arcade"),
          GameRoomRules.translate("With Arcade off, play follows the normal rules above. With Arcade on, every paddle return has two independent chances of 7 percent: a shield for the player who returned the ball and an invisible ball. Both may happen on the same hit. A serve alone does not trigger these effects."),
          GameRoomRules.translate("A shield protects the whole goal for ten seconds of play. It returns a missed ball straight ahead without being used up. Winning another shield renews its time to ten seconds. An invisible ball is silent until a paddle returns it or a goal is scored. A shield bounce does not reveal it. Activation and shield expiry have distinct sounds; E reports the current effects. The remaining shield time is preserved between points and does not run down while waiting for a serve.")),
        rule_section(:difficulty, GameRoomRules.translate("Speed and opponents"),
          GameRoomRules.translate("Difficulty and ball speed has six levels: Easy, Normal, Hard, Insane, Impossible and Nightmare. Higher settings start with a faster ball. Against a bot, they also change reaction time, movement, aim and the chance of an error. The bot tracks the visible ball with limited precision and does not track an invisible ball. It may still return an invisible ball if its paddle happens to be in the right place.")),
        rule_section(:personal, GameRoomRules.translate("Your Pong settings"),
          GameRoomRules.translate("Ctrl+P and the Pong settings item in the table menu open the same local panel as the Axel Pong category in Game Room settings. Besides automatic return, you can adjust your paddle movement, the opponent's movement and the recorded announcer separately. Each volume ranges from 0 to 200 percent; 100 percent keeps the original balance, and 0 mutes that group. Game Room's overall volume still applies. Save keeps these values for your future matches on this computer; Cancel leaves them unchanged. They are not table rules and do not change the opponent's settings. The match continues while this panel is open, but its controls do not move your paddle.")),
        rule_section(:echo, GameRoomRules.translate("Finding the sides by sound"),
          GameRoomRules.translate("Shift+E switches echolocation between off, noise and tones. These are additional local sounds that help you judge your paddle's distance from the left and right edges. The nearer an edge is, the louder its cue. This setting does not move your paddle or change what your opponent hears. Game Room's sound-volume and mute controls still apply.")),
        rule_section(:hurry, GameRoomRules.translate("An opponent who does not serve"),
          GameRoomRules.translate("When playing another person, Ctrl+W warns the opponent to serve within ten seconds. It is available only after the normal break, while it is their serve and the ball has not been served yet. A valid serve cancels the warning; otherwise you receive a point. Repeated presses do not extend the deadline, and a new warning cannot be sent for fifteen seconds. Observers cannot issue warnings. A broken connection does not count as a late serve.")),
        rule_section(:connection, GameRoomRules.translate("When the connection is interrupted"),
          GameRoomRules.translate("The table and score use Game Room's normal session; movement uses Communications. During a human match, each player calculates their own flight and return locally. Lost or delayed paddle-position updates alone do not stop the ball. Serves, returns and misses travel separately in order. An actual connection failure pauses the rally; a replacement connection restarts the unfinished point with the confirmed score unchanged. Observers may listen but cannot control a paddle. Unfinished matches cannot currently be saved.")),
        rule_section(:controls, GameRoomRules.translate("Game keyboard shortcuts"),
          GameRoomRules.translate("Left arrow: move the paddle left."),
          GameRoomRules.translate("Right arrow: move the paddle right."),
          GameRoomRules.translate("Up arrow: serve or return the ball."),
          GameRoomRules.translate("Space: serve or return the ball."),
          GameRoomRules.translate("Ctrl+P: open your Pong settings."),
          GameRoomRules.translate("S: read scores."),
          GameRoomRules.translate("T: read the server and connection status."),
          GameRoomRules.translate("C: read your paddle position."),
          GameRoomRules.translate("E: read active shields and invisible ball."),
          GameRoomRules.translate("Shift+E: switch echolocation: off, noise, tones."),
          GameRoomRules.translate("Ctrl+W: hurry the opponent before a serve."))
      ]
    end
  end
end
