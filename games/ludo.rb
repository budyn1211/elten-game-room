require_relative "../lib/game_bots"
require_relative "base"

module GameRoomGames
  class Ludo < Base
    PAWNS_PER_PLAYER = 4
    OUTER_LENGTH = 52
    FINISH_PROGRESS = 57
    HOME_LANE_LENGTH = FINISH_PROGRESS - OUTER_LENGTH + 1
    ENTRY_INDICES = [0, 13, 26, 39].freeze
    SAFE_TRACK_INDICES = ENTRY_INDICES.freeze
    PAWN_MOVE_ACTION = "move_pawn"

    def id
      "ludo"
    end

    def name
      _("Ludo")
    end

    def minimum_players
      2
    end

    def maximum_players
      4
    end

    def supports_bots?
      true
    end

    def bot_strategy
      @bot_strategy ||= GameRoomBots::HeuristicStrategy.new
    end

    def option_definitions
      [
        OptionDefinition.new(key: "enter_on_six", label: _("A 6 is required to leave the base"), kind: :boolean, default: true),
        OptionDefinition.new(key: "extra_on_six", label: _("Roll again after a 6"), kind: :boolean, default: true),
        OptionDefinition.new(key: "exact_finish", label: _("An exact roll is required to reach the finish"), kind: :boolean, default: true),
        OptionDefinition.new(key: "three_sixes", label: _("Three consecutive sixes lose the turn"), kind: :boolean, default: true),
        OptionDefinition.new(key: "blockades", label: _("Two pawns of one player form a blockade"), kind: :boolean, default: true)
      ]
    end

    def options_summary(_options)
      _("classic rules; four pawns per player")
    end

    def rule_sections
      [
        rule_section(:goal, _("Goal"), _("Move all four of your pawns from the base, around the shared track, through your private home lane and to the finish before the other players.")),
        rule_section(:setup, _("Setup"), _("Two to four players each receive four pawns. With the classic defaults, a player must roll a 6 to move a pawn out of the base."), _("The players' starting fields, in seating order, are 1, 14, 27 and 40 on the same shared track."), _("The shared track has 52 numbered fields. After field 52 comes field 1, so every player travels the same distance despite starting at a different number."), _("After completing the shared track, each player enters a private six-field home lane. Reaching its end places the pawn at the finish, where it no longer moves.")),
        rule_section(:play, _("How to play"), _("Press Enter on the pawn list to roll. If exactly one pawn can move, it moves automatically. If several pawns can move, the list shows only those choices together with their destinations; use the Arrow keys and Enter to choose."), _("Landing on an opposing pawn outside a safe start field sends it back to its base. Two pawns of one player form a blockade."), _("A 6 gives another roll. Three consecutive sixes end the turn. The finish must be reached by an exact roll.")),
        rule_section(:ending, _("Ending the game"), _("The first player to place all four pawns at the finish wins.")),
        rule_section(:variants, _("Variants and table options"), _("The default settings are the classic rules. The table creator may change entry, extra-roll, exact-finish, three-sixes and blockade rules.")),
        rule_section(:controls, _("Controls"), _("Press Enter on the pawn list to roll or to choose a displayed move. Press P for your pawn positions, Shift+P for the opponents' pawn positions, T for the turn and Ctrl+F1 for these rules."))
      ]
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      options = options_from_json(session["options"])
      state = initial_state(players, options)
      accepted = []
      history = [starting_history(players)]

      events.each do |event|
        break if state[:winner] != nil
        actor = repository.actor_of(event, session)
        next if !same_user?(actor, state[:current_player])

        applied = case event["action"].to_s
        when "roll"
          apply_roll!(state, event, actor, repository, history)
        when PAWN_MOVE_ACTION
          apply_pawn_move!(state, event, actor, repository, history)
        when "move"
          apply_legacy_pawn_move!(state, event, actor, repository, history)
        else
          false
        end
        accepted << event if applied
      end

      Replay.new(
        board: board_snapshot(state), players: players, current_player: state[:current_player], winner: state[:winner],
        draw: false, accepted_events: accepted, history: history, state: state
      )
    end

    def legal_actions(replay, actor, context: nil)
      return [] if replay.finished? || !same_user?(replay.current_player, actor)
      return [{ "kind" => "dice", "action" => "roll" }] if replay.state[:phase] == :awaiting_roll

      player = player_index(replay.state[:players], actor)
      legal_pawn_indices(replay.state, player).map do |pawn|
        { "kind" => "pawn", "action" => "move", "pawn" => pawn.to_s }
      end
    end

    def surface_spec(replay, viewer)
      state = replay.state
      player = player_index(state[:players], viewer)
      own_turn = !replay.finished? && same_user?(state[:current_player], viewer)
      choosing = own_turn && state[:phase] == :moving
      items = if choosing
        move_choice_items(state, player)
      elsif player == nil
        spectator_status_items(state)
      else
        pawn_status_items(state, player)
      end
      activation_action = if own_turn && state[:phase] == :awaiting_roll
        GameSurfaces::Action.new(kind: "dice", name: "roll", source: "ludo_pawns")
      end
      GameSurfaces::PawnTrackSpec.new(
        id: "ludo_pawns",
        header: pawn_track_header(replay, viewer),
        items: items,
        empty_label: _("No pawns to display"),
        activation_action: activation_action
      )
    end

    def describe_event(event, repository, replay, _viewer)
      event_id = repository.event_id(event).to_i
      spoken_kinds = [:roll, :move, :capture, :pass, :turn_end]
      replay.history.filter_map do |entry|
        entry.text if entry.event_id.to_i == event_id && spoken_kinds.include?(entry.kind)
      end
    end

    def action_for(selection, replay, actor, context: nil)
      state = replay.state
      return [:finished, nil] if replay.finished?
      return [:not_your_turn, nil] if !same_user?(replay.current_player, actor)
      if ["dice", "command"].include?(selection["kind"].to_s) && selection["action"].to_s == "roll"
        return [:invalid, nil] if state[:phase] != :awaiting_roll || context == nil || context.random_source == nil

        value = context.random_source.roll(count: 1, sides: 6).values.first.to_i
        return [:ok, event_plan("roll", value.to_s)]
      end
      return [:invalid, nil] if state[:phase] != :moving
      return [:invalid, nil] if selection["kind"].to_s != "pawn" || selection["action"].to_s != "move"

      player = player_index(state[:players], actor)
      pawn_value = selection["pawn"].to_s
      return [:invalid_move, nil] if !/\A\d+\z/.match?(pawn_value)
      pawn = pawn_value.to_i
      return [:invalid_move, nil] if !legal_pawn_indices(state, player).include?(pawn)

      [:ok, event_plan(PAWN_MOVE_ACTION, pawn.to_s)]
    end

    def move_error(status)
      return _("This pawn cannot move after the current roll.") if status == :invalid_move

      super
    end

    def bot_action_score(replay, actor, action, context: nil)
      return 0.0 if action["action"].to_s == "roll"

      state = replay.state
      player = player_index(state[:players], actor)
      pawn = action["pawn"].to_i
      return -10_000.0 if !legal_pawn_indices(state, player).include?(pawn)

      before = state[:pawns][player][pawn]
      after = destination_progress(state, player, pawn)
      score = after - before
      score += 1_000 if after == FINISH_PROGRESS
      score += 240 if before < 0
      score += 400 if capture_targets(state, player, after).any?
      score += 80 if safe_progress?(player, after)
      score -= exposure_risk(state, player, after) * 35
      score
    end

    def bot_position_value(replay, actor)
      return bot_reward(replay, actor) * 1_000_000.0 if replay.finished?
      player = player_index(replay.players, actor)
      own = replay.state[:pawns][player].sum { |progress| progress < 0 ? -8 : progress }
      others = replay.state[:pawns].each_with_index.reject { |_pawns, index| index == player }
        .sum { |pawns, _index| pawns.sum { |progress| progress < 0 ? -8 : progress } }
      own * 5.0 - others * 2.0
    end

    def bot_search_key(replay, actor)
      state = replay.state
      "#{player_index(replay.players, actor)}:#{player_index(replay.players, replay.current_player)}:#{state[:phase]}:#{state[:roll]}:#{state[:pawns].flatten.join(',')}"
    end

    def custom_game_shortcuts(replay, viewer)
      [
        announcement_shortcut(
          key: "p",
          label: _("read your pawn positions"),
          message: pawn_positions_text(replay.state, viewer)
        ),
        GameShortcut.new(
          key: "p",
          modifiers: [:shift],
          label: _("read the opponents' pawn positions"),
          kind: :announcement,
          message: opponents_pawn_positions_text(replay.state, viewer)
        )
      ]
    end

    private

    def pawn_track_header(replay, viewer)
      state = replay.state
      if replay.finished?
        _("Your pawns. The game has ended")
      elsif same_user?(state[:current_player], viewer) && state[:phase] == :awaiting_roll
        _("Your pawns. Press Enter to roll the die")
      elsif same_user?(state[:current_player], viewer) && state[:phase] == :moving
        _("You rolled %{value}. Choose a pawn to move") % { value: state[:roll] }
      elsif player_index(state[:players], viewer) == nil
        _("Pawns. Waiting for %{player}") % { player: participant_name(state[:current_player]) }
      else
        _("Your pawns. Waiting for %{player}") % { player: participant_name(state[:current_player]) }
      end
    end

    def move_choice_items(state, player)
      legal_pawn_indices(state, player).map do |pawn|
        GameSurfaces::PawnTrackItem.new(
          id: "move:#{pawn}",
          label: move_choice_label(state, player, pawn),
          action: GameSurfaces::Action.new(
            kind: "pawn", name: "move", payload: { "pawn" => pawn.to_s }, source: "ludo_pawns"
          )
        )
      end
    end

    def move_choice_label(state, player, pawn)
      before = state[:pawns][player][pawn]
      after = destination_progress(state, player, pawn)
      label = _("Pawn %{pawn}: %{from}; will move to %{to}") % {
        pawn: pawn + 1,
        from: progress_label(player, before),
        to: progress_label(player, after)
      }
      captures = capture_targets(state, player, after).length
      if captures == 1
        label = _("%{move}; captures an opposing pawn") % { move: label }
      elsif captures > 1
        label = _("%{move}; opposing pawns captured: %{count}") % { move: label, count: captures }
      end
      label = _("%{move}; safe field") % { move: label } if after < OUTER_LENGTH && safe_progress?(player, after)
      label
    end

    def pawn_status_items(state, player)
      pawn_status_labels(state, player).each_with_index.map do |label, index|
        GameSurfaces::PawnTrackItem.new(id: "status:#{player}:#{index}", label: label)
      end
    end

    def spectator_status_items(state)
      state[:players].each_index.flat_map do |player|
        pawn_status_labels(state, player).each_with_index.map do |label, index|
          GameSurfaces::PawnTrackItem.new(
            id: "status:#{player}:#{index}",
            label: _("%{player}: %{position}") % { player: participant_name(state[:players][player]), position: label }
          )
        end
      end
    end

    def pawn_status_labels(state, player)
      pawns = state[:pawns][player]
      labels = []
      base_pawns = pawns.each_index.select { |pawn| pawns[pawn] < 0 }.map { |pawn| pawn + 1 }
      labels << _("Pawns in base: %{pawns}") % { pawns: base_pawns.join(", ") } if !base_pawns.empty?
      pawns.each_with_index do |progress, pawn|
        next if progress < 0 || progress == FINISH_PROGRESS

        labels << _("Pawn %{pawn}: %{position}") % {
          pawn: pawn + 1,
          position: progress_label(player, progress)
        }
      end
      finished = pawns.count { |progress| progress == FINISH_PROGRESS }
      if finished > 0
        labels << _("At the finish: %{count} of %{total} pawns") % { count: finished, total: PAWNS_PER_PLAYER }
      end
      labels
    end

    def pawn_positions_text(state, viewer)
      player = player_index(state[:players], viewer)
      return _("You are not a player in this game.") if player == nil

      _("Your pawns: %{positions}.") % { positions: pawn_status_labels(state, player).join("; ") }
    end

    def opponents_pawn_positions_text(state, viewer)
      viewer_index = player_index(state[:players], viewer)
      positions = state[:players].each_index.filter_map do |player|
        next if player == viewer_index

        _("%{player}: %{positions}") % {
          player: participant_name(state[:players][player]),
          positions: pawn_status_labels(state, player).join("; ")
        }
      end
      _("Opponents' pawns: %{positions}.") % { positions: positions.join("; ") }
    end

    def initial_state(players, options)
      {
        players: players, options: options, current_player: players[0], phase: :awaiting_roll, roll: nil,
        consecutive_sixes: 0, pawns: Array.new(players.length) { Array.new(PAWNS_PER_PLAYER, -1) }, winner: nil
      }
    end

    def apply_roll!(state, event, actor, repository, history)
      return false if state[:phase] != :awaiting_roll
      value = event["value"].to_i
      return false if !value.between?(1, 6)

      state[:roll] = value
      state[:consecutive_sixes] = value == 6 ? state[:consecutive_sixes] + 1 : 0
      event_id = repository.event_id(event)
      history << HistoryEntry.new(
        key: "roll:#{event_id}", text: _("%{player} rolled %{value}.") % { player: participant_name(actor), value: value },
        event_id: event_id, actor: actor, kind: :roll, value: value
      )
      if state[:options]["three_sixes"] && state[:consecutive_sixes] >= 3
        history << HistoryEntry.new(
          key: "three_sixes:#{event_id}", text: _("Three consecutive sixes; %{player}'s turn ends.") % { player: participant_name(actor) },
          event_id: event_id, actor: actor, kind: :turn_end
        )
        advance_turn!(state, actor)
        return true
      end

      player = player_index(state[:players], actor)
      choices = legal_pawn_indices(state, player)
      if choices.empty?
        history << HistoryEntry.new(
          key: "no_move:#{event_id}", text: _("%{player} has no legal pawn move.") % { player: participant_name(actor) },
          event_id: event_id, actor: actor, kind: :pass
        )
        if value == 6 && state[:options]["extra_on_six"]
          state[:phase] = :awaiting_roll
          state[:roll] = nil
        else
          advance_turn!(state, actor)
        end
      elsif choices.length == 1
        state[:phase] = :moving
        apply_pawn_move_index!(state, actor, player, choices.first, event_id, history)
      else
        state[:phase] = :moving
      end
      true
    end

    def apply_pawn_move!(state, event, actor, repository, history)
      return false if state[:phase] != :moving
      player = player_index(state[:players], actor)
      pawn = Integer(event["value"].to_s, 10)
      return false if !legal_pawn_indices(state, player).include?(pawn)

      apply_pawn_move_index!(state, actor, player, pawn, repository.event_id(event), history)
      true
    rescue ArgumentError
      false
    end

    def apply_legacy_pawn_move!(state, event, actor, repository, history)
      pawn_field = event["value"].to_s.split(";").find { |field| field.start_with?("pawn=") }
      return false if pawn_field == nil

      legacy_event = event.merge("value" => pawn_field.split("=", 2)[1])
      apply_pawn_move!(state, legacy_event, actor, repository, history)
    end

    def apply_pawn_move_index!(state, actor, player, pawn, event_id, history)
      previous = state[:pawns][player][pawn]
      destination = destination_progress(state, player, pawn)
      captured = capture_targets(state, player, destination)
      state[:pawns][player][pawn] = destination
      captured.each { |other, index| state[:pawns][other][index] = -1 }
      text = _("%{player} moved pawn %{pawn} from %{from} to %{to}.") % {
        player: participant_name(actor), pawn: pawn + 1,
        from: progress_label(player, previous), to: progress_label(player, destination)
      }
      history << HistoryEntry.new(
        key: "move:#{event_id}", text: text, event_id: event_id, actor: actor,
        kind: :move, field: progress_label(player, destination)
      )
      captured.each do |other, captured_pawn|
        history << HistoryEntry.new(
          key: "capture:#{event_id}:#{other}:#{captured_pawn}",
          text: _("%{player} sent pawn %{pawn} belonging to %{opponent} back to the base.") % {
            player: participant_name(actor),
            pawn: captured_pawn + 1,
            opponent: participant_name(state[:players][other])
          },
          event_id: event_id, actor: actor, kind: :capture, value: captured.length
        )
      end
      if state[:pawns][player].all? { |progress| progress == FINISH_PROGRESS }
        state[:winner] = actor
        state[:current_player] = nil
        state[:phase] = :finished
        history << result_history(event_id: event_id, winner: actor)
      elsif state[:roll] == 6 && state[:options]["extra_on_six"]
        state[:phase] = :awaiting_roll
        state[:roll] = nil
      else
        advance_turn!(state, actor)
      end
    end

    def legal_pawn_indices(state, player)
      return [] if player == nil || state[:roll] == nil
      roll = state[:roll].to_i
      state[:pawns][player].each_index.filter_map do |pawn|
        current = state[:pawns][player][pawn]
        next if current == FINISH_PROGRESS

        destination = if current < 0
          next if state[:options]["enter_on_six"] && roll != 6
          0
        else
          current + roll
        end
        if destination > FINISH_PROGRESS
          next if state[:options]["exact_finish"]
          destination = FINISH_PROGRESS
        end
        next if blocked_path?(state, player, current, destination)

        pawn
      end
    end

    def destination_progress(state, player, pawn)
      current = state[:pawns][player][pawn]
      current < 0 ? 0 : [current + state[:roll].to_i, FINISH_PROGRESS].min
    end

    def blocked_path?(state, player, current, destination)
      return false if !state[:options]["blockades"] || current < 0
      ((current + 1)..destination).any? do |progress|
        next false if progress >= OUTER_LENGTH
        global = global_track_index(player, progress)
        state[:pawns].each_with_index.any? do |pawns, other|
          other != player && pawns.count { |value| value.between?(0, OUTER_LENGTH - 1) && global_track_index(other, value) == global } >= 2
        end
      end
    end

    def capture_targets(state, player, progress)
      return [] if progress < 0 || progress >= OUTER_LENGTH
      global = global_track_index(player, progress)
      return [] if SAFE_TRACK_INDICES.include?(global)
      result = []
      state[:pawns].each_with_index do |pawns, other|
        next if other == player
        pawns.each_with_index do |candidate, index|
          result << [other, index] if candidate.between?(0, OUTER_LENGTH - 1) && global_track_index(other, candidate) == global
        end
      end
      result
    end

    def exposure_risk(state, player, progress)
      return 0 if progress < 0 || progress >= OUTER_LENGTH || safe_progress?(player, progress)
      global = global_track_index(player, progress)
      state[:pawns].each_with_index.sum do |pawns, other|
        next 0 if other == player
        pawns.count do |candidate|
          candidate.between?(0, OUTER_LENGTH - 1) && begin
            distance = (global - global_track_index(other, candidate)) % OUTER_LENGTH
            distance.between?(1, 6)
          end
        end
      end
    end

    def safe_progress?(player, progress)
      progress >= OUTER_LENGTH || SAFE_TRACK_INDICES.include?(global_track_index(player, progress))
    end

    def advance_turn!(state, actor)
      index = player_index(state[:players], actor)
      state[:current_player] = state[:players][(index + 1) % state[:players].length]
      state[:phase] = :awaiting_roll
      state[:roll] = nil
      state[:consecutive_sixes] = 0
    end

    def board_snapshot(state)
      state[:pawns].map(&:dup)
    end

    def progress_label(player, progress)
      return _("base") if progress < 0
      return _("finish") if progress == FINISH_PROGRESS
      if progress >= OUTER_LENGTH
        return _("home lane %{position} of %{total}") % {
          position: progress - OUTER_LENGTH + 1,
          total: HOME_LANE_LENGTH
        }
      end

      _("track %{position}") % { position: global_track_index(player, progress) + 1 }
    end

    def global_track_index(player, progress)
      (ENTRY_INDICES[player] + progress) % OUTER_LENGTH
    end
  end
end
