# encoding: UTF-8
module GameRoomGames
  class Rummy
    def surface_spec(replay, viewer)
      state = replay.state
      own_turn = state[:phase] == :playing && same_user?(state[:current_player], viewer)
      editable = own_turn && ready?(state)
      can_discard = editable && state[:options]["discard_mode"] != "none"
      cards = hand(state, viewer).each_with_index.map do |card, index|
        choices = editable ? additions_for(state, card).map do |item|
          meld = state[:melds].find { |m| m[:id] == item[:target] }
          action = command("add", card: card, target: item[:target], mode: item[:mode].to_s)
          label = item[:mode] == :recover ? _("Replace joker in %{meld}") : _("Lay off on %{meld}")
          GameSurfaces::CardChoice.new(id: "#{item[:target]}:#{item[:mode]}", label: label % { meld: meld_label(meld) }, value: JSON.generate(action))
        end : []
        if choices.empty? && can_discard
          choices << GameSurfaces::CardChoice.new(id: "discard", label: _("Discard"), value: JSON.generate(command("discard", card: card)))
        end
        choices << GameSurfaces::CardChoice.new(id: "cancel", label: _("Cancel"), value: "") unless choices.empty?
        GameSurfaces::Card.new(id: card, label: playing_card_label(card), value: card,
          choices: choices, choice_header: _("Choose an action"), sort_keys: {
            "colour" => playing_card_sort_key(card),
            "number" => [Rules.joker?(card) ? 99 : Rules.rank(card), Rules::SUITS.index(card[1]) || 4, card],
            "none" => [index]
          })
      end
      table = state[:melds].map do |meld|
        entry = { id: meld[:id], label: meld_label(meld), details: meld_label(meld), actions: [], merges: [] }
        if own_turn && manipulation_allowed?(state)
          unless meld[:cards].any? { |c| Rules.joker?(c) }
            entry[:actions] << { label: _("Take the whole meld"), action: command("take", target: meld[:id]) }
          end
          Rules.removable(meld, identities: state[:options]["identities"]).each do |item|
            entry[:actions] << { label: _("Take %{card}") % { card: playing_card_label(item[:card]) }, action: command("take", target: meld[:id], card: item[:card]) }
          end
          state[:melds].each do |second|
            next if meld == second
            merged = Rules.validate(meld[:cards] + second[:cards], identities: state[:options]["identities"])
            next unless merged && Rules.preserves_joker?(meld, merged) && Rules.preserves_joker?(second, merged)
            entry[:merges] << { label: meld_label(second), action: command("merge", target: meld[:id], second: second[:id]) }
          end
        end
        entry
      end
      discard_choices = []
      discard_error = discard_draw_error(state, viewer)
      unless discard_error
        discard_choices = visible_discards(state).each_with_index.map do |card, index|
          { id: card, label: playing_card_label(card), action: command("draw", depth: index + 1) }
        end
      end
      GameSurfaces::MeldHandSpec.new(
        zones: [GameSurfaces::CardZoneSpec.new(id: "hand", header: _("Your hand"), cards: cards,
          empty_label: _("Your hand is empty"), hand_order: hand(state, viewer).dup, hand_epoch: "#{viewer.to_s.downcase}:#{state[:round]}")],
        turn: [state[:round], state[:turn]], editable: editable, can_discard: can_discard,
        minimum: state[:first_meld][state[:current_player]] ? 0 : state[:options]["first_meld"],
        validator: ->(groups) { meld_preview(groups, state) }, table: table, discard_choices: discard_choices,
        discard_error: discard_error, action_error: hand_action_error(state, viewer))
    end

    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      discards = visible_discards(state)
      discard_message = if state[:options]["discard_mode"] == "none"
        _("There is no discard pile in this variant.")
      elsif discards.empty?
        _("The discard pile is empty.")
      else
        discards.map { |card| playing_card_label(card) }.join(", ")
      end
      shortcuts = [
        GameShortcut.new(key: "space", label: _("draw a card"), kind: :action, action_kind: "command", action_name: "draw", payload: { "depth" => 0 }),
        surface_shortcut(key: "delete", label: _("discard the current card immediately"), command: "meld_discard"),
        surface_shortcut(key: "n", label: _("prepare a new meld"), command: "meld_new"),
        surface_shortcut(key: "f", label: _("submit all prepared melds"), command: "meld_submit"),
        surface_shortcut(key: "p", label: _("read prepared melds and their score"), command: "meld_read"),
        surface_shortcut(key: "p", modifiers: [:shift], label: _("edit prepared melds"), command: "meld_edit"),
        surface_shortcut(key: "c", label: _("browse melds on the table"), command: "meld_table"),
        announcement_shortcut(key: "d", label: _("read the discard pile"), message: discard_message),
        surface_shortcut(key: "d", modifiers: [:shift], label: _("take cards from the discard pile"), command: "meld_discard_pile"),
        announcement_shortcut(key: "e", label: _("card counts"), message: active_players(state).map { |p| "#{participant_name(p)}, #{state[:hands][p].length}" }.join("; ") + ". " + _("Draw pile: %{count}.") % { count: state[:stock].length }),
        announcement_shortcut(key: "s", label: _("scores"), message: state[:scores].map { |p, score| "#{participant_name(p)}, #{score}" }.join("; "))
      ]
      if state[:options]["discard_mode"] == "none"
        shortcuts << GameShortcut.new(key: "f", modifiers: [:shift], label: _("end your turn"), kind: :action, action_kind: "command", action_name: "end", payload: {})
      end
      [["c", "colour", _("sort cards by suit"), _("Cards sorted by ascending suit."), _("Cards sorted by descending suit.")],
       ["h", "number", _("sort cards by rank"), _("Cards sorted by ascending rank."), _("Cards sorted by descending rank.")],
       ["m", "none", _("restore acquisition order"), _("Cards restored to acquisition order."), nil]].each do |key, mode, label, ascending, descending|
        shortcuts << surface_shortcut(key: key, modifiers: [:shift], label: label, command: "sort_cards",
          payload: { "mode" => mode, "toggle" => mode != "none", "ascending_message" => ascending, "descending_message" => descending })
      end
      shortcuts
    end

    def playable_card_navigation(replay, viewer)
      state = replay.state
      return nil unless state[:phase] == :playing && same_user?(state[:current_player], viewer) && ready?(state)
      cards = hand(state, viewer)
      alternatives = GameRoomRummyPlanner.candidates(cards, identities: state[:options]["identities"]).flat_map { |m| m[:cards] }
      grouped = cards.to_h do |card|
        [card, additions_for(state, card).map { |item| command("add", card: card, target: item[:target], mode: item[:mode].to_s) }]
      end.reject { |_card, actions| actions.empty? }
      automatic = grouped.select { |card, actions| actions.one? && actions.first["mode"] == "extend" && !alternatives.include?(card) }.keys
      card_navigation_spec(hand_id: "hand", card_actions: grouped, automatic_card_ids: automatic)
    end

    def rule_sections
      [
        rule_section(:melds, _("Drawing, ordered melds and the first meld"),
          _("Two to eight players receive fourteen cards each. Two decks are used for two to four players, three for five or six, and four for seven or eight. Each deck has two jokers. Identities always uses four decks. The starting player rotates after every round."),
          _("Begin your turn by drawing once. Then you may meld, lay off or manipulate as often as the rules allow. You cannot do these actions before drawing, unless there is no available draw source. End by discarding one card; with no discard pile use Shift+F. Emptying your hand ends the round immediately, even without a final discard."),
          _("Select cards in their actual meld order. A run has at least three consecutive cards of one suit. Ace may be low before two or high after king, but a run cannot wrap from king through ace to two or contain two aces. A set has three or four equal ranks in different suits. With Identities enabled, three or four identical rank-and-suit cards from different decks also form a meld."),
          _("Each meld permits at most one joker and must contain at least two natural cards. The joker's position determines its identity: joker, three, four represents two; three, four, joker represents five. It is always spoken as joker. Cards are not reordered to repair an invalid selection."),
          _("Your first meld must reach the configured minimum, 15–90 points, default 30. Several new melds made from your own hand may reach it together; submit them in one action. Before that you cannot take discards, lay off, replace a joker, take or merge table melds. The restriction resets every round.")),
        rule_section(:discards, _("Four discard modes and an exhausted stock"),
          _("Discard mode is the only list setting: no discard pile; discarding without taking discards; taking only the top discard (default); or taking a selected discard and every newer card above it. Taken discards may stay in your hand. D reads the visible discards without opening a list: only the top card, or all cards from newest to oldest in multiple-discard mode. Shift+D takes the only available choice immediately; otherwise it lists card names from newest to oldest, with no draw-count labels or extra confirmation."),
          _("When the stock empties, all discards except the top one are shuffled into it. If drawing is impossible, you may continue with the other legal actions. After two complete circuits without drawing or placing a card from the original hand, while no draw source remains, the round is blocked. Merely taking and replacing table cards does not count as progress.")),
        rule_section(:manipulation, _("Replacing jokers and manipulating melds"),
          _("After your first meld you can replace a table joker with its actual natural card from your hand. No separate Recover joker menu item is needed. In a three-card set with a joker and two suits, first add a third natural suit; only the fourth missing suit then recovers the joker. A bare joker cannot be appended to an existing meld."),
          _("Combination manipulation is off by default. When enabled you may take a whole meld without a joker, or a legal end of a run or card of a set if at least three cards remain in a valid meld. A joker may not change identity as a side effect. Recover its joker before taking a whole meld. Merge joins two melds in their displayed order only when the result is legal."),
          _("Every taken card, including a recovered joker, must be returned to the table during this turn or incur 300 penalty points. Returning another physical copy of the same card also settles one debt. Discarding it does not. You may keep it and end the turn: the penalty is applied once and it becomes an ordinary hand card. Timeout and unreturned-card penalties add together.")),
        rule_section(:values, _("Card values and identities"),
          _("Rounding to five-point units is on by default: ranks two through nine are worth 5, ten and faces 10, a low ace 5, a high or set ace 15. With rounding off they are face value, faces 10, low ace 1 and high or set ace 11. An ace left in hand is always worth the high value. A hand joker is worth 20; a melded joker takes the represented value. An identity meld adds 10 per card.")),
        rule_section(:normal, _("Normal scoring and rummy bonuses"),
          _("In normal mode you score cards you place on the table. Taking a card subtracts its old table value from your score; laying it down again adds its new value. Replacing a joker with an equal natural card gives no artificial extra points. The round winner also receives the value of all opponents' remaining cards."),
          _("Finishing in the turn of your first meld is rummy: 200 bonus points, or 300 instead if only new melds from your hand were used, without laying off or borrowing. Finishing before anyone else first melded adds another 100. At a blocked round there is no winner bonus. The normal score limit defaults to 1000; check it only after scoring the round. The highest total wins when the limit is reached; tied leaders continue.")),
        rule_section(:elimination, _("Elimination, penalties and time"),
          _("Elimination is off by default. When enabled, melds do not earn points; only cards left in hand and penalties count. The round winner receives no hand points. Opponents' hand points are doubled for rummy, tripled for pure rummy, or quadrupled for pure rummy before anyone else melded. Penalties are not multiplied. A blocked round scores everyone's remaining hand without a multiplier."),
          _("The elimination score limit defaults to 500. Players reaching it leave after the round, not in the middle of a turn. The last remaining player wins. If everyone crosses the limit together, the lowest total wins; a tie for that lowest total is a shared victory."),
          _("Thinking time is zero (unlimited) or 20–600 seconds and covers the whole turn, including menus and prepared melds. At timeout you lose 50 points in normal mode or gain 50 in elimination. Draw one stock card only if you have not drawn yet, then immediately pass without an arbitrary discard. Unreturned cards still cost 300 each. Save is allowed at the beginning of a turn, before drawing or manipulation.")),
        rule_section(:controls, _("Hand, prepared melds and table controls"),
          _("Arrows browse the hand. Enter offers matching melds, even when there is just one. If none matches it offers Discard and Cancel. Delete discards directly. N starts a meld; Enter selects or deselects cards in order; another N keeps that group and starts the next. F submits all prepared groups. P reads them and their value; Shift+P edits or removes a group. Escape cancels the current local choice or unsubmitted draft."),
          _("Space draws from stock. D only reads the visible discard pile. Shift+D takes the only available choice immediately, or opens a discard list when there are several choices. C browses numbered table melds; Enter reads the selected meld. Its context menu contains only legal Merge, Take whole meld and individual cards to take. E reads hand and stock counts, S scores, T the turn. Shift+C/H toggles suit/rank order; Shift+M restores acquisition order."),
          _("Z and Shift+Z navigate cards which can be laid off immediately. They do not solve a multi-card meld. Automatic play requires exactly one physical card and one unambiguous direct action, with no joker replacement or alternative meld preparation; it is disabled while preparing a draft. After drawing, the cursor follows the last acquired card; after playing, it moves to the previous remaining card, or the next if there is none."))
      ]
    end

    protected

    # Older discards remain in state for recycling, not for inspection in the
    # single-discard variant. Reading never mutates that shared game state.
    def visible_discards(state)
      case state[:options]["discard_mode"]
      when "none" then []
      when "multiple" then state[:discard].reverse
      else state[:discard].last(1)
      end
    end

    def hand_action_error(state, viewer)
      return _("This action is not available now.") unless state[:phase] == :playing
      return _("It is not your turn.") unless same_user?(state[:current_player], viewer)
      return _("Draw a card first.") unless ready?(state)
      nil
    end

    def discard_draw_error(state, viewer)
      return _("There is no discard pile in this variant.") if state[:options]["discard_mode"] == "none"
      return _("Taking discards is disabled at this table.") if state[:options]["discard_mode"] == "discard"
      return _("This action is not available now.") unless state[:phase] == :playing
      return _("It is not your turn.") unless same_user?(state[:current_player], viewer)
      return _("You have already drawn this turn.") if state[:drawn] || state[:acted]
      return _("Make your first meld before taking discards.") unless state[:first_meld][state[:current_player]]
      return _("The discard pile is empty.") if state[:discard].empty?
      nil
    end

    def meld_label(meld)
      _("Meld %{number}: %{cards}") % { number: meld[:id], cards: meld[:cards].map { |card| playing_card_label(card) }.join(", ") }
    end
  end
end
