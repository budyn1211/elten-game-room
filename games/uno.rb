require "digest"
require_relative "card_game"
require_relative "../lib/game_bots"

module GameRoomGames
  class Uno < CardGame
    COLORS = %w[R Y G B].freeze
    DARK_COLORS = %w[O P T U].freeze
    COLOUR_CHOICE_ORDER = %w[Y R B G].freeze
    # Presentation order only: preserve deck construction.
    SORT_COLORS = (COLOUR_CHOICE_ORDER + DARK_COLORS).freeze
    COLOR_NAMES = {
      "R" => _("red"), "Y" => _("yellow"), "G" => _("green"), "B" => _("blue"),
      "O" => _("orange"), "P" => _("pink"), "T" => _("teal"), "U" => _("purple")
    }.freeze
    TYPE_NAMES = {
      "S" => _("skip"), "V" => _("reverse"), "D" => _("draw two"),
      "W" => _("wild"), "F" => _("wild draw four"), "E" => _("skip everyone"),
      "A" => _("discard all"), "X" => _("draw four"), "6" => _("wild draw six"),
      "T" => _("wild draw ten"), "R" => _("wild reverse draw four"),
      "C" => _("wild colour roulette"), "I" => _("draw one"),
      "H" => _("draw five"), "L" => _("flip"), "B" => _("buzzer")
    }.freeze
    DECKS = [
      OptionChoice.new(value: "classic", label: _("Classic UNO deck")),
      OptionChoice.new(value: "no_mercy", label: _("UNO No Mercy deck")),
      OptionChoice.new(value: "flip", label: _("UNO Flip deck"))
    ].freeze
    NO_MERCY_DECK = ->(options) { options["deck"].to_s == "no_mercy" }

    def id
      "uno"
    end

    def name
      _("UNO")
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
        rule_section(:hand, _("Matching cards and winning rounds"),
          _("Two to eight players begin each round with seven cards. Play one card matching the effective colour or the face of the top discard; a wild lets you choose the next colour. Cards are normally played one at a time. The first player with an empty hand wins the round, but a final draw penalty or buzzer is resolved before scoring."),
          _("The round winner gets zero points. Others add the points of cards left in their hands: number cards their value, coloured action cards 20, and wild cards 50. Eliminate a player at this score defaults to 500 (50–5000). Reaching or exceeding it eliminates that player; the remaining players start another round. The last remaining player wins the whole game."),
          _("Declare UNO when one card remains. An opponent can catch an undeclared last card in the response window and make its owner draw two. If the draw pile runs out, discarded cards except its top are shuffled back into the draw pile; held cards stay in their hands.")),
        rule_section(:decks, _("Classic, No Mercy and Flip decks"),
          _("Classic is the default deck: four colours, numbers 0–9, Skip, Reverse, Draw Two, Wild and Wild Draw Four. Skip misses the next player. Reverse changes direction; with two players it normally acts as a skip. Draw cards create a pending penalty instead of immediately choosing the next player's response."),
          _("No Mercy adds coloured Draw Four, wild Draw Six and Draw Ten, Reverse Draw Four, Skip Everyone, Discard All and Colour Roulette. Skip Everyone gives another play. Discard All removes the rest of the played colour from your hand. Roulette makes the next player draw until a non-wild card of the chosen colour appears and then ends their turn. Reverse Draw Four reverses direction and adds four; with two players its pending penalty comes back to the player who used it."),
          _("No Mercy card limit applies only to that deck: default 25, or 10–100; 0 disables it. Reaching the limit removes the player from this round and adds 250 points. They return next round unless their accumulated score eliminates them from the whole game. This is different from the voluntary draw limit."),
          _("Flip has a light and a dark side. A Flip card turns every hand and both piles over, reversing the pile order. Light uses Draw One and Wild Draw Two; dark uses Draw Five, Skip Everyone and wild colour drawing, as well as its own colours. The active side determines what matches and what a card does. This implementation's action-card scoring remains 20 for coloured and 50 for wild cards on either side.")),
        rule_section(:draw, _("Drawing and responses to penalties"),
          _("Ordinary drawing takes one card. If afterwards you still have no playable card, your turn ends automatically. Otherwise you may play. Allow drawing with a playable card is on by default. Maximum cards drawn voluntarily in one turn is 3 by default (1–20); at the limit another draw is refused rather than silently ending the turn. With optional drawing disabled, you cannot draw while already holding a legal card."),
          _("Draw until a playable card is off by default. When enabled, one ordinary draw action takes cards until a playable card is found or the available supply is exhausted. Penalty drawing is separate: it takes the full pending penalty. Skip the turn after drawing a penalty is off by default; when on, that draw always ends the turn. When off, it still ends the turn if no playable card remains."),
          _("Draw responses is on by default: you may add a draw card to the pending penalty instead of taking it. Classic requires the same draw-card type. In No Mercy coloured Draw Two/Four form one family and wild draw cards another; the responding card cannot be weaker than the last attack. Advanced responses is off and requires Draw responses: Skip or Wild passes the debt on, Reverse sends it in the opposite direction; in No Mercy Discard All and Skip Everyone cancel the pending numeric penalty. Without responses you must take the penalty."),
          _("Challenging Wild Draw Four is off by default and available only in Classic. F challenges the last such play: if its author still had a card of the previous colour, they draw four instead. If the play was justified, the challenger draws six and loses the turn. This is not an automatic check on every wild play.")),
        rule_section(:speed, _("Interceptions, hand changes and the buzzer"),
          _("Interceptions is off by default. When enabled, a matching non-wild card can be played out of turn to take over the turn; it must match both colour and face. Super interceptions, separately off, relaxes this to the same face regardless of colour. An interception becomes visible as its own play, not part of a hidden batch."),
          _("A wild card that requires a colour is placed on the discard pile first, and choosing its colour is a separate visible action. Once the wild has been played, nobody can intercept before its owner chooses the colour. Thinking time is paused during this choice; the next player's full time starts only after the colour has been selected."),
          _("Straights is off by default. When enabled, a player may start a straight only during their own turn by playing a number card. They may then quickly add consecutive number cards of the same colour, in ascending or descending order. Every card is a separate visible play. The sequence ends as soon as another player plays or intercepts; there is no separate straight timer."),
          _("With interceptions enabled, pressing Enter on a nonmatching card during another player's turn announces Too late and adds 3 penalty points to your total. The card stays in your hand and the turn does not change. This applies against people and computers, including during the bot's delay. There is no accidental-key exception. Wrong cards on your own turn, disabled interceptions and buzzer response windows do not incur this penalty. Elimination at the score limit is checked at the end of the round."),
          _("Zero and seven hand swapping is off by default. Seven exchanges your hand with a selected opponent. Zero passes every active hand along the direction of play. Buzzer cards is also off: it adds eight universal cards to Classic or No Mercy, not Flip. After one is played, all active players press B; the last draws two. Anything can be played after a buzzer."),
          _("Thinking time is 0 by default, meaning unlimited, or 1–300 seconds. Expiry takes the pending penalty, or one card if there is none, and ends the turn. Buzzer responses pause this countdown. Bot move delay is 1–5 seconds, default 1; it cannot exceed a nonzero thinking time. The pause is shortened near expiry so a bot can submit. It does not delay humans or synchronization.")),
        rule_section(:controls, _("Playing, sorting and checking the state"),
          _("Arrow keys browse your hand; Enter plays a card and opens colour or opponent choices when needed. Space draws. C reads the top card, V the current colour, E reads every player's card count, S the scores, T the turn, U declares or catches UNO, F challenges Wild Draw Four, B responds to a buzzer and G reads the pending penalty."),
          _("Shift+C toggles ascending/descending colour order. Shift+H toggles ascending/descending card-value order. Shift+D restores deal order. Sorting changes your local hand view, not anyone's cards or the turn."))
      ]
    end

    def option_definitions
      [
        OptionDefinition.new(key: "deck", label: _("UNO deck"), kind: :choice, default: "classic", choices: DECKS),
        OptionDefinition.new(key: "score_limit", label: _("Eliminate a player at this score"), kind: :integer, default: 500),
        OptionDefinition.new(key: "draw_responses", label: _("Draw responses"), kind: :boolean, default: true),
        OptionDefinition.new(key: "advanced_responses", label: _("Advanced responses"), kind: :boolean, default: false,
          visible_if: { "draw_responses" => true }),
        OptionDefinition.new(key: "bluff_challenge", label: _("Allow challenging Wild Draw Four"), kind: :boolean, default: false,
          visible_if: { "deck" => "classic" }),
        OptionDefinition.new(key: "skip_after_penalty", label: _("Skip the turn after drawing a penalty"), kind: :boolean, default: false),
        OptionDefinition.new(key: "allow_optional_draw", label: _("Allow drawing with a playable card"), kind: :boolean, default: true),
        OptionDefinition.new(key: "maximum_optional_draws", label: _("Maximum cards drawn voluntarily in one turn"), kind: :integer, default: 3,
          visible_if: { "allow_optional_draw" => true }),
        OptionDefinition.new(key: "straights", label: _("Straights"), kind: :boolean, default: false),
        OptionDefinition.new(key: "interceptions", label: _("Interceptions"), kind: :boolean, default: false),
        OptionDefinition.new(key: "super_interceptions", label: _("Super interceptions by value"), kind: :boolean, default: false,
          visible_if: { "interceptions" => true }),
        OptionDefinition.new(key: "zero_seven", label: _("Zero and seven hand swapping"), kind: :boolean, default: false),
        OptionDefinition.new(key: "buzzers", label: _("Buzzer cards"), kind: :boolean, default: false,
          visible_if: ->(options) { options["deck"].to_s != "flip" }),
        OptionDefinition.new(key: "draw_until_playable", label: _("Draw until a playable card"), kind: :boolean, default: false),
        OptionDefinition.new(key: "no_mercy_limit", label: _("No Mercy card limit; zero disables it"), kind: :integer, default: 25,
          visible_if: NO_MERCY_DECK),
        OptionDefinition.new(key: "thinking_time", label: _("Thinking time in seconds; zero means no limit"), kind: :integer, default: 0),
        OptionDefinition.new(key: "bot_delay", label: _("Bot move delay in seconds (1 to 5)"), kind: :integer, default: 1)
      ]
    end

    def rules_option_visible?(definition, options)
      return false if %w[thinking_time no_mercy_limit].include?(definition.key.to_s) && options[definition.key.to_s].to_i == 0
      super
    end

    def options_error(options, player_count: nil)
      values = normalize_options(options)
      return _("The score limit must be from 50 to 5000.") if !values["score_limit"].to_i.between?(50, 5_000)
      if values["allow_optional_draw"] && !values["maximum_optional_draws"].to_i.between?(1, 20)
        return _("The draw limit must be from 1 to 20.")
      end
      mercy = values["no_mercy_limit"].to_i
      if NO_MERCY_DECK.call(values) && mercy != 0 && !mercy.between?(10, 100)
        return _("The No Mercy card limit must be zero or from 10 to 100.")
      end
      return _("Thinking time must be from 0 to 300 seconds.") if !values["thinking_time"].to_i.between?(0, 300)
      return _("Bot move delay must be from 1 to 5 seconds.") if !values["bot_delay"].to_i.between?(1, 5)
      if values["thinking_time"].to_i > 0 && values["bot_delay"].to_i > values["thinking_time"].to_i
        return _("Bot move delay cannot exceed thinking time.")
      end
      nil
    end

    def actions_during_bot_turn?
      true
    end

    def bot_delay_revision(replay, _revision)
      penalties = replay.history.to_a.each_with_object({}) do |entry, ids|
        ids[entry.event_id.to_i] = true if entry.key.to_s.start_with?("too_late:")
      end
      ids = replay.accepted_events.to_a.map { |event| (event["__id"] || event["id"]).to_i }
      ids.reject! { |id| penalties[id] }
      [ids.length, ids.max.to_i]
    end

    def bot_move_delay(replay, actor, context: nil)
      state = replay.state
      return 0.0 if colour_choice_pending?(state) && same_user?(state[:colour_choice_player], actor)

      delay = [[state[:options]["bot_delay"].to_i, 1].max, 5].min
      deadline = state[:turn_deadline].to_i
      if same_user?(state[:current_player], actor) && deadline > 0
        # Deadlines have whole-second precision. Leave one second to submit;
        # equal settings (including 1/1) must not turn every bot move into timeout.
        now = context&.now || Time.now.to_f
        delay = [delay, [deadline - now.to_f - 1.0, 0.0].max].min
      end
      delay
    end

    def options_summary(options)
      values = normalize_options(options)
      deck = DECKS.find { |choice| choice.value == values["deck"] }&.label
      _("%{deck}; score limit %{score}; draw responses: %{responses}; optional draw limit: %{draws}; thinking time: %{time}; bot delay: %{delay} s") % {
        deck: deck, score: values["score_limit"], responses: values["draw_responses"] ? _("on") : _("off"),
        draws: values["maximum_optional_draws"], delay: values["bot_delay"],
        time: values["thinking_time"].to_i.zero? ? _("unlimited") : _("%{seconds} seconds") % { seconds: values["thinking_time"] }
      }
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
        when "choose_colour" then apply_choose_colour(state, event, actor, repository, history)
        when "draw" then apply_draw(state, event, actor, repository, history)
        when "pass" then apply_pass(state, event, actor, repository, history)
        when "uno" then apply_uno(state, event, actor, repository, history)
        when "catch" then apply_catch(state, event, actor, repository, history)
        when "challenge" then apply_challenge(state, event, actor, repository, history)
        when "turn_timeout" then apply_turn_timeout(state, event, actor, repository, history)
        when "buzz" then apply_buzz(state, event, actor, repository, history)
        else false
        end
        accepted << event if applied
      end
      Replay.new(board: nil, players: players, current_player: state[:current_player], winner: state[:winner],
        draw: false, accepted_events: accepted, history: history, state: state)
    end

    def automatic_action(replay, actor, context: nil)
      return nil if replay.finished? || !same_user?(actor, replay.players.first)
      state = replay.state
      if [:awaiting_deal, :round_complete].include?(state[:phase])
        return { "kind" => "command", "action" => "deal" }
      end
      return nil if state[:phase] != :playing || state[:buzzer_active] || !turn_deadline_reached?(state, context&.now)

      { "kind" => "command", "action" => "turn_timeout" }
    end

    def automatic_action_due?(replay, actor, context: nil)
      same_user?(actor, replay.players.first) && replay.state[:phase] == :playing && !replay.state[:buzzer_active] &&
        turn_deadline_reached?(replay.state, context&.now)
    end

    def active_actors(replay)
      state = replay.state
      return [] if state[:current_player] == nil
      return [state[:colour_choice_player]] if colour_choice_pending?(state)
      if state[:buzzer_active]
        return active_players(state).reject { |player| state[:buzzer_pressed][player] }
      end
      actors = active_players(state).select { |player| hand_for(state, player).length == 1 && !(state[:uno_declarations] || {})[player] }
      straight_actor = state[:straight_actor]
      if straight_actor != nil && active_players(state).include?(straight_actor) &&
          hand_for(state, straight_actor).any? { |card| straight_continuation?(state, straight_actor, card) }
        actors << straight_actor
      end
      actors << state[:current_player]
      if state[:options]["interceptions"] && state[:phase] == :playing
        active_players(state).each do |player|
          next if same_user?(player, state[:current_player])
          actors << player if hand_for(state, player).any? { |card| interceptable?(state, card) }
        end
      end
      actors.uniq
    end

    def legal_actions(replay, actor, context: nil)
      state = replay.state
      return [] if replay.finished? || state[:phase] != :playing || !active_players(state).any? { |player| same_user?(player, actor) }
      if colour_choice_pending?(state)
        return [] if !same_user?(state[:colour_choice_player], actor)

        return available_colors(state).map do |colour|
          { "kind" => "command", "action" => "choose_colour", "choice" => colour }
        end
      end
      if state[:buzzer_active]
        player = player_key(state, actor)
        return [] if player == nil || state[:buzzer_pressed][player]
        return [{ "kind" => "command", "action" => "buzz" }]
      end
      announcements = []
      if hand_for(state, actor).length == 1 && !(state[:uno_declarations] || {})[player_key(state, actor)]
        announcements << { "kind" => "command", "action" => "uno" }
      end
      announcements << { "kind" => "command", "action" => "catch" } if catchable_player(state, actor)
      if !same_user?(actor, state[:current_player])
        actions = hand_for(state, actor).flat_map do |card|
          if straight_continuation?(state, actor, card)
            card_actions(card, state, false, actor, straight: true)
          elsif state[:options]["interceptions"] && interceptable?(state, card)
            card_actions(card, state, true, actor)
          else
            []
          end
        end
        return announcements + actions
      end
      actions = hand_for(state, actor).flat_map do |card|
        playable?(state, card) ? card_actions(card, state, false, actor) : []
      end
      actions << { "kind" => "command", "action" => "draw" } if can_draw?(state, actor)
      actions << { "kind" => "command", "action" => "pass" } if state[:optional_draws].to_i > 0 && state[:pending_draw].zero?
      actions.concat(announcements)
      actions << { "kind" => "command", "action" => "challenge" } if state[:options]["bluff_challenge"] && state[:challenge_player] != nil
      actions
    end

    def action_for(selection, replay, actor, context: nil)
      state = replay.state
      return [:finished, nil] if replay.finished?
      if selection["kind"].to_s == "command" && selection["action"].to_s == "deal"
        return [:not_your_turn, nil] if !same_user?(actor, replay.players.first)
        return [:invalid, nil] if ![:awaiting_deal, :round_complete].include?(state[:phase]) || context&.random_source == nil
        seed = card_seed(context.random_source)
        dealer = state[:dealer_index] == nil ? seed.to_i(16) % replay.players.length : next_game_active_index(state, state[:dealer_index], 1)
        return [:ok, event_plan("deal", "#{state[:round] + 1}|#{dealer}|#{seed}|#{next_turn_deadline(state, context)}")]
      end
      if selection["kind"].to_s == "command" && selection["action"].to_s == "turn_timeout"
        return [:not_your_turn, nil] if !same_user?(actor, replay.players.first)
        return [:invalid, nil] if state[:phase] != :playing || !turn_deadline_reached?(state, context&.now)
        player = player_key(state, state[:current_player])
        return [:invalid, nil] if player == nil

        value = [player_index(state[:players], player), state[:turn_deadline].to_i, next_turn_deadline(state, context)].join("|")
        return [:ok, event_plan("turn_timeout", value)]
      end
      action = selection["action"].to_s
      action = "play" if action == "select" && selection["kind"].to_s == "card"
      legal = legal_actions(replay, actor, context: context)
      if colour_choice_pending?(state)
        choice = if action == "choose_colour"
          selection["choice"].to_s
        elsif action == "play" && selection["kind"].to_s == "card"
          selection["card_id"].to_s.empty? ? selection["card"].to_s : selection["card_id"].to_s
        else
          ""
        end
        candidate = legal.find { |item| item["action"] == "choose_colour" && item["choice"] == choice }
        return [:invalid, nil] if candidate == nil

        return [:ok, event_plan("choose_colour", "#{choice}|#{next_turn_deadline(state, context)}")]
      end
      case action
      when "play"
        raw_card = selection["card"].to_s
        if selection["kind"].to_s == "card" && raw_card.include?("|")
          card, choice = raw_card.split("|", 2)
        else
          card = selection["card_id"].to_s.empty? ? raw_card : selection["card_id"].to_s
          choice = selection["choice"].to_s
        end
        candidate = legal.find { |item| item["action"] == "play" && item["card"] == card && item["choice"].to_s == choice }
        if candidate == nil
          return [:illegal_card, nil] if !too_late_interception?(state, actor, card)
          choice = ""
        end
        staged_wild = candidate != nil && wild?(card) && !buzzer?(card)
        event_deadline = if staged_wild
          0
        elsif candidate && candidate["straight"]
          state[:turn_deadline].to_i
        else
          next_turn_deadline(state, context)
        end
        [:ok, event_plan("play", [card, choice, event_deadline].join("|"))]
      when "draw", "pass", "uno", "catch", "challenge", "buzz"
        return [:cannot_draw, nil] if action == "draw" && !legal.any? { |item| item["action"] == "draw" }
        return [:invalid, nil] if !legal.any? { |item| item["action"] == action }
        timed_value = %w[draw pass challenge buzz].include?(action) ? next_turn_deadline(state, context).to_s : ""
        timed_value = "#{catchable_player(state, actor)}|#{next_turn_deadline(state, context)}" if action == "catch"
        [:ok, event_plan(action, timed_value)]
      else
        [:invalid, nil]
      end
    end

    def surface_spec(replay, viewer)
      state = replay.state
      if colour_choice_pending?(state) && same_user?(state[:colour_choice_player], viewer)
        colours = colour_choice_order(state).map do |colour|
          GameSurfaces::Card.new(id: colour, label: COLOR_NAMES.fetch(colour), value: colour,
            choices: [], sort_keys: {})
        end
        return GameSurfaces::CardTableSpec.new(zones: [GameSurfaces::CardZoneSpec.new(
          id: "colour_choice", header: _("Choose a colour"), cards: colours,
          empty_label: _("There are no colours to choose from"), hand_order: nil, hand_epoch: nil
        )])
      end
      cards = hand_for(state, viewer).each_with_index.map do |card, index|
        choices = colour_choice_pending?(state) || too_late_interception?(state, viewer, card) ? [] : card_choices(card, state, viewer)
        GameSurfaces::Card.new(id: card, label: uno_label(card, state), value: card, choices: choices,
          choice_header: state[:options]["zero_seven"] && card_number(card) == 7 ? _("Choose a player to exchange hands with") : _("Choose a colour"), sort_keys: {
            "colour" => uno_sort_key(card),
            "number" => uno_number_sort_key(card),
            "none" => [index]
          })
      end.sort_by { |card| card.sort_keys["colour"] }
      GameSurfaces::CardTableSpec.new(zones: [GameSurfaces::CardZoneSpec.new(
        id: "hand", header: same_user?(state[:current_player], viewer) && !state[:buzzer_active] ? _("Your hand") : status_text(state, viewer),
        cards: cards, empty_label: _("Your hand is empty"),
        hand_order: hand_for(state, viewer).dup, hand_epoch: [viewer, state[:round], state[:side]].join(":"))])
    end

    def participant_scores(replay)
      replay.state[:scores].dup
    end

    def participant_status(replay, participant, connected: true)
      player = player_key(replay.state, participant)
      return _("eliminated") if player != nil && replay.state[:eliminated][player]
      return _("out of this round") if player != nil && replay.state[:round_eliminated][player]
      super
    end

    def turn_announcement(replay, viewer)
      if colour_choice_pending?(replay.state)
        return _("Choose a colour.") if same_user?(replay.state[:colour_choice_player], viewer)

        return _("%{player} is choosing a colour.") % {
          player: participant_name(replay.state[:colour_choice_player])
        }
      end
      return status_text(replay.state, viewer) if replay.state[:buzzer_active]
      super
    end

    def current_turn_shortcut_text(replay, viewer)
      announcement = super
      return announcement if announcement == nil || replay.finished? || replay.state[:turn_deadline].to_i <= 0

      remaining = [replay.state[:turn_deadline].to_i - Time.now.to_i, 0].max
      _("%{turn} %{seconds} seconds remain.") % { turn: announcement, seconds: remaining }
    end

    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      shortcuts = [
        GameShortcut.new(key: "space", label: _("draw a card"), kind: :action, action_kind: "command", action_name: "draw"),
        announcement_shortcut(key: "c", label: _("read the top card"), message: top_card_text(state)),
        announcement_shortcut(key: "v", label: _("read the current colour"), message: colour_text(state)),
        announcement_shortcut(key: "e", label: _("read card counts"), message: card_counts_text(state)),
        announcement_shortcut(key: "s", label: _("read the scores"), message: scores_text(state)),
        GameShortcut.new(key: "u", label: _("declare or catch UNO"), kind: :action, action_kind: "command", action_name: hand_for(state, viewer).length == 1 && !(state[:uno_declarations] || {})[player_key(state, viewer)] ? "uno" : (catchable_player(state, viewer) ? "catch" : "uno")),
        GameShortcut.new(key: "f", label: _("challenge Wild Draw Four"), kind: :action, action_kind: "command", action_name: "challenge"),
        announcement_shortcut(key: "g", label: _("read the draw obligation"), message: penalty_text(state)),
        surface_shortcut(key: "c", modifiers: [:shift], label: _("sort cards by colour"),
          command: "sort_cards", payload: { "mode" => "colour", "toggle" => true,
            "ascending_message" => _("Your cards are now sorted by ascending color."),
            "descending_message" => _("Your cards are now sorted by descending color.") }),
        surface_shortcut(key: "h", modifiers: [:shift], label: _("sort cards by value"),
          command: "sort_cards", payload: { "mode" => "number", "toggle" => true,
            "ascending_message" => _("Your cards are now sorted by ascending number."),
            "descending_message" => _("Your cards are now sorted by descending number.") }),
        surface_shortcut(key: "d", modifiers: [:shift], label: _("disable card sorting"),
          command: "sort_cards", payload: { "mode" => "none", "message" => _("Card sorting disabled.") })
      ]
      if state[:buzzer_active] && !state[:buzzer_pressed][player_key(state, viewer)]
        shortcuts << GameShortcut.new(key: "b", label: _("press the buzzer"), kind: :action,
          action_kind: "command", action_name: "buzz")
      end
      shortcuts
    end

    def bot_observation(replay, actor)
      state = replay.state
      { "current_player" => state[:current_player], "own_hand" => hand_for(state, actor),
        "hand_sizes" => state[:hands].transform_values(&:length), "top" => state[:discard].last,
        "colour" => state[:colour], "pending_draw" => state[:pending_draw], "scores" => state[:scores],
        "eliminated" => state[:eliminated], "round_eliminated" => state[:round_eliminated], "winner" => state[:winner] }
    end

    def bot_action_score(replay, actor, action, context: nil)
      state = replay.state
      if action["action"] == "choose_colour"
        colour = action["choice"].to_s
        return hand_for(state, actor).count { |card| !wild?(card) && card_color(card) == colour } * 45.0
      end
      return -50.0 * [state[:pending_draw].to_i, 4].max if action["action"] == "draw"
      return -300.0 if action["action"] == "pass"
      return 10_000.0 if %w[uno catch buzz].include?(action["action"])
      if action["action"] == "challenge"
        count = hand_for(state, state[:challenge_source]).length
        # A conservative prior from public hand size, not challenge_legal or
        # the source's cards. An empty remaining hand cannot be a colour bluff.
        bluff_probability = [count * 0.04, 0.45].min
        return -300 * (1 - bluff_probability) + 100 * bluff_probability
      end
      card = action["card"].to_s
      score = card_points(card) * 3.0
      score += 180 if %w[D F S V].include?(card_type(card))
      remaining = hand_for(replay.state, actor) - [card]
      remaining = remaining.reject { |other| card_color(other) == card_color(card) } if card_type(card) == "A"
      swaps = replay.state[:options]["zero_seven"] && [0, 7].include?(card_number(card))
      # Exchanges hand an empty hand to someone else, not to the actor.
      delayed = draw_penalty(state, card) > 0 || card_type(card) == "C" || buzzer?(card) ||
        (state[:pending_draw].to_i > 0 && !(state[:options]["advanced_responses"] && %w[A E].include?(card_type(card))))
      return 100_000.0 if remaining.empty? && !swaps && !delayed
      score += 2_000 if remaining.empty? && !swaps
      score += (hand_for(replay.state, actor).length - remaining.length - 1) * 180
      colour = if wild?(card)
        available_colors(state).max_by do |candidate|
          remaining.count { |other| !wild?(other) && card_color(other) == candidate }
        end
      else
        card_color(card)
      end
      if card_type(card) == "L"
        remaining = remaining.map { |other| flip_counterparts.fetch(other, other) }
        colour = card_color(flip_counterparts.fetch(state[:discard].first, card))
      end
      score += remaining.count { |other| card_color(other) == colour } * 45 unless swaps
      score -= 170 if wild?(card) && remaining.length > 1
      reversed = %w[V R].include?(card_type(card)) && active_players(state).length > 2
      next_state = reversed ? state.merge(direction: -state[:direction]) : state
      target = next_active_player(next_state, actor, 1)
      if hand_for(replay.state, target).length <= 2
        score += 250 if draw_penalty(replay.state, card) > 0 || %w[S V E].include?(card_type(card))
      end
      if replay.state[:options]["zero_seven"] && card_number(card) == 7
        chosen = seven_target(replay.state, actor, action["choice"])
        score += (remaining.length - hand_for(replay.state, chosen).length) * 180 if chosen
        score -= 100_000 if remaining.empty?
      elsif replay.state[:options]["zero_seven"] && card_number(card) == 0
        donor = previous_active_player(state, actor)
        score += (remaining.length - hand_for(state, donor).length) * 180
        score -= 100_000 if remaining.empty?
      end
      returns_turn = card_type(card) == "E" || (active_players(state).length == 2 && %w[V S R].include?(card_type(card)))
      score += 140 if returns_turn && state[:pending_draw].to_i == 0 && remaining.any? { |other| wild?(other) || card_color(other) == colour }
      score += [draw_penalty(state, card), 10].min * 15
      score
    end

    def move_error(status)
      case status
      when :illegal_card then _("That card cannot be played now.")
      when :cannot_draw then _("You cannot draw another card.")
      else super
      end
    end

    def describe_event(event, repository, replay, viewer)
      id = repository.event_id(event).to_i
      messages = replay.history.filter_map { |entry| entry.text if entry.event_id.to_i == id }
      if event["action"].to_s == "play" && same_user?(repository.actor_of(event), viewer)
        card, choice, = event["value"].to_s.split("|", 3)
        if wild?(card) && !buzzer?(card) && choice.to_s.empty? &&
            colour_choice_pending?(replay.state) && same_user?(replay.state[:colour_choice_player], viewer)
          messages << _("Choose a colour.")
        end
      end
      messages.empty? ? nil : messages
    end

    private

    def initial_state(players, options)
      { players: players, options: options, scores: players.to_h { |player| [player, 0] },
        eliminated: players.to_h { |player| [player, false] }, round: 0, dealer_index: nil,
        round_eliminated: players.to_h { |player| [player, false] },
        phase: :awaiting_deal, current_player: nil, direction: 1, seed: nil, recycle: 0,
        hands: players.to_h { |player| [player, []] }, draw_pile: [], discard: [], colour: nil,
        pending_draw: 0, pending_type: nil, optional_draws: 0, declared_uno: nil, uno_declarations: {}, uno_window: nil,
        pending_family: nil, pending_colour: nil, side: :light, mercy_cards: [],
        challenge_player: nil, challenge_legal: nil, turn_deadline: 0,
        buzzer_active: false, buzzer_pressed: {}, buzzer_player: nil, free_play: false,
        straight_actor: nil, straight_last: nil, straight_direction: nil,
        colour_choice_player: nil, colour_choice_card: nil, colour_choice_steps: nil,
        pending_finisher: nil, winner: nil }
    end

    def apply_deal(state, event, actor, repository, history)
      return false if !same_user?(actor, state[:players].first) || ![:awaiting_deal, :round_complete].include?(state[:phase])
      fields = event["value"].to_s.split("|", -1)
      return false if ![3, 4].include?(fields.length)
      round, dealer, seed = Integer(fields[0], 10), Integer(fields[1], 10), fields[2]
      deadline = fields.length == 4 ? Integer(fields[3], 10) : 0
      return false if round != state[:round] + 1 || seed !~ /\A[0-9a-f]{32}\z/
      state[:round_eliminated] = state[:players].to_h { |player| [player, false] }
      active = active_players(state)
      return false if active.length < 2 || !active.include?(state[:players][dealer])
      deck = shuffled_cards(uno_deck(state[:options]), seed)
      hands = state[:players].to_h { |player| [player, []] }
      cursor = dealer
      (active.length * 7).times do
        cursor = next_active_index(state, cursor, 1)
        hands[state[:players][cursor]] << deck.shift
      end
      first_index = deck.index { |card| !wild?(card) } || 0
      top = deck.delete_at(first_index)
      state.update(round: round, dealer_index: dealer, phase: :playing,
        current_player: state[:players][next_active_index(state, dealer, 1)], direction: 1,
        seed: seed, recycle: 0, hands: hands, draw_pile: deck, discard: [top], colour: card_color(top),
        pending_draw: 0, pending_type: nil, optional_draws: 0, declared_uno: nil, uno_declarations: {}, uno_window: nil,
        pending_family: nil, pending_colour: nil, side: :light, mercy_cards: [],
        challenge_player: nil, challenge_legal: nil, turn_deadline: deadline,
        buzzer_active: false, buzzer_pressed: {}, buzzer_player: nil, free_play: false,
        straight_actor: nil, straight_last: nil, straight_direction: nil,
        colour_choice_player: nil, colour_choice_card: nil, colour_choice_steps: nil,
        pending_finisher: nil)
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "deal:#{round}", text: _("UNO round %{round} started. First card: %{card}.") % { round: round, card: uno_label(top, state) }, event_id: id, actor: actor, kind: :deal)
      true
    rescue ArgumentError
      false
    end

    def apply_play(state, event, actor, repository, history)
      card, choice, deadline_text = event["value"].to_s.split("|", 3)
      deadline = deadline_text.to_i
      return false if colour_choice_pending?(state)

      previous_current_player = state[:current_player]
      current = same_user?(actor, state[:current_player])
      straight = !current && straight_continuation?(state, actor, card)
      interception = !current && !straight && state[:options]["interceptions"] && interceptable?(state, card)
      return false if state[:phase] != :playing || state[:buzzer_active]
      player = player_key(state, actor)
      return false if player == nil || !active_players(state).include?(player) || !state[:hands][player].include?(card)
      if !current && !interception && !straight
        return false if !too_late_interception?(state, player, card)

        # Resolve the attempt against the ordered replay, not the old screen:
        # a preceding human/bot play may have changed the interception target.
        state[:scores][player] += 3
        id = repository.event_id(event)
        history << HistoryEntry.new(key: "too_late:#{id}",
          text: _("Too late!"),
          event_id: id, actor: player, kind: :score, value: 3)
        return true
      end
      return false if current && !playable?(state, card)
      awaiting_colour = wild?(card) && !buzzer?(card) && choice.to_s.empty?
      if wild?(card) && !buzzer?(card) && !awaiting_colour
        return false if !available_colors(state).include?(choice)
      end
      selected_seven_target = nil
      if state[:options]["zero_seven"] && card_number(card) == 7
        selected_seven_target = seven_target(state, player, choice)
        return false if selected_seven_target == nil
      end
      clear_straight(state) if current || interception
      played_text = awaiting_colour ? uno_label(card, state) : played_label(card, choice, state)
      state[:hands][player].delete_at(state[:hands][player].index(card))
      previous_colour = state[:colour]
      state[:discard] << card
      state[:colour] = if awaiting_colour
        nil
      elsif wild?(card)
        buzzer?(card) ? nil : choice
      else
        card_color(card)
      end
      state[:free_play] = false
      state[:optional_draws] = 0
      state[:uno_window] = nil
      (state[:uno_declarations] ||= {}).delete(player)
      state[:challenge_player] = state[:challenge_legal] = state[:challenge_source] = nil
      type = card_type(card)
      penalty = draw_penalty(state, card)
      responding_to_penalty = state[:pending_draw] > 0
      if penalty > 0
        state[:pending_draw] += penalty
        state[:pending_type] = type
        state[:pending_family] = penalty_family(state, card)
        state[:pending_strength] = penalty
      end
      if type == "C"
        state[:pending_type] = "C"
        state[:pending_colour] = choice if !awaiting_colour
        state[:pending_family] = nil
      end
      if challenge_card?(state, card) && state[:options]["bluff_challenge"]
        state[:challenge_player] = if awaiting_colour
          nil
        else
          interception ? previous_current_player : next_active_player(state, player, 1)
        end
        state[:challenge_source] = player
        state[:challenge_legal] = !state[:hands][player].any? { |candidate| !wild?(candidate) && card_color(candidate) == previous_colour }
      end
      if type == "A"
        discarded = state[:hands][player].select { |candidate| card_color(candidate) == card_color(card) }
        state[:hands][player] -= discarded
        state[:discard].insert(state[:discard].length - 1, *discarded)
      end
      id = repository.event_id(event)
      play_key = interception ? "interception" : (straight ? "straight" : "play")
      history << HistoryEntry.new(key: "#{play_key}:#{id}", text: _("%{player} played %{card}.") % { player: participant_name(player), card: played_text }, event_id: id, actor: actor, kind: :play)
      if type == "L"
        flip_all_cards(state)
        side = state[:side] == :dark ? _("dark side") : _("light side")
        history << HistoryEntry.new(key: "flip:#{id}", text: _("Flip: %{side}. %{top}") % { side: side, top: top_text(state) }, event_id: id, actor: actor, kind: :game)
      end
      if type == "A" && !discarded.empty?
        text = n_("%{player} also discards %{count} %{colour} card.", "%{player} also discards %{count} %{colour} cards.", discarded.length) % { player: participant_name(player), count: discarded.length, colour: COLOR_NAMES.fetch(card_color(card)) }
        history << HistoryEntry.new(key: "discard_colour:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      end
      cancels_penalty = responding_to_penalty && state[:options]["advanced_responses"] && %w[A E].include?(type)
      clear_pending_penalty(state) if cancels_penalty
      steps = type == "S" && !responding_to_penalty ? 2 : 1
      steps = 0 if type == "E" && !responding_to_penalty
      if type == "V"
        state[:direction] *= -1 if active_players(state).length > 2
        steps = active_players(state).length == 2 && !responding_to_penalty ? 2 : 1
      end
      if type == "R"
        state[:direction] *= -1
        steps = active_players(state).length == 2 ? 0 : 1
      end
      if awaiting_colour
        state[:colour_choice_player] = player
        state[:colour_choice_card] = card
        state[:colour_choice_steps] = steps
      end
      state[:current_player] = if awaiting_colour
        player
      elsif straight
        previous_current_player
      elsif interception && state[:pending_draw] > 0
        previous_current_player
      else
        next_active_player(state, player, interception ? 0 : steps)
      end
      if state[:options]["zero_seven"] && card_number(card) == 7
        target = selected_seven_target
        state[:hands][player], state[:hands][target] = state[:hands][target], state[:hands][player]
        history << HistoryEntry.new(key: "swap:#{id}", text: _("%{first} exchanged hands with %{second}.") % { first: participant_name(player), second: participant_name(target) }, event_id: id, actor: actor, kind: :game)
      elsif state[:options]["zero_seven"] && card_number(card) == 0
        rotated = active_players(state).map { |owner| state[:hands][owner] }
        active_players(state).each_with_index { |owner, index| state[:hands][owner] = rotated[(index - state[:direction]) % rotated.length] }
        text = state[:direction] == 1 ? _("All active players pass their hands to the next player in seating order.") : _("All active players pass their hands to the previous player in seating order.")
        history << HistoryEntry.new(key: "rotate:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      end
      if buzzer?(card)
        state[:buzzer_active] = true
        state[:buzzer_pressed] = {}
        state[:buzzer_player] = player
        state[:turn_deadline] = 0
      elsif awaiting_colour
        state[:turn_deadline] = 0
      else
        state[:turn_deadline] = deadline if !straight
      end
      if state[:options]["zero_seven"] && [0, 7].include?(card_number(card))
        state[:uno_declarations] = {}
      end
      state[:uno_window] = player if state[:hands][player].length == 1
      if straight
        extend_straight(state, player, card)
      elsif current
        begin_straight(state, player, card)
      end
      finisher = active_players(state).find { |owner| state[:hands][owner].empty? }
      if finisher
        if state[:pending_draw] > 0 || state[:pending_colour] != nil || state[:buzzer_active] || colour_choice_pending?(state)
          state[:pending_finisher] ||= finisher
        else
          finish_round(state, finisher, id, history)
          return true
        end
      else
        apply_no_mercy(state, player, id, history, deadline: deadline)
      end
      finish_pending_round(state, id, history) if state[:phase] == :playing
      true
    end

    def apply_choose_colour(state, event, actor, repository, history)
      return false if state[:phase] != :playing || !colour_choice_pending?(state)

      player = player_key(state, actor)
      return false if player == nil || !same_user?(player, state[:colour_choice_player])

      colour, deadline_text = event["value"].to_s.split("|", 2)
      deadline = Integer(deadline_text.to_s, 10)
      return false if !available_colors(state).include?(colour)

      card = state[:colour_choice_card]
      return false if card == nil || state[:discard].last != card

      state[:colour] = colour
      state[:pending_colour] = colour if card_type(card) == "C"
      if challenge_card?(state, card) && state[:options]["bluff_challenge"] &&
          same_user?(state[:challenge_source], player)
        state[:challenge_player] = next_active_player(state, player, 1)
      end
      steps = state[:colour_choice_steps].to_i
      clear_colour_choice(state)
      state[:current_player] = next_active_player(state, player, steps)
      state[:turn_deadline] = deadline
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "colour:#{id}",
        text: _("%{player} chose %{colour}.") % {
          player: participant_name(player), colour: COLOR_NAMES.fetch(colour)
        }, event_id: id, actor: actor, kind: :game)
      finish_pending_round(state, id, history)
      true
    rescue ArgumentError
      false
    end

    def apply_draw(state, event, actor, repository, history)
      return false if state[:phase] != :playing || !same_user?(actor, state[:current_player]) || !can_draw?(state, actor)
      player = player_key(state, actor)
      clear_straight(state)
      next_deadline = event["value"].to_s.to_i
      roulette = state[:pending_type] == "C" && state[:pending_colour] != nil
      state[:uno_window] = nil
      (state[:uno_declarations] ||= {}).delete(player)
      drawn = if roulette
        draw_until(state) { |card| !wild?(card) && card_color(card) == state[:pending_colour] }
      elsif state[:pending_draw] > 0
        draw_cards(state, state[:pending_draw])
      elsif state[:options]["draw_until_playable"]
        draw_until(state) { |card| playable?(state, card) }
      else
        draw_cards(state, 1)
      end
      state[:hands][player].concat(drawn)
      penalty = state[:pending_draw] > 0 || roulette
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "draw:#{id}", text: penalty ?
        n_("%{player} drew %{count} penalty card.", "%{player} drew %{count} penalty cards.", drawn.length) % { player: participant_name(player), count: drawn.length } :
        n_("%{player} drew %{count} card.", "%{player} drew %{count} cards.", drawn.length) % { player: participant_name(player), count: drawn.length }, event_id: id, actor: actor, kind: :draw)
      clear_pending_penalty(state) if penalty
      state[:challenge_player] = nil if penalty
      state[:challenge_legal] = nil if penalty
      state[:optional_draws] += 1 if !penalty
      apply_no_mercy(state, player, id, history, deadline: next_deadline)
      finish_pending_round(state, id, history)
      return true if state[:winner] != nil || state[:phase] != :playing
      return true if !same_user?(state[:current_player], player)
      if roulette
        advance_turn(state, player, next_deadline)
      elsif penalty && state[:options]["skip_after_penalty"]
        advance_turn(state, player, next_deadline)
      elsif hand_for(state, player).none? { |card| playable?(state, card) }
        advance_turn(state, player, next_deadline)
      end
      true
    end

    def apply_pass(state, event, actor, repository, history)
      return false if !same_user?(actor, state[:current_player]) || state[:optional_draws].zero? || state[:pending_draw] > 0
      clear_straight(state)
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "pass:#{id}", text: _("%{player} ended the turn.") % { player: participant_name(actor) }, event_id: id, actor: actor, kind: :pass)
      advance_turn(state, actor, event["value"].to_s.to_i)
      true
    end

    def apply_uno(state, event, actor, repository, history)
      player = player_key(state, actor)
      return false if state[:phase] != :playing || player == nil || state[:hands][player].length != 1 || (state[:uno_declarations] || {})[player]
      state[:declared_uno] = player
      (state[:uno_declarations] ||= {})[player] = true
      history << HistoryEntry.new(key: "uno:#{repository.event_id(event)}", text: _("%{player} says UNO!") % { player: participant_name(player) }, event_id: repository.event_id(event), actor: actor, kind: :game)
      true
    end

    def apply_catch(state, event, actor, repository, history)
      target = catchable_player(state, actor)
      expected, deadline = event["value"].to_s.split("|", 2)
      return false if target == nil || player_key(state, actor) == nil || (!expected.empty? && !same_user?(expected, target))
      draw_cards(state, 2).each { |card| state[:hands][target] << card }
      state[:declared_uno] = target
      state[:uno_window] = nil
      apply_no_mercy(state, target, repository.event_id(event), history, deadline: deadline.to_i)
      history << HistoryEntry.new(key: "catch:#{repository.event_id(event)}", text: _("%{player} caught %{target} without UNO. %{target} draws two cards.") % { player: participant_name(actor), target: participant_name(target) }, event_id: repository.event_id(event), actor: actor, kind: :game)
      true
    end

    def apply_challenge(state, event, actor, repository, history)
      return false if state[:challenge_player] == nil || !same_user?(actor, state[:challenge_player])
      challenge_was_legal = state[:challenge_legal] == true
      source = state[:challenge_source] || previous_active_player(state, actor)
      target = challenge_was_legal ? actor : source
      count = challenge_was_legal ? 6 : 4
      player = player_key(state, target)
      drawn = draw_cards(state, count)
      state[:hands][player].concat(drawn)
      (state[:uno_declarations] ||= {}).delete(player)
      state[:uno_window] = nil
      id = repository.event_id(event)
      outcome = challenge_was_legal ? _("Challenge failed.") : _("Challenge succeeded.")
      payment = n_("%{player} drew %{count} penalty card.", "%{player} drew %{count} penalty cards.", drawn.length) % { player: participant_name(player), count: drawn.length }
      text = _("%{challenger} challenges the +4 played by %{source}. %{outcome} %{payment}") % { challenger: participant_name(actor), source: participant_name(source), outcome: outcome, payment: payment }
      history << HistoryEntry.new(key: "challenge:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      clear_pending_penalty(state)
      state[:challenge_player] = nil
      state[:challenge_legal] = nil
      advance_turn(state, actor, event["value"].to_s.to_i) if state[:options]["skip_after_penalty"] || challenge_was_legal
      apply_no_mercy(state, player, id, history, deadline: event["value"].to_s.to_i)
      finish_pending_round(state, id, history)
      true
    end

    def apply_buzz(state, event, actor, repository, history)
      player = player_key(state, actor)
      return false if state[:phase] != :playing || !state[:buzzer_active] || player == nil || state[:buzzer_pressed][player]

      state[:buzzer_pressed][player] = true
      id = repository.event_id(event)
      remaining = active_players(state).reject { |candidate| state[:buzzer_pressed][candidate] }
      if remaining.empty?
        cards = draw_cards(state, 2)
        state[:hands][player].concat(cards)
        state[:buzzer_active] = false
        state[:buzzer_player] = nil
        state[:free_play] = true
        state[:turn_deadline] = event["value"].to_s.to_i
        history << HistoryEntry.new(key: "buzzer:#{id}", text: _("%{player} was last at the buzzer and draws two cards.") % {
          player: participant_name(player)
        }, event_id: id, actor: actor, kind: :game)
        (state[:uno_declarations] ||= {}).delete(player)
        apply_no_mercy(state, player, id, history, deadline: event["value"].to_s.to_i)
        finish_pending_round(state, id, history)
      end
      true
    end

    def apply_turn_timeout(state, event, actor, repository, history)
      return false if state[:phase] != :playing || state[:buzzer_active] || !same_user?(actor, state[:players].first)
      player_index_text, expected_deadline_text, next_deadline_text = event["value"].to_s.split("|", 3)
      index = Integer(player_index_text, 10)
      expected_deadline = Integer(expected_deadline_text, 10)
      next_deadline = Integer(next_deadline_text, 10)
      player = state[:players][index]
      return false if player == nil || !same_user?(player, state[:current_player]) || expected_deadline <= 0 || state[:turn_deadline].to_i != expected_deadline
      clear_straight(state)

      roulette = state[:pending_type] == "C" && state[:pending_colour] != nil
      cards = if roulette
        draw_until(state) { |card| !wild?(card) && card_color(card) == state[:pending_colour] }
      else
        draw_cards(state, [state[:pending_draw], 1].max)
      end
      state[:hands][player].concat(cards)
      state[:uno_window] = nil
      (state[:uno_declarations] ||= {}).delete(player)
      clear_pending_penalty(state)
      state[:challenge_player] = nil
      state[:challenge_legal] = nil
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "timeout:#{id}", text: n_("%{player} ran out of time and drew %{count} card.", "%{player} ran out of time and drew %{count} cards.", cards.length) % {
        player: participant_name(player), count: cards.length
      }, event_id: id, actor: actor, kind: :game)
      apply_no_mercy(state, player, id, history, deadline: next_deadline)
      finish_pending_round(state, id, history)
      advance_turn(state, player, next_deadline) if state[:phase] == :playing && same_user?(state[:current_player], player)
      true
    rescue ArgumentError
      false
    end

    def playable?(state, card)
      return false if colour_choice_pending?(state)
      return false if state[:buzzer_active]
      return true if buzzer?(card)
      if state[:pending_type] == "C" && state[:pending_colour] != nil
        return false
      end
      if state[:pending_draw] > 0
        return false if !state[:options]["draw_responses"]
        penalty = draw_penalty(state, card)
        if penalty > 0
          return penalty_family(state, card) == state[:pending_family] && penalty >= pending_card_strength(state)
        end
        advanced = %w[S V W]
        advanced += %w[A E] if state[:options]["deck"].to_s == "no_mercy"
        return state[:options]["advanced_responses"] && advanced.include?(card_type(card))
      end
      return true if state[:free_play]
      wild?(card) || card_color(card) == state[:colour] || card_face(card) == card_face(state[:discard].last)
    end

    def interceptable?(state, card)
      return false if colour_choice_pending?(state)
      top = state[:discard].last
      return false if top == nil || wild?(card)
      return card_face(card) == card_face(top) if state[:options]["super_interceptions"]
      card_color(card) == card_color(top) && card_face(card) == card_face(top)
    end

    def straight_continuation?(state, actor, card)
      return false if !state[:options]["straights"] || state[:straight_actor] == nil
      return false if !same_user?(actor, state[:straight_actor])
      number = card_number(card)
      previous = state[:straight_last]
      return false if number == nil || previous == nil || card_color(card) != card_color(state[:discard].last)

      difference = number - previous.to_i
      direction = state[:straight_direction]
      direction == nil ? difference.abs == 1 : difference == direction.to_i
    end

    def begin_straight(state, player, card)
      clear_straight(state)
      return if !state[:options]["straights"] || card_number(card) == nil || state[:phase] != :playing

      state[:straight_actor] = player
      state[:straight_last] = card_number(card)
    end

    def extend_straight(state, player, card)
      previous = state[:straight_last].to_i
      state[:straight_actor] = player
      state[:straight_last] = card_number(card)
      state[:straight_direction] ||= state[:straight_last].to_i - previous
    end

    def clear_straight(state)
      state[:straight_actor] = nil
      state[:straight_last] = nil
      state[:straight_direction] = nil
    end

    def too_late_interception?(state, actor, card)
      state[:phase] == :playing && !state[:buzzer_active] && !colour_choice_pending?(state) &&
        state[:options]["interceptions"] && state[:current_player] != nil &&
        !same_user?(actor, state[:current_player]) &&
        active_players(state).any? { |player| same_user?(player, actor) } &&
        hand_for(state, actor).include?(card) && !interceptable?(state, card)
    end

    def can_draw?(state, actor)
      return false if colour_choice_pending?(state)
      return false if !same_user?(actor, state[:current_player])
      return true if state[:pending_type] == "C" && state[:pending_colour] != nil
      return true if state[:pending_draw] > 0
      return false if !state[:options]["allow_optional_draw"] && hand_for(state, actor).any? { |card| playable?(state, card) }
      state[:optional_draws].to_i < state[:options]["maximum_optional_draws"].to_i
    end

    def card_actions(card, state, interception, actor, straight: false)
      choices = if state[:options]["zero_seven"] && card_number(card) == 7
        seven_target_choices(state, player_key(state, actor))
      else
        [""]
      end
      choices.map do |choice|
        { "kind" => "card", "action" => "play", "card" => card, "card_id" => card,
          "choice" => choice, "interception" => interception, "straight" => straight }
      end
    end

    def card_choices(card, state, viewer)
      return [] if !state[:options]["zero_seven"] || card_number(card) != 7

      player = player_key(state, viewer)
      seven_target_choices(state, player).map do |token|
        target = seven_target(state, player, token)
        GameSurfaces::CardChoice.new(id: token, label: participant_name(target), value: "#{card}|#{token}")
      end
    end

    def seven_target_choices(state, player = state[:current_player])
      active_players(state).each_with_index.filter_map do |candidate, _index|
        next if same_user?(candidate, player)
        "p#{player_index(state[:players], candidate)}"
      end
    end

    def seven_target(state, player, token)
      return nil if token.to_s !~ /\Ap(\d+)\z/
      target = state[:players][Regexp.last_match(1).to_i]
      return nil if target == nil || same_user?(target, player) || !active_players(state).include?(target)

      target
    end

    def uno_deck(options = {})
      cards = case options["deck"].to_s
      when "no_mercy" then no_mercy_deck
      when "flip" then flip_deck
      else classic_deck
      end
      return cards if !options["buzzers"] || options["deck"].to_s == "flip"

      cards + buzzer_cards
    end

    def buzzer_cards
      @buzzer_cards ||= 8.times.map { |index| "NB#{index}" }.freeze
    end

    def classic_deck
      @classic_deck ||= begin
        cards = []
        COLORS.each do |color|
          cards << "#{color}0a"
          (%w[1 2 3 4 5 6 7 8 9 S V D]).each { |face| %w[a b].each { |copy| cards << "#{color}#{face}#{copy}" } }
        end
        4.times { |index| cards << "NW#{index}" << "NF#{index}" }
        cards.freeze
      end
    end

    def no_mercy_deck
      @no_mercy_deck ||= begin
        cards = []
        COLORS.each do |color|
          (0..9).each { |number| %w[a b].each { |copy| cards << "#{color}#{number}#{copy}" } }
          %w[D S V].each { |face| %w[a b c].each { |copy| cards << "#{color}#{face}#{copy}" } }
          %w[E X].each { |face| %w[a b].each { |copy| cards << "#{color}#{face}#{copy}" } }
          %w[a b c].each { |copy| cards << "#{color}A#{copy}" }
        end
        8.times { |index| cards << "NC#{index}" << "NR#{index}" }
        4.times { |index| cards << "N6#{index}" << "NT#{index}" }
        cards.freeze
      end
    end

    def flip_deck
      @flip_deck ||= flip_pairs.keys.freeze
    end

    def flip_pairs
      @flip_pairs ||= begin
        light = []
        dark = []
        COLORS.each do |color|
          (1..9).each { |number| %w[a b].each { |copy| light << "#{color}#{number}#{copy}" } }
          %w[I V S L].each { |face| %w[a b].each { |copy| light << "#{color}#{face}#{copy}" } }
        end
        DARK_COLORS.each do |color|
          (1..9).each { |number| %w[a b].each { |copy| dark << "#{color}#{number}#{copy}" } }
          %w[H V E L].each { |face| %w[a b].each { |copy| dark << "#{color}#{face}#{copy}" } }
        end
        4.times do |index|
          light << "NW#{index}" << "NF#{index}"
          dark << "NWd#{index}" << "NCd#{index}"
        end
        light.zip(dark).to_h
      end
    end

    def flip_counterparts
      @flip_counterparts ||= flip_pairs.merge(flip_pairs.invert).freeze
    end

    def card_color(card)
      wild?(card) ? nil : card.to_s[0]
    end

    def card_face(card)
      card.to_s[1]
    end

    alias card_type card_face

    def card_number(card)
      return nil if wild?(card)
      face = card_face(card)
      face =~ /\A\d\z/ ? face.to_i : nil
    end

    def wild?(card)
      card.to_s.start_with?("N")
    end

    def buzzer?(card)
      card.to_s.start_with?("NB")
    end

    def available_colors(state)
      state[:side] == :dark ? DARK_COLORS : COLORS
    end

    def colour_choice_order(state)
      state[:side] == :dark ? DARK_COLORS : COLOUR_CHOICE_ORDER
    end

    def all_colors
      COLORS + DARK_COLORS
    end

    def card_type_name(card, state = nil)
      type = card_type(card)
      return type if !wild?(card) && type =~ /\A\d\z/
      if state != nil && state[:options]["deck"].to_s == "flip"
        return _("wild draw two") if type == "F" && state[:side] == :light
        return _("wild draw colour") if type == "C" && state[:side] == :dark
      end
      TYPE_NAMES.fetch(type, type)
    end

    def face_sort_index(face)
      order = %w[0 1 2 3 4 5 6 7 8 9 V S I D X H E A L W F R T C B]
      order.index(face.to_s) || order.length
    end

    def draw_penalty(state, card)
      type = card_type(card)
      return 2 if type == "D"
      return 4 if type == "X"
      return 1 if type == "I"
      return 5 if type == "H"
      return state[:options]["deck"].to_s == "flip" ? 2 : 4 if type == "F"
      return 6 if type == "6" && wild?(card)
      return 10 if type == "T"
      return 4 if type == "R"
      0
    end

    def penalty_family(state, card)
      if state[:options]["deck"].to_s == "no_mercy"
        return "coloured_draw" if %w[D X].include?(card_type(card))
        return "wild_draw" if %w[F 6 T R].include?(card_type(card))
      end
      card_type(card)
    end

    def pending_card_strength(state)
      [state[:pending_strength].to_i, draw_penalty(state, state[:discard].last), 1].max
    end

    def challenge_card?(state, card)
      state[:options]["deck"].to_s == "classic" && card_type(card) == "F"
    end

    def clear_pending_penalty(state)
      state[:pending_draw] = 0
      state[:pending_type] = nil
      state[:pending_family] = nil
      state[:pending_colour] = nil
      state[:pending_strength] = nil
    end

    def flip_all_cards(state)
      counterpart = flip_counterparts
      state[:hands].each_value { |hand| hand.map! { |card| counterpart.fetch(card, card) } }
      state[:draw_pile] = state[:draw_pile].reverse.map { |card| counterpart.fetch(card, card) }
      state[:discard] = state[:discard].reverse.map { |card| counterpart.fetch(card, card) }
      state[:mercy_cards].map! { |card| counterpart.fetch(card, card) }
      state[:side] = state[:side] == :light ? :dark : :light
      state[:colour] = card_color(state[:discard].last)
    end

    def uno_label(card, state = nil)
      face = card_face(card)
      value = card_type_name(card, state)
      return value if wild?(card)
      _("%{colour} %{value}") % { colour: COLOR_NAMES.fetch(card_color(card)), value: value }
    end

    def played_label(card, choice, state = nil)
      return uno_label(card, state) if !wild?(card) || buzzer?(card)
      _("%{card}; colour %{colour}") % { card: uno_label(card, state), colour: COLOR_NAMES.fetch(choice, choice) }
    end

    def uno_sort_key(card)
      [SORT_COLORS.index(card_color(card)) || 99, face_sort_index(card_face(card)), card]
    end

    def uno_number_sort_key(card)
      [face_sort_index(card_face(card)), SORT_COLORS.index(card_color(card)) || 99, card]
    end

    def card_points(card)
      number = card_number(card)
      return number if number != nil
      wild?(card) ? 50 : 20
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
      return if state[:discard].length <= 1 && state[:mercy_cards].empty?
      top = state[:discard].pop
      state[:recycle] += 1
      state[:draw_pile] = shuffled_cards(state[:discard] + state[:mercy_cards], "#{state[:seed]}:#{state[:recycle]}")
      state[:discard] = [top]
      state[:mercy_cards] = []
    end

    def draw_until_playable_count(state)
      probe = state[:draw_pile].dup
      count = 0
      probe.each do |card|
        count += 1
        break if playable?(state, card)
      end
      [count, 1].max
    end

    def draw_until(state)
      result = []
      loop do
        card = draw_cards(state, 1).first
        break if card == nil
        result << card
        break if yield(card)
      end
      result
    end

    def draw_until_colour_count(state, colour)
      count = 0
      state[:draw_pile].each do |card|
        count += 1
        break if !wild?(card) && card_color(card) == colour
      end
      [count, 1].max
    end

    def turn_deadline_reached?(state, now)
      state[:turn_deadline].to_i > 0 && now != nil && now.to_i >= state[:turn_deadline].to_i
    end

    def next_turn_deadline(state, context)
      duration = state[:options]["thinking_time"].to_i
      return 0 if duration <= 0

      now = context&.now
      (now == nil ? Time.now.to_i : now.to_i) + duration
    end

    def finish_round(state, winner, event_id, history)
      clear_straight(state)
      clear_colour_choice(state)
      history << HistoryEntry.new(key: "round:#{event_id}", text: _("%{player} won the round.") % {
        player: participant_name(winner)
      }, event_id: event_id, actor: winner, kind: :round_result)
      active_players(state).each do |player|
        points = same_user?(player, winner) ? 0 : state[:hands][player].sum { |card| card_points(card) }
        state[:scores][player] += points
        history << HistoryEntry.new(key: "round_score:#{event_id}:#{player}", text: n_("%{player} received %{points} point.", "%{player} received %{points} points.", points) % {
          player: participant_name(player), points: points
        }, event_id: event_id, actor: player, kind: :score, value: points)
      end
      game_active_players(state).each do |player|
        next if state[:scores][player] < state[:options]["score_limit"].to_i
        state[:eliminated][player] = true
        history << HistoryEntry.new(key: "eliminated:#{event_id}:#{player}", text: n_("%{player} was eliminated with %{score} point.", "%{player} was eliminated with %{score} points.", state[:scores][player]) % { player: participant_name(player), score: state[:scores][player] }, event_id: event_id, actor: player, kind: :game)
      end
      remaining = game_active_players(state)
      if remaining.length <= 1
        state[:winner] = remaining.first || winner
        state[:current_player] = nil
        state[:phase] = :finished
        history << result_history(event_id: event_id, winner: state[:winner])
      else
        state[:phase] = :round_complete
        state[:current_player] = nil
      end
    end

    def apply_no_mercy(state, player, event_id, history, deadline: 0)
      return if state[:options]["deck"].to_s != "no_mercy"
      limit = state[:options]["no_mercy_limit"].to_i
      return if limit <= 0 || state[:hands][player].length < limit
      state[:mercy_cards].concat(state[:hands][player])
      state[:hands][player] = []
      state[:pending_finisher] = nil if same_user?(state[:pending_finisher], player)
      state[:round_eliminated][player] = true
      state[:scores][player] += 250
      history << HistoryEntry.new(key: "mercy:#{event_id}", text: _("%{player} reached the No Mercy card limit, receives 250 points and is out of this round.") % { player: participant_name(player) }, event_id: event_id, actor: player, kind: :game)
      remaining = active_players(state)
      if remaining.length <= 1
        finish_round(state, remaining.first, event_id, history) if remaining.first != nil
      elsif same_user?(state[:current_player], player)
        advance_turn(state, player, deadline)
      end
    end

    def finish_pending_round(state, event_id, history)
      finisher = state[:pending_finisher]
      return if finisher == nil || state[:pending_draw] > 0 || state[:pending_colour] != nil ||
        state[:buzzer_active] || colour_choice_pending?(state)

      state[:pending_finisher] = nil
      finish_round(state, finisher, event_id, history) if state[:hands][finisher].empty? && !state[:eliminated][finisher]
    end

    def advance_turn(state, actor, deadline = 0)
      clear_straight(state)
      clear_colour_choice(state)
      state[:current_player] = next_active_player(state, actor, 1)
      state[:optional_draws] = 0
      state[:free_play] = false
      state[:turn_deadline] = deadline.to_i
      state[:uno_window] = nil
      state[:declared_uno] = nil if state[:declared_uno] != nil && hand_for(state, state[:declared_uno]).length != 1
    end

    def active_players(state)
      state[:players].reject { |player| state[:eliminated][player] || state[:round_eliminated][player] }
    end

    def game_active_players(state)
      state[:players].reject { |player| state[:eliminated][player] }
    end

    def next_active_index(state, index, direction)
      cursor = index.to_i
      state[:players].length.times do
        cursor = (cursor + direction.to_i) % state[:players].length
        player = state[:players][cursor]
        return cursor if !state[:eliminated][player] && !state[:round_eliminated][player]
      end
      cursor
    end

    # A player removed by the No Mercy hand limit returns for the next round.
    # Dealer rotation must therefore ignore only permanent score eliminations.
    def next_game_active_index(state, index, direction)
      cursor = index.to_i
      state[:players].length.times do
        cursor = (cursor + direction.to_i) % state[:players].length
        return cursor if !state[:eliminated][state[:players][cursor]]
      end
      cursor
    end

    def next_active_player(state, actor, steps)
      index = player_index(state[:players], actor)
      steps.to_i.times { index = next_active_index(state, index, state[:direction]) }
      state[:players][index]
    end

    def previous_active_player(state, actor)
      index = player_index(state[:players], actor)
      state[:players][next_active_index(state, index, -state[:direction])]
    end

    def player_key(state, actor)
      state[:players].find { |player| same_user?(player, actor) }
    end

    def hand_for(state, actor)
      player = player_key(state, actor)
      player == nil ? [] : state[:hands][player]
    end

    def catchable_player(state, actor = nil)
      player = state[:uno_window]
      return nil if state[:phase] != :playing || player == nil || same_user?(player, actor)
      player if state[:hands][player].length == 1 && !(state[:uno_declarations] || {})[player]
    end

    def colour_choice_pending?(state)
      state[:colour_choice_player] != nil && state[:colour_choice_card] != nil
    end

    def clear_colour_choice(state)
      state[:colour_choice_player] = nil
      state[:colour_choice_card] = nil
      state[:colour_choice_steps] = nil
    end

    def top_text(state)
      top = state[:discard].last
      return _("There is no card on the discard pile.") if top == nil

      return _("%{card}; any card may be played.") % { card: uno_label(top, state) } if state[:free_play]

      _("%{card}; current colour: %{colour}.") % { card: uno_label(top, state), colour: COLOR_NAMES.fetch(state[:colour], state[:colour]) }
    end

    def top_card_text(state)
      top = state[:discard].last
      return _("There is no card on the discard pile.") if top == nil

      uno_label(top, state)
    end

    def colour_text(state)
      return _("Any colour may be played.") if state[:free_play]

      colour = state[:colour].to_s
      return _("There is no current colour.") if colour.empty?

      _("Current colour: %{colour}.") % { colour: COLOR_NAMES.fetch(colour, colour) }
    end

    def scores_text(state)
      state[:players].map { |player| _("%{player}: %{score}") % { player: participant_name(player), score: state[:scores][player] } }.join("; ")
    end

    def card_counts_text(state)
      state[:players].map do |player|
        "#{participant_name(player)}, #{state[:hands].fetch(player, []).length}"
      end.join(". ") + "."
    end

    def penalty_text(state)
      return _("Buzzer: press B.") if state[:buzzer_active]
      if state[:pending_type] == "C" && state[:pending_colour] != nil
        return _("%{player} must draw until a %{colour} card appears.") % { player: participant_name(state[:current_player]), colour: COLOR_NAMES.fetch(state[:pending_colour]) }
      end
      return _("There is no draw obligation.") if state[:pending_draw].zero?
      n_("%{player} must draw %{count} card.", "%{player} must draw %{count} cards.", state[:pending_draw]) % { player: participant_name(state[:current_player]), count: state[:pending_draw] }
    end

    def status_text(state, viewer)
      if colour_choice_pending?(state)
        return _("Choose a colour.") if same_user?(state[:colour_choice_player], viewer)

        return _("%{player} is choosing a colour.") % {
          player: participant_name(state[:colour_choice_player])
        }
      end
      return _("Buzzer: press B.") if state[:buzzer_active]
      _("Waiting for %{player}") % { player: participant_name(state[:current_player]) }
    end
  end
end
