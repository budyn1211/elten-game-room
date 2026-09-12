require_relative "../lib/game_bots"
require_relative "../lib/game_tree_search"
require_relative "../lib/board_presentation"

module GameRoomGames
  class Reversi < Base
    include GameRoomBoardPresentation

    SIZE = 8
    DIRECTIONS = [-1, 0, 1].product([-1, 0, 1]).reject { |dx, dy| dx == 0 && dy == 0 }.freeze

    def id
      "reversi"
    end

    def name
      _("Reversi")
    end

    def rule_sections
      [
        rule_section(:turning, _("Enclosing and turning discs"),
          _("Two players use an 8 by 8 board with four discs in the centre. The first player is black and starts; the second is white. Place a disc on an empty field so that it encloses a continuous line of one or more opposing discs between the new disc and one of your existing discs."),
          _("Lines count horizontally, vertically and diagonally. Every opposing disc enclosed by this move changes to your colour, in all qualifying directions at once. An empty space interrupts a line. At least one disc must turn for a move to be legal; you cannot simply place a disc beside your own."),
          _("If you have no legal move, the game announces and skips your turn automatically. You cannot pass voluntarily when a move exists. When neither player can move, the game counts the discs: more discs wins, equal numbers draw. The board need not be full. There are no optional variants; computers are supported.")),
        rule_section(:controls, _("Placing a disc"),
          _("Use the Arrow keys to inspect the board and Enter to place a disc. T reads the turn. Entering /d3 in chat attempts the same move as Enter on D3 and applies the same enclosure rules."))
      ]
    end

    def supports_bots?
      true
    end

    def shareable_simulation_snapshot?
      true
    end

    def bot_strategy
      @bot_strategy ||= GameRoomBots::AlphaBetaStrategy.new(max_depth: 6, node_limit: 55_000, optimize_transpositions: true)
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      state = { board: initial_board, players: players, current_player: players[0], winner: nil, draw: false }
      accepted = []
      history = [starting_history(players)]
      apply_events!(state, events, repository, session, accepted, history)

      Replay.new(
        board: state[:board], players: players, current_player: state[:current_player], winner: state[:winner], draw: state[:draw],
        accepted_events: accepted, history: history, state: state.merge(counts: disc_counts(state[:board]))
      )
    end

    def incremental_replay(replay, session, events, repository)
      return nil if replay == nil

      state = replay.state.merge(board: replay.board.map(&:dup), players: replay.players)
      accepted = replay.accepted_events.dup
      history = replay.history.dup
      apply_events!(state, events, repository, session, accepted, history)
      Replay.new(
        board: state[:board], players: state[:players], current_player: state[:current_player], winner: state[:winner], draw: state[:draw],
        accepted_events: accepted, history: history, state: state.merge(counts: disc_counts(state[:board]))
      )
    end

    def surface_spec(replay, viewer)
      cells = replay.board.map do |row|
        row.map { |marker| marker == nil ? "" : _("%{player}'s disc") % { player: participant_name(replay.players[marker]) } }
      end
      GameSurfaces::GridSpec.new(width: SIZE, height: SIZE, header: game_field_header(replay, viewer), cells: cells, row_origin: :bottom)
    end

    def legal_actions(replay, actor, context: nil)
      return [] if replay.finished? || !same_user?(replay.current_player, actor)

      available_fields(replay.board, player_index(replay.players, actor)).map do |x, y|
        { "kind" => "grid", "action" => "select", "x" => x, "y" => y }
      end
    end

    def action_for(selection, replay, actor, context: nil)
      return [:finished, nil] if replay.finished?
      return [:not_your_turn, nil] if !same_user?(replay.current_player, actor)
      return [:invalid, nil] if selection["kind"].to_s != "grid" || selection["action"].to_s != "select"

      x = selection_value(selection, "x")
      y = selection_value(selection, "y")
      marker = player_index(replay.players, actor)
      return [:invalid_move, nil] if !inside?(x, y)
      return [:occupied, nil] if replay.board[y][x] != nil
      return [:invalid_move, nil] if flips_for(replay.board, x, y, marker).empty?

      [:ok, event_plan("place", "#{x},#{y}")]
    end

    def move_error(status)
      return _("This field is already occupied.") if status == :occupied
      return _("A disc placed here would not enclose any opposing discs.") if status == :invalid_move

      super
    end

    def move_error_for(status, selection: nil, replay: nil, actor: nil)
      if status == :occupied && selection != nil
        x = selection_value(selection, "x")
        y = selection_value(selection, "y")
        return _("Field %{field} is already occupied.") % { field: field_label(x, y) }
      end

      super
    end

    def bot_search_key(replay, actor)
      board = replay.board.flatten.map { |cell| cell == nil ? "-" : cell }.join
      "#{player_index(replay.players, actor)}:#{player_index(replay.players, replay.current_player)}:#{board}"
    end

    def bot_action_score(replay, actor, action, context: nil)
      x = selection_value(action, "x")
      y = selection_value(action, "y")
      marker = player_index(replay.players, actor)
      score = flips_for(replay.board, x, y, marker).length.to_f
      score += 1_000 if corner?(x, y)
      score -= 180 if dangerous_corner_neighbor?(replay.board, x, y)
      score += edge?(x, y) ? 35 : 0
      score
    end

    def bot_position_value(replay, actor)
      return bot_reward(replay, actor) * 1_000_000.0 if replay.finished?

      marker = player_index(replay.players, actor)
      opponent = marker == 0 ? 1 : 0
      own_moves = available_fields(replay.board, marker).length
      other_moves = available_fields(replay.board, opponent).length
      corners = [[0, 0], [7, 0], [0, 7], [7, 7]]
      corner_score = corners.sum do |x, y|
        replay.board[y][x] == marker ? 1 : (replay.board[y][x] == opponent ? -1 : 0)
      end
      counts = disc_counts(replay.board)
      empty = replay.board.flatten.count(nil)
      disc_weight = empty < 16 ? 5.0 : 0.3
      stability = reversi_stable_edges(replay.board).sum { |x, y| replay.board[y][x] == marker ? 1 : -1 }
      frontier = [0, 0]
      danger = [0, 0]
      replay.board.each_with_index do |row, y|
        row.each_with_index do |cell, x|
          next if cell == nil
          frontier[cell] += 1 if (-1..1).any? { |dy| (-1..1).any? { |dx| inside?(x + dx, y + dy) && replay.board[y + dy][x + dx] == nil } }
          danger[cell] += 1 if dangerous_corner_neighbor?(replay.board, x, y)
        end
      end
      parity = if empty <= 12
        reversi_odd_regions(replay.board) * (same_user?(replay.current_player, actor) ? 2 : -2)
      else
        0
      end
      (own_moves - other_moves) * 12.0 + corner_score * 250.0 + (counts[marker] - counts[opponent]) * disc_weight +
        stability * 30 + (frontier[opponent] - frontier[marker]) * 4 + (danger[opponent] - danger[marker]) * 45 + parity
    end

    private

    def reversi_stable_edges(board)
      stable = []
      [[0, 0, 1, 1], [7, 0, -1, 1], [0, 7, 1, -1], [7, 7, -1, -1]].each do |x, y, dx, dy|
        next if board[y][x] == nil
        [[dx, 0], [0, dy]].each do |sx, sy|
          px, py = x, y
          while inside?(px, py) && board[py][px] == board[y][x]
            stable << [px, py]
            px += sx
            py += sy
          end
        end
      end
      stable.uniq
    end

    def reversi_odd_regions(board)
      empty = {}
      board.each_with_index { |row, y| row.each_with_index { |cell, x| empty[[x, y]] = true if cell == nil } }
      odd = 0
      until empty.empty?
        stack = [empty.keys.first]
        count = 0
        until stack.empty?
          x, y = stack.pop
          next unless empty.delete([x, y])
          count += 1
          [[1, 0], [-1, 0], [0, 1], [0, -1]].each { |dx, dy| stack << [x + dx, y + dy] if empty.key?([x + dx, y + dy]) }
        end
        odd += 1 if count.odd?
      end
      odd
    end

    def apply_events!(state, events, repository, session, accepted, history)
      events.each do |event|
        break if state[:winner] != nil || state[:draw]
        next if event["action"].to_s != "place"

        actor = repository.actor_of(event, session)
        next if !same_user?(actor, state[:current_player])
        position = parse_position(event["value"])
        marker = player_index(state[:players], actor)
        flips = position == nil ? [] : flips_for(state[:board], position[0], position[1], marker)
        next if flips.empty?

        x, y = position
        state[:board][y][x] = marker
        flips.each { |fx, fy| state[:board][fy][fx] = marker }
        accepted << event
        event_id = repository.event_id(event)
        field = field_label(x, y)
        changed_fields = ([[x, y]] + flips).uniq.map { |fx, fy| field_label(fx, fy) }.join(", ")
        history << HistoryEntry.new(
          key: "move:#{event_id}",
          text: _("%{player}, changed fields: %{fields}.") % {
            player: participant_name(actor), fields: changed_fields
          },
          event_id: event_id, actor: actor, kind: :move, field: field, value: flips.length
        )
        other = other_player(state[:players], actor)
        state[:current_player] = if !available_fields(state[:board], player_index(state[:players], other)).empty?
          other
        elsif !available_fields(state[:board], marker).empty?
          history << HistoryEntry.new(
            key: "pass:#{event_id}",
            text: _("%{player} has no legal move; the turn is passed.") % { player: participant_name(other) },
            event_id: event_id, actor: other, kind: :pass
          )
          actor
        end
        if state[:current_player] == nil
          counts = disc_counts(state[:board])
          if counts[0] == counts[1]
            state[:draw] = true
            history << result_history(event_id: event_id, draw: true)
          else
            state[:winner] = state[:players][counts[0] > counts[1] ? 0 : 1]
            history << result_history(event_id: event_id, winner: state[:winner])
          end
        end
      end
    end

    def initial_board
      board = Array.new(SIZE) { Array.new(SIZE) }
      board[3][3] = 1
      board[4][4] = 1
      board[3][4] = 0
      board[4][3] = 0
      board
    end

    def available_fields(board, marker)
      return [] if marker == nil

      key = [board.flatten.map { |cell| cell == nil ? "-" : cell }.join, marker]
      @reversi_moves_cache ||= {}
      return @reversi_moves_cache[key] if @reversi_moves_cache.key?(key)
      @reversi_moves_cache.clear if @reversi_moves_cache.length >= 8_000
      @reversi_moves_cache[key] = (0...SIZE).flat_map do |y|
        (0...SIZE).filter_map { |x| [x, y] if !flips_for(board, x, y, marker).empty? }
      end
    end

    def flips_for(board, x, y, marker)
      return [] if marker == nil || !inside?(x, y) || board[y][x] != nil

      opponent = marker == 0 ? 1 : 0
      DIRECTIONS.flat_map do |dx, dy|
        line = []
        cx = x + dx
        cy = y + dy
        while inside?(cx, cy) && board[cy][cx] == opponent
          line << [cx, cy]
          cx += dx
          cy += dy
        end
        inside?(cx, cy) && board[cy][cx] == marker ? line : []
      end
    end

    def parse_position(value)
      match = /\A([0-7]),([0-7])\z/.match(value.to_s)
      match == nil ? nil : [match[1].to_i, match[2].to_i]
    end

    def inside?(x, y)
      x.to_i.between?(0, SIZE - 1) && y.to_i.between?(0, SIZE - 1)
    end

    def disc_counts(board)
      [board.flatten.count(0), board.flatten.count(1)]
    end

    def corner?(x, y)
      [0, 7].include?(x) && [0, 7].include?(y)
    end

    def edge?(x, y)
      [0, 7].include?(x) || [0, 7].include?(y)
    end

    def dangerous_corner_neighbor?(board, x, y)
      nearest = [[0, 0], [7, 0], [0, 7], [7, 7]].find do |cx, cy|
        (x - cx).abs <= 1 && (y - cy).abs <= 1 && !corner?(x, y)
      end
      nearest != nil && board[nearest[1]][nearest[0]] == nil
    end
  end
end
