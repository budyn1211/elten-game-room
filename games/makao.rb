require "digest"
require_relative "card_game"
require_relative "../lib/game_bots"

module GameRoomGames
  class Makao < CardGame
    PROFILES = [
      OptionChoice.new(value: "simple", label: _("Simple Makao")),
      OptionChoice.new(value: "polish", label: _("Polish extended Makao")),
      OptionChoice.new(value: "joker", label: _("Makao with jokers")),
      OptionChoice.new(value: "custom", label: _("Custom rules"))
    ].freeze
    SUITS = %w[C D H S].freeze
    RANKS = %w[2 3 4 5 6 7 8 9 T J Q K A].freeze
    SUIT_NAMES = { "C" => _("clubs"), "D" => _("diamonds"), "H" => _("hearts"), "S" => _("spades") }.freeze
    RANK_NAMES = { "T" => "10", "J" => _("jack"), "Q" => _("queen"), "K" => _("king"), "A" => _("ace") }.freeze

    def id
      "makao"
    end

    def name
      _("Makao")
    end

    def minimum_players
      2
    end

    def maximum_players
      8
    end

    def supports_bots?
      true
    end

    def bot_strategy
      @bot_strategy ||= GameRoomBots::HeuristicStrategy.new
    end

    def rule_sections
      [
        rule_section(:matching, _("Matching cards and playing packets"),
          _("Two to eight players use a standard 52-card deck, optionally with two jokers. Everyone receives five cards by default. The first table card is not a two, three, four, ace, king or joker. Play goes in one fixed direction from the player after the dealer. The first player to empty their hand wins immediately."),
          _("Play one card or an ordered packet of equal ranks. The first card must match the current suit or rank, or qualify under an active special rule. Later cards in the same packet may have different suits but must have the same rank; a joker can represent that rank. The packet is a single move. Its order matters because the last card determines the resulting table state."),
          _("With no legal starting card, draw one. If the drawn card is playable and Draw responses is enabled, you may play it in this turn, including a matching packet, or pass. Otherwise the turn passes automatically. You cannot draw voluntarily while already holding a playable card, and paying a draw penalty always ends the turn. If the deck runs out, discards except the current top card are recycled.")),
        rule_section(:penalties, _("Twos, threes, fours and kings"),
          _("Each two adds two penalty cards and each three adds three. Twos and threes may answer each other is on in the ready-made profiles: the debt accumulates, for example two plus three means five. With this option off, only another card of the same attacking rank answers. A player who accepts the debt draws its full amount and ends the turn."),
          _("A four requires waiting. With Fours accumulate skipped turns enabled, answer with another four or a packet of fours to pass on the increased number. Whoever accepts waits exactly that many turns, including the current one, and is automatically skipped on later waiting turns. With accumulation off, a four causes one missed turn and cannot be answered with another four."),
          _("With Attacking kings enabled, the king of spades attacks the next player with five cards. The king of hearts answers that king attack and adds another five, so the next player owes ten. It does not reverse the direction. The other kings are ordinary matching cards. King penalties are separate from the two/three family.")),
        rule_section(:special, _("Suit changes, requests, queens and jokers"),
          _("Ace changes suit lets an ace be played on any ordinary table card and opens the choice of a suit. It does not cancel a pending draw or waiting penalty. If disabled, aces only match normally. Jack requests a rank from 5 to 10 makes a played jack request one of those ranks from the next player. With it off, jacks are ordinary cards."),
          _("Queen is universal allows a queen to start a normal move regardless of the table card. A queen does not defend against a pending penalty. Use two jokers adds two cards which can represent any ordinary or special card; choose the represented card when playing. A joker defending a penalty must represent a card that can actually defend it, not an arbitrary card. Representing an ace or king uses its enabled special effect.")),
        rule_section(:profiles, _("Ready-made profiles and your own rules"),
          _("Simple Makao is the default: no jokers, mixing two/three penalties, cumulative fours, suit-changing aces and playing a drawn card are enabled; jack requests, universal queens and attacking kings are disabled. Polish extended Makao adds those three features, still without jokers. Makao with jokers adds two jokers and attacking kings to the simple profile, fixes the deal at five cards, and leaves jack requests and universal queens off."),
          _("Custom rules exposes every special-rule switch described above: jokers, mixed twos/threes, cumulative fours, ace suit changes, jack requests, universal queens, attacking kings and playing a drawn card. These values are remembered locally for the next custom table, not imposed on other people's tables. Cards dealt to each player can be 3–15, default 5, except in the fixed joker profile. The chosen player count and hand size must leave a card for the table."),
          _("Cards drawn for missing Makao defaults to 1, from 1 to 10, in every profile. Say Makao once your hand contains one card. Another player may catch the omission before your next turn and make you draw this many cards. Playing your last card ends the game; there is no points-elimination tournament in this implementation.")),
        rule_section(:controls, _("Preparing and playing a packet"),
          _("Arrow keys browse your hand. Enter plays the current card, or the prepared packet, opening any required declaration list. Shift+Enter adds or removes a card from the packet in selection order; Enter also includes the current card if it is not selected yet. P reads the prepared packet in selection order; Shift+P clears it. Space draws, or ends the turn after an ordinary draw. To accept a waiting penalty, use its separate action with Enter."),
          _("C reads the table card and declaration, G the pending penalty, T the turn, S card counts and D your hand. U says Makao, Shift+U catches another player. A declaration or catch does not require your ordinary turn."))
      ]
    end

    def option_definitions
      custom_rules = { "profile" => "custom" }
      [
        OptionDefinition.new(key: "profile", label: _("Rule profile"), kind: :choice, default: "simple", choices: PROFILES),
        OptionDefinition.new(key: "jokers", label: _("Use two jokers"), kind: :boolean, default: false,
          visible_if: custom_rules),
        OptionDefinition.new(key: "hand_size", label: _("Cards dealt to each player"), kind: :integer, default: 5,
          visible_if: ->(options) { options["profile"].to_s != "joker" }),
        OptionDefinition.new(key: "mixed_draw_cards", label: _("Twos and threes may answer each other"), kind: :boolean, default: true,
          visible_if: custom_rules),
        OptionDefinition.new(key: "stack_fours", label: _("Fours accumulate skipped turns"), kind: :boolean, default: true,
          visible_if: custom_rules),
        OptionDefinition.new(key: "ace_changes_suit", label: _("Ace changes suit"), kind: :boolean, default: true,
          visible_if: custom_rules),
        OptionDefinition.new(key: "jack_requests_rank", label: _("Jack requests a rank from 5 to 10"), kind: :boolean, default: false,
          visible_if: custom_rules),
        OptionDefinition.new(key: "queen_universal", label: _("Queen is universal"), kind: :boolean, default: false,
          visible_if: custom_rules),
        OptionDefinition.new(key: "attacking_kings", label: _("Attacking kings"), kind: :boolean, default: false,
          visible_if: custom_rules),
        OptionDefinition.new(key: "draw_responses", label: _("A drawn playable card may be played immediately"), kind: :boolean, default: true,
          visible_if: custom_rules),
        OptionDefinition.new(key: "makao_penalty", label: _("Cards drawn for missing Makao"), kind: :integer, default: 1)
      ]
    end

    def normalize_options(values)
      result = super
      case result["profile"].to_s
      when "simple"
        result.merge!("jokers" => false, "mixed_draw_cards" => true, "stack_fours" => true,
          "ace_changes_suit" => true, "jack_requests_rank" => false, "queen_universal" => false,
          "attacking_kings" => false, "draw_responses" => true)
      when "polish"
        result.merge!("jokers" => false, "mixed_draw_cards" => true, "stack_fours" => true,
          "ace_changes_suit" => true, "jack_requests_rank" => true, "queen_universal" => true,
          "attacking_kings" => true, "draw_responses" => true)
      when "joker"
        result.merge!("jokers" => true, "hand_size" => 5, "mixed_draw_cards" => true,
          "stack_fours" => true, "ace_changes_suit" => true, "jack_requests_rank" => false,
          "queen_universal" => false, "attacking_kings" => true, "draw_responses" => true)
      end
      result
    end

    def rules_option_visible?(_definition, _options)
      # Presets lock their checkboxes in the editor, but their enabled rules
      # still belong in the read-only table settings document.
      true
    end

    def options_error(options, player_count: nil)
      values = normalize_options(options)
      return _("The hand size must be from 3 to 15.") if !values["hand_size"].to_i.between?(3, 15)
      return _("The Makao penalty must be from 1 to 10.") if !values["makao_penalty"].to_i.between?(1, 10)
      if player_count && player_count.to_i * values["hand_size"].to_i >= (values["jokers"] ? 54 : 52)
        return _("There are not enough cards to deal this many cards to every player.")
      end
      nil
    end

    def options_summary(options)
      values = normalize_options(options)
      profile = PROFILES.find { |choice| choice.value == values["profile"] }&.label || values["profile"]
      _("%{profile}; %{cards} cards; jokers: %{jokers}") % { profile: profile, cards: values["hand_size"], jokers: values["jokers"] ? _("yes") : _("no") }
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      state = initial_state(players, options_from_json(session["options"]))
      accepted = []
      history = [starting_history(players)]
      events.each do |event|
        break if state[:winner] != nil
        actor = repository.actor_of(event, session)
        applied = case event["action"].to_s
        when "deal" then apply_deal(state, event, actor, repository, history)
        when "play" then apply_play(state, event, actor, repository, history)
        when "draw" then apply_draw(state, event, actor, repository, history)
        when "accept_skip" then apply_accept_skip(state, event, actor, repository, history)
        when "makao" then apply_makao(state, event, actor, repository, history)
        when "catch" then apply_catch(state, event, actor, repository, history)
        when "pass" then apply_pass(state, event, actor, repository, history)
        else false
        end
        accepted << event if applied
      end
      Replay.new(board: nil, players: players, current_player: state[:current_player], winner: state[:winner],
        draw: false, accepted_events: accepted, history: history, state: state)
    end

    def automatic_action(replay, actor, context: nil)
      return nil if replay.finished? || !same_user?(actor, replay.players.first) || replay.state[:phase] != :awaiting_deal
      { "kind" => "command", "action" => "deal" }
    end

    def legal_actions(replay, actor, context: nil)
      state = replay.state
      return [] if replay.finished? || state[:phase] != :playing || player_key(state, actor) == nil
      actions = []
      if state[:phase] == :playing && same_user?(state[:current_player], actor)
        hand = hand_for(state, actor)
        # Enumerate packets by rank rather than all subsets of the hand.
        RANKS.each do |rank|
          group = hand.select { |card| joker?(card) || card_rank(card) == rank }
          1.upto(group.length) do |count|
            group.combination(count) do |packet|
              packet.each do |first|
                ordered = [first] + (packet - [first])
                choices = packet.any? { |card| joker?(card) } ? SUITS.map { |suit| "#{rank}#{suit}" } : card_choices_for(state, ordered.last)
                if rank == "J" && state[:options]["jack_requests_rank"] && packet.any? { |card| !joker?(card) }
                  choices += %w[5 6 7 8 9 T]
                end
                choices = [""] if choices.empty?
                choices.each do |choice|
                  next if validate_packet(state, actor, ordered, choice) != :ok
                  actions << { "kind" => "card_packet", "action" => "play", "cards" => JSON.generate(ordered), "choice" => choice }
                end
              end
            end
          end
        end
        if state[:skip_penalty].to_i > 0
          actions << { "kind" => "command", "action" => "accept_skip" }
        elsif state[:draw_penalty] > 0 || (!state[:drawn_this_turn] && actions.empty?)
          actions << { "kind" => "command", "action" => "draw" }
        elsif state[:drawn_this_turn]
          actions << { "kind" => "command", "action" => "pass" }
        end
      end
      actions << { "kind" => "command", "action" => "makao" } if hand_for(state, actor).length == 1 && !(state[:makao_declarations] || {})[player_key(state, actor)]
      actions << { "kind" => "command", "action" => "catch" } if catchable_player(state, actor) != nil
      actions.uniq
    end

    def active_actors(replay)
      return [] if replay.finished? || replay.state[:phase] != :playing
      state = replay.state
      declaring = state[:players].select { |player| hand_for(state, player).length == 1 && !(state[:makao_declarations] || {})[player] }
      (declaring + [state[:current_player]] + state[:players]).compact.uniq.select { |player| !legal_actions(replay, player).empty? }
    end

    def action_for(selection, replay, actor, context: nil)
      state = replay.state
      return [:finished, nil] if replay.finished?
      if selection["kind"].to_s == "command" && selection["action"].to_s == "deal"
        return [:not_your_turn, nil] if !same_user?(actor, replay.players.first)
        return [:invalid, nil] if state[:phase] != :awaiting_deal || context&.random_source == nil
        seed = card_seed(context.random_source)
        dealer = seed.to_i(16) % replay.players.length
        return [:ok, event_plan("deal", "#{dealer}|#{seed}")]
      end
      action = selection["action"].to_s
      if action == "play"
        return [:not_your_turn, nil] if !same_user?(state[:current_player], actor)
        cards = JSON.parse(selection["cards"].to_s).map(&:to_s)
        choice = selection["choice"].to_s
        status = validate_packet(state, actor, cards, choice)
        return [status, nil] if status != :ok
        return [:ok, event_plan("play", "#{cards.join(',')}|#{choice}")]
      end
      if %w[draw accept_skip makao catch pass].include?(action) && legal_actions(replay, actor).any? { |item| item["action"] == action }
        return [:ok, event_plan(action, action == "catch" ? catchable_player(state, actor) : "")]
      end
      [:invalid, nil]
    rescue JSON::ParserError
      [:invalid_packet, nil]
    end

    def surface_spec(replay, viewer)
      state = replay.state
      cards = hand_for(state, viewer).sort_by { |card| makao_sort_key(card) }.map do |card|
        choices = card_choices_for(state, card).map do |choice|
          GameSurfaces::CardChoice.new(id: choice, label: choice_label(choice), value: choice)
        end
        GameSurfaces::Card.new(id: card, label: makao_card_label(card), value: card, choices: choices,
          choice_header: joker?(card) ? _("Choose the card represented by the joker") : card_rank(card) == "A" ? _("Choose a suit") : _("Choose the requested rank"))
      end
      packet = GameSurfaces::PacketCardSpec.new(id: "makao_hand", header: same_user?(state[:current_player], viewer) ? _("Your hand") : _("Waiting for %{player}") % { player: participant_name(state[:current_player]) },
        cards: cards, action_name: "play", allow_packet: true, empty_label: _("Your hand is empty"),
        hand_order: hand_for(state, viewer).dup, hand_epoch: [viewer, state[:seed]].join(":"))
      return packet if state[:skip_penalty].to_i <= 0 || !same_user?(state[:current_player], viewer)

      command = GameSurfaces::CommandPanelSpec.new(commands: [
        GameSurfaces::Command.new(
          id: "accept_skip",
          label: n_("Accept waiting for %{count} turn", "Accept waiting for %{count} turns", state[:skip_penalty]) % { count: state[:skip_penalty] },
          enabled: true,
          payload: {}
        )
      ])
      GameSurfaces::CompositeSpec.new(parts: [
        GameSurfaces::SurfacePart.new(id: "skip", surface: command),
        GameSurfaces::SurfacePart.new(id: "hand", surface: packet)
      ])
    end

    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      [
        GameShortcut.new(key: "space", label: _("draw a card or finish after drawing"), kind: :action, action_kind: "command", action_name: state[:drawn_this_turn] ? "pass" : "draw"),
        surface_shortcut(key: "p", label: _("read the prepared packet"), command: "announce_packet"),
        surface_shortcut(key: "p", modifiers: [:shift], label: _("clear the prepared packet"), command: "clear_packet"),
        announcement_shortcut(key: "c", label: _("read the table card"), message: table_text(state)),
        announcement_shortcut(key: "g", label: _("read the current penalty"), message: penalty_text(state, viewer)),
        announcement_shortcut(key: "s", label: _("read card counts"), message: counts_text(state)),
        announcement_shortcut(key: "d", label: _("read your hand"), message: hand_for(state, viewer).map { |card| makao_card_label(card) }.join(", ")),
        GameShortcut.new(key: "u", label: _("say Makao"), kind: :action, action_kind: "command", action_name: "makao"),
        GameShortcut.new(key: "u", modifiers: [:shift], label: _("catch missing Makao"), kind: :action, action_kind: "command", action_name: "catch")
      ]
    end

    def bot_observation(replay, actor)
      state = replay.state
      { "current_player" => state[:current_player], "own_hand" => hand_for(state, actor),
        "counts" => state[:hands].transform_values(&:length), "top" => state[:discard].last,
        "suit" => state[:declared_suit], "penalty" => state[:draw_penalty], "skip" => state[:skip_penalty] }
    end

    def bot_action_score(replay, actor, action, context: nil)
      return -500.0 if action["action"] == "draw"
      return -600.0 if action["action"] == "pass"
      return 1_000.0 if action["action"] == "catch"
      return 500.0 if action["action"] == "makao"
      cards = JSON.parse(action["cards"].to_s) rescue []
      score = cards.length * 400.0
      score += cards.sum { |card| special_card?(card) ? 100 : rank_value(card) }
      score += 2_000 if hand_for(replay.state, actor).length == cards.length
      remaining = hand_for(replay.state, actor) - cards
      effective = effective_packet(cards, action["choice"]) if !cards.empty?
      if effective
        score += remaining.count { |card| card_suit(card) == effective[:suit] } * 35
        score += remaining.count { |card| card_rank(card) == effective[:request] } * 90 if effective[:request]
        score -= cards.count { |card| joker?(card) || card_rank(card) == "A" } * 80
        simulated = replay.state.merge(skip_turns: replay.state[:skip_turns].dup, makao_windows: replay.state[:makao_windows].to_h.dup)
        apply_packet_effects(simulated, cards, effective)
        next_player = advance_player(simulated, actor, 1)
        attack = simulated[:draw_penalty].to_i + simulated[:skip_penalty].to_i * 2
        score += [attack, 12].min * (hand_for(replay.state, next_player).length <= 2 ? 40 : 12)
        # Preserve a flexible defence and prefer a connected remaining hand.
        # Only own cards and public penalties/counts are considered.
        score += 55 if remaining.any? { |card| joker?(card) }
        score += 30 if remaining.any? { |card| %w[2 3].include?(card_rank(card)) }
        suits = remaining.reject { |card| joker?(card) }.map { |card| card_suit(card) }.uniq
        bridges = remaining.group_by { |card| card_rank(card) }.values.count { |group| group.map { |card| card_suit(card) }.uniq.length > 1 }
        score += bridges * 25 - [suits.length - 1, 0].max * 15
      end
      score
    end

    def move_error(status)
      case status
      when :invalid_packet then _("The selected cards do not form a legal packet.")
      when :card_not_in_hand then _("One of these cards is not in your hand.")
      when :wrong_rank then _("All cards in a packet must have the same value.")
      when :illegal_card then _("The first card in the packet cannot begin this move.")
      else super
      end
    end

    def move_error_for(status, selection: nil, replay: nil, actor: nil)
      if status == :illegal_card && replay != nil
        state = replay.state
        return _("The first card in the packet does not defend against the draw penalty.") if state[:draw_penalty].to_i > 0
        return _("The first card in the packet does not defend against the waiting penalty.") if state[:skip_penalty].to_i > 0
        return _("The first card in the packet does not satisfy the requested rank.") if state[:requested_rank] != nil
      end
      super
    end

    def describe_event(event, repository, replay, viewer)
      id = repository.event_id(event).to_i
      values = replay.history.filter_map { |entry| entry.text if entry.event_id.to_i == id }
      values.empty? ? nil : values
    end

    private

    def initial_state(players, options)
      { players: players, options: options, phase: :awaiting_deal, dealer_index: nil,
        current_player: nil, hands: players.to_h { |player| [player, []] }, draw_pile: [], discard: [],
        seed: nil, recycle: 0, declared_suit: nil, requested_rank: nil, draw_penalty: 0,
        penalty_kind: nil, skip_penalty: 0, skip_turns: players.to_h { |player| [player, 0] },
        declared_makao: nil, makao_declarations: {}, makao_windows: {}, drawn_this_turn: false, winner: nil }
    end

    def apply_deal(state, event, actor, repository, history)
      return false if state[:phase] != :awaiting_deal || !same_user?(actor, state[:players].first)
      dealer_text, seed = event["value"].to_s.split("|", 2)
      dealer = Integer(dealer_text, 10)
      return false if seed !~ /\A[0-9a-f]{32}\z/ || !dealer.between?(0, state[:players].length - 1)
      return false if options_error(state[:options], player_count: state[:players].length)
      deck = shuffled_cards(makao_deck(state[:options]["jokers"]), seed)
      # Reserve an ordinary opening card even when almost the whole deck is dealt.
      top = deck.delete_at(deck.index { |card| ordinary_start?(card) })
      hands = state[:players].to_h { |player| [player, []] }
      cursor = dealer
      (state[:players].length * state[:options]["hand_size"].to_i).times do
        cursor = (cursor + 1) % state[:players].length
        hands[state[:players][cursor]] << deck.shift
      end
      state.update(phase: :playing, dealer_index: dealer, current_player: state[:players][(dealer + 1) % state[:players].length],
        hands: hands, draw_pile: deck, discard: [top], seed: seed, recycle: 0,
        declared_suit: card_suit(top), requested_rank: nil, draw_penalty: 0, penalty_kind: nil,
        skip_penalty: 0, declared_makao: nil, drawn_this_turn: false)
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "deal:#{id}", text: _("Cards were dealt. First card: %{card}.") % { card: makao_card_label(top) }, event_id: id, actor: actor, kind: :deal)
      true
    rescue ArgumentError
      false
    end

    def apply_play(state, event, actor, repository, history)
      cards_text, choice = event["value"].to_s.split("|", 2)
      cards = cards_text.to_s.split(",").reject(&:empty?)
      return false if validate_packet(state, actor, cards, choice.to_s) != :ok
      player = player_key(state, actor)
      cards.each { |card| state[:hands][player].delete_at(state[:hands][player].index(card)) }
      cards.each { |card| state[:discard] << card }
      effective = effective_packet(cards, choice)
      state[:declared_suit] = effective[:suit]
      state[:declared_rank] = effective[:rank]
      state[:requested_rank] = effective[:request]
      apply_packet_effects(state, cards, effective)
      state[:drawn_this_turn] = false
      (state[:makao_declarations] ||= {}).delete(player)
      (state[:makao_windows] ||= {}).delete(player)
      state[:makao_windows][player] = true if state[:hands][player].length == 1
      id = repository.event_id(event)
      labels = cards.map { |card| makao_card_label(card) }.join(", ")
      text = _("%{player} played %{cards}.") % { player: participant_name(player), cards: labels }
      if cards.any? { |card| joker?(card) }
        text += " " + _("%{player}'s joker represents %{card}.") % { player: participant_name(player), card: makao_card_label("#{effective[:rank]}#{effective[:suit]}") }
      end
      if effective[:rank] == "A" && state[:options]["ace_changes_suit"]
        text += " " + _("%{player} changes the suit to %{suit}.") % { player: participant_name(player), suit: SUIT_NAMES.fetch(effective[:suit]) }
      elsif effective[:request] != nil
        text += " " + _("%{player} requests %{rank}.") % { player: participant_name(player), rank: RANK_NAMES.fetch(effective[:request], effective[:request]) }
      end
      history << HistoryEntry.new(key: "play:#{id}", text: text, event_id: id, actor: actor, kind: :play)
      if state[:hands][player].empty?
        state[:winner] = player
        state[:phase] = :finished
        state[:current_player] = nil
        history << result_history(event_id: id, winner: player)
      else
        state[:current_player] = advance_player(state, player, 1, consume_skips: state[:skip_penalty].zero?)
      end
      true
    end

    def apply_draw(state, event, actor, repository, history)
      return false if state[:phase] != :playing || !same_user?(actor, state[:current_player])
      return false if state[:skip_penalty].to_i > 0 || state[:drawn_this_turn]
      player = player_key(state, actor)
      penalty = state[:draw_penalty] > 0
      return false if !penalty && hand_for(state, actor).any? { |card| playable_first?(state, card) }
      count = state[:draw_penalty] > 0 ? state[:draw_penalty] : 1
      drawn = draw_cards(state, count)
      state[:hands][player].concat(drawn)
      (state[:makao_declarations] ||= {}).delete(player)
      (state[:makao_windows] ||= {}).delete(player)
      id = repository.event_id(event)
      text = penalty ? n_("%{player} drew %{count} penalty card.", "%{player} drew %{count} penalty cards.", drawn.length) : n_("%{player} drew %{count} card.", "%{player} drew %{count} cards.", drawn.length)
      history << HistoryEntry.new(key: "draw:#{id}", text: text % { player: participant_name(player), count: drawn.length }, event_id: id, actor: actor, kind: :draw)
      state[:draw_penalty] = 0
      state[:penalty_kind] = nil
      state[:drawn_this_turn] = true
      if !penalty && state[:options]["draw_responses"] && drawn.length == 1 && playable_first?(state, drawn.first)
        # The drawn card stays available to play in the same turn.
      else
        state[:current_player] = advance_player(state, player, 1)
        state[:drawn_this_turn] = false
      end
      true
    end

    def apply_pass(state, event, actor, repository, history)
      return false if state[:phase] != :playing || !same_user?(actor, state[:current_player]) || !state[:drawn_this_turn]
      state[:current_player] = advance_player(state, actor, 1)
      state[:drawn_this_turn] = false
      history << HistoryEntry.new(key: "pass:#{repository.event_id(event)}", text: _("%{player} ended the turn.") % { player: participant_name(actor) }, event_id: repository.event_id(event), actor: actor, kind: :pass)
      true
    end

    def apply_accept_skip(state, event, actor, repository, history)
      return false if state[:phase] != :playing || !same_user?(actor, state[:current_player]) || state[:skip_penalty].to_i <= 0
      player = player_key(state, actor)
      turns = state[:skip_penalty].to_i
      state[:skip_turns][player] = state[:skip_turns][player].to_i + [turns - 1, 0].max
      state[:skip_penalty] = 0
      state[:current_player] = advance_player(state, player, 1)
      id = repository.event_id(event)
      history << HistoryEntry.new(
        key: "skip:#{id}",
        text: n_("%{player} must wait %{count} turn.", "%{player} must wait %{count} turns.", turns) % { player: participant_name(player), count: turns },
        event_id: id, actor: actor, kind: :game
      )
      true
    end

    def apply_makao(state, event, actor, repository, history)
      player = player_key(state, actor)
      return false if state[:phase] != :playing || player == nil || state[:hands][player].length != 1 || (state[:makao_declarations] || {})[player]
      state[:declared_makao] = player
      (state[:makao_declarations] ||= {})[player] = true
      history << HistoryEntry.new(key: "makao:#{repository.event_id(event)}", text: _("%{player} says Makao!") % { player: participant_name(player) }, event_id: repository.event_id(event), actor: actor, kind: :game)
      true
    end

    def apply_catch(state, event, actor, repository, history)
      target = catchable_player(state, actor)
      return false if target == nil || player_key(state, actor) == nil || (!event["value"].to_s.empty? && !same_user?(target, event["value"]))
      cards = draw_cards(state, state[:options]["makao_penalty"].to_i)
      state[:hands][target].concat(cards)
      state[:declared_makao] = target
      (state[:makao_windows] ||= {}).delete(target)
      id = repository.event_id(event)
      text = _("%{player} caught %{target} without Makao.") % { player: participant_name(actor), target: participant_name(target) }
      text += " " + n_("%{player} drew %{count} penalty card.", "%{player} drew %{count} penalty cards.", cards.length) % { player: participant_name(target), count: cards.length }
      history << HistoryEntry.new(key: "catch:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      true
    end

    def validate_packet(state, actor, cards, choice)
      return :not_your_turn if !same_user?(state[:current_player], actor)
      return :invalid_packet if cards.empty? || cards.uniq.length != cards.length
      hand = hand_for(state, actor)
      return :card_not_in_hand if cards.any? { |card| !hand.include?(card) }
      ranks = cards.reject { |card| joker?(card) }.map { |card| card_rank(card) }.uniq
      return :wrong_rank if ranks.length > 1
      return :illegal_card if !playable_first?(state, cards.first)
      if cards.any? { |card| joker?(card) }
        if ranks.empty?
          return :invalid_packet if !joker_choice?(choice)
        elsif !choice.to_s.empty?
          if ranks.first == "J" && state[:options]["jack_requests_rank"]
            return :invalid_packet if !rank_request?(choice) && !(joker_choice?(choice) && choice.to_s[0] == "J" && rank_request?(choice.to_s.split(":", 2)[1]))
          elsif ranks.first == "A" && state[:options]["ace_changes_suit"] && SUITS.include?(choice.to_s)
            # The choice changes suit for the whole ace packet.
          else
            return :invalid_packet if !joker_choice?(choice)
            return :wrong_rank if choice.to_s[0] != ranks.first
          end
        end
      end
      if ranks == ["A"] && state[:options]["ace_changes_suit"]
        declared_suit = joker_choice?(choice) ? choice.to_s[1] : choice.to_s
        return :invalid_packet if !SUITS.include?(declared_suit)
      elsif ranks == ["J"] && state[:options]["jack_requests_rank"]
        return :invalid_packet if !rank_request?(choice) && !joker_choice?(choice)
      elsif cards.none? { |card| joker?(card) } && !choice.to_s.empty?
        return :invalid_packet
      end
      effective = effective_packet(cards, choice)
      if effective[:rank] == "J" && state[:options]["jack_requests_rank"]
        return :invalid_packet if !rank_request?(effective[:request])
      elsif effective[:request] != nil
        return :invalid_packet
      end
      if joker?(cards.first)
        represented = "#{effective[:rank]}#{effective[:suit]}"
        return :illegal_card if (state[:draw_penalty] > 0 || state[:skip_penalty] > 0) && !playable_first?(state, represented)
      end
      :ok
    end

    def playable_first?(state, card)
      return true if joker?(card)
      if state[:draw_penalty] > 0
        return card_rank(card) == "K" && card_suit(card) == "H" if state[:penalty_kind] == "K"
        return ["2", "3"].include?(card_rank(card)) if state[:penalty_kind] == "draw" && state[:options]["mixed_draw_cards"]
        return card_rank(card) == state[:penalty_kind]
      end
      return state[:options]["stack_fours"] && card_rank(card) == "4" if state[:skip_penalty] > 0
      return true if (state[:options]["queen_universal"] && card_rank(card) == "Q") || (state[:options]["ace_changes_suit"] && card_rank(card) == "A")
      return card_rank(card) == state[:requested_rank] if state[:requested_rank] != nil
      card_suit(card) == state[:declared_suit] || card_rank(card) == (state[:declared_rank] || card_rank(state[:discard].last))
    end

    def card_choices_for(state, card)
      if joker?(card)
        return RANKS.flat_map do |rank|
          SUITS.flat_map do |suit|
            if rank == "J" && state[:options]["jack_requests_rank"]
              %w[5 6 7 8 9 T].map { |requested| "#{rank}#{suit}:#{requested}" }
            else
              ["#{rank}#{suit}"]
            end
          end
        end
      end
      if card_rank(card) == "A" && state[:options]["ace_changes_suit"]
        return SUITS
      end
      if card_rank(card) == "J" && state[:options]["jack_requests_rank"]
        return %w[5 6 7 8 9 T]
      end
      []
    end

    def effective_card(card, choice)
      if joker?(card)
        { rank: choice.to_s[0], suit: choice.to_s[1], request: choice.to_s.split(":", 2)[1] }
      elsif card_rank(card) == "A"
        { rank: "A", suit: choice.to_s.empty? ? card_suit(card) : choice.to_s, request: nil }
      elsif card_rank(card) == "J" && !choice.to_s.empty?
        { rank: "J", suit: card_suit(card), request: choice.to_s }
      else
        { rank: card_rank(card), suit: card_suit(card), request: nil }
      end
    end

    def effective_packet(cards, choice)
      return effective_card(cards.last, choice) if cards.none? { |card| joker?(card) }

      ordinary = cards.reverse.find { |card| !joker?(card) }
      return effective_card(cards.last, choice) if ordinary == nil

      rank = card_rank(ordinary)
      suit = if rank == "A" && state_suit_choice?(choice)
        choice.to_s[-1]
      elsif joker?(cards.last) && joker_choice?(choice)
        choice.to_s[1]
      else
        card_suit(ordinary)
      end
      request = rank == "J" ? (joker_choice?(choice) ? choice.to_s.split(":", 2)[1] : choice.to_s) : nil
      { rank: rank, suit: suit, request: request.to_s.empty? ? nil : request }
    end

    def joker_choice?(choice)
      text = choice.to_s
      card, request = text.split(":", 2)
      card.length == 2 && RANKS.include?(card[0]) && SUITS.include?(card[1]) &&
        (request == nil || (card[0] == "J" && rank_request?(request)))
    end

    def state_suit_choice?(choice)
      SUITS.include?(choice.to_s) || joker_choice?(choice)
    end

    def rank_request?(choice)
      %w[5 6 7 8 9 T].include?(choice.to_s)
    end

    def apply_packet_effects(state, cards, effective)
      ranks = cards.map { |card| joker?(card) ? effective[:rank] : card_rank(card) }
      draw = ranks.sum { |rank| rank == "2" ? 2 : rank == "3" ? 3 : 0 }
      if draw > 0
        state[:draw_penalty] += draw
        state[:penalty_kind] = state[:options]["mixed_draw_cards"] ? "draw" : ranks.last
      elsif state[:options]["attacking_kings"] && effective[:rank] == "K"
        cards.each do |card|
          suit = joker?(card) ? effective[:suit] : card_suit(card)
          if suit == "S" || (suit == "H" && state[:penalty_kind] == "K")
            state[:draw_penalty] += 5
            state[:penalty_kind] = "K"
          end
        end
      end
      if ranks.include?("4")
        state[:skip_penalty] = state[:options]["stack_fours"] ? state[:skip_penalty] + ranks.count("4") : 1
      end
    end

    def makao_deck(jokers)
      cards = SUITS.product(RANKS).map { |suit, rank| "#{rank}#{suit}" }
      cards += %w[X0 X1] if jokers
      cards
    end

    def ordinary_start?(card)
      !joker?(card) && !%w[2 3 4 A K].include?(card_rank(card))
    end

    def joker?(card)
      card.to_s.start_with?("X")
    end

    def card_rank(card)
      joker?(card) ? "X" : card.to_s[0]
    end

    def card_suit(card)
      joker?(card) ? nil : card.to_s[1]
    end

    def makao_card_label(card)
      return _("joker") if joker?(card)
      _("%{rank} of %{suit}") % { rank: RANK_NAMES.fetch(card_rank(card), card_rank(card)), suit: SUIT_NAMES.fetch(card_suit(card), card_suit(card)) }
    end

    def choice_label(choice)
      return _("no declaration") if choice.to_s.empty?
      return SUIT_NAMES.fetch(choice) if SUITS.include?(choice)
      return RANK_NAMES.fetch(choice, choice) if choice.length == 1
      label = _("%{rank} of %{suit}") % { rank: RANK_NAMES.fetch(choice[0], choice[0]), suit: SUIT_NAMES.fetch(choice[1], choice[1]) }
      request = choice.to_s.split(":", 2)[1]
      label += ", " + _("Requested rank: %{rank}") % { rank: RANK_NAMES.fetch(request, request) } if request
      label
    end

    def makao_sort_key(card)
      [SUITS.index(card_suit(card)) || 9, RANKS.index(card_rank(card)) || 99, card]
    end

    def special_card?(card)
      joker?(card) || %w[2 3 4 A K].include?(card_rank(card))
    end

    def rank_value(card)
      index = RANKS.index(card_rank(card))
      index == nil ? 15 : index + 2
    end

    def draw_cards(state, count)
      result = []
      count.to_i.times do
        recycle(state) if state[:draw_pile].empty?
        card = state[:draw_pile].shift
        break if card == nil
        result << card
      end
      result
    end

    def recycle(state)
      return if state[:discard].length <= 1
      top = state[:discard].pop
      state[:recycle] += 1
      state[:draw_pile] = shuffled_cards(state[:discard], "#{state[:seed]}:#{state[:recycle]}")
      state[:discard] = [top]
    end

    def player_key(state, actor)
      state[:players].find { |player| same_user?(player, actor) }
    end

    def hand_for(state, actor)
      player = player_key(state, actor)
      player == nil ? [] : state[:hands][player]
    end

    def advance_player(state, actor, steps, consume_skips: true)
      index = player_index(state[:players], actor)
      steps.to_i.times do
        loop do
          index = (index + 1) % state[:players].length
          player = state[:players][index]
          break if !consume_skips || state[:skip_turns][player].to_i <= 0

          state[:skip_turns][player] -= 1
        end
      end
      player = state[:players][index]
      (state[:makao_windows] ||= {}).delete(player)
      player
    end

    def catchable_player(state, actor = nil)
      return nil if state[:phase] != :playing
      state[:players].find { |player| !same_user?(player, actor) && (state[:makao_windows] || {})[player] && state[:hands][player].length == 1 && !(state[:makao_declarations] || {})[player] }
    end

    def table_text(state)
      top = state[:discard].last
      _("Top card: %{card}; declared suit: %{suit}%{request}.") % {
        card: top == nil ? _("none") : joker?(top) ? _("joker as %{card}") % { card: makao_card_label("#{state[:declared_rank]}#{state[:declared_suit]}") } : makao_card_label(top),
        suit: SUIT_NAMES.fetch(state[:declared_suit], state[:declared_suit]),
        request: state[:requested_rank] == nil ? "" : _("; requested rank %{rank}") % { rank: RANK_NAMES.fetch(state[:requested_rank], state[:requested_rank]) }
      }
    end

    def penalty_text(state, viewer = nil)
      messages = []
      if state[:draw_penalty] > 0
        messages << n_("%{player} must draw %{count} card.", "%{player} must draw %{count} cards.", state[:draw_penalty]) % { player: participant_name(state[:current_player]), count: state[:draw_penalty] }
      elsif state[:skip_penalty] > 0
        messages << n_("%{player} faces a penalty of %{count} waiting turn.", "%{player} faces a penalty of %{count} waiting turns.", state[:skip_penalty]) % { player: participant_name(state[:current_player]), count: state[:skip_penalty] }
      end
      remaining = state[:skip_turns][player_key(state, viewer)].to_i
      messages << n_("You still have %{count} turn to wait.", "You still have %{count} turns to wait.", remaining) % { count: remaining } if remaining > 0
      messages.empty? ? _("No penalty is active.") : messages.join(" ")
    end

    def counts_text(state)
      state[:players].map { |player| _("%{player}: %{count}") % { player: participant_name(player), count: state[:hands][player].length } }.join("; ")
    end
  end
end
