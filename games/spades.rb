require "digest"
require_relative "base"
require_relative "../lib/game_bots"
require_relative "../lib/spades_learning"
require_relative "../lib/spades_round_planner"

module GameRoomGames
  class Spades < Base
    RANKS = %w[2 3 4 5 6 7 8 9 T J Q K A].freeze
    SUITS = %w[C D H S].freeze
    SUIT_NAMES = {
      "C" => _("clubs"),
      "D" => _("diamonds"),
      "H" => _("hearts"),
      "S" => _("spades")
    }.freeze
    RANK_NAMES = {
      "2" => "2",
      "3" => "3",
      "4" => "4",
      "5" => "5",
      "6" => "6",
      "7" => "7",
      "8" => "8",
      "9" => "9",
      "T" => "10",
      "J" => _("jack"),
      "Q" => _("queen"),
      "K" => _("king"),
      "A" => _("ace")
    }.freeze
    DIFFICULT_CONTRACT_THRESHOLD = {
      3 => 10,
      4 => 7,
      5 => 6,
      6 => 5
    }.freeze
    PLANNING_FULL_CONFIDENCE_MARGIN = 8.0
    PLANNING_DOMINATED_RAW_MARGIN = 40.0
    PLANNING_DOMINATED_CHOICE_PENALTY = 24.0
    PLANNING_MATCH_LOSS_RAW_THRESHOLD = 500.0
    BID_THREAT_MAX_PENALTY = 3.5
    MATCH_CLOSING_BID_PENALTY = 24.0
    CERTAIN_TRICK_NIL_PENALTY = 1_000.0
    MATCH_DEFENSE_TRICK_PRIORITY = 72.0
    FUTURE_CONTROL_DISCARD_PENALTY = 28.0
    EXPIRING_CONTROL_PRIORITY = 30.0
    # The raw hand-strength model was originally tuned around five-player
    # deals. Fewer opponents make high cards and long trump suits substantially
    # stronger, while six-player hands convert slightly fewer nominal winners.
    # These factors calibrate the mean estimate to the fair share of available
    # tricks for each supported deck size without revealing any private hand.
    BID_STRENGTH_SCALE = {
      3 => 1.901,
      4 => 1.392,
      5 => 1.003,
      6 => 0.818
    }.freeze

    UnitResult = Struct.new(
      :unit,
      :points,
      :score,
      keyword_init: true
    )
    ScoreResult = Struct.new(:scores, :units, keyword_init: true)

    class Scoring
      def initialize(players, options)
        @players = players.to_a
        @options = options
        @assignment = build_assignment
      end

      def unit_ids
        return @players.dup if @assignment == nil

        @assignment.team_ids
      end

      def members_for(unit)
        return @players if unit == "all"
        return @assignment.members_for(unit) if @assignment != nil

        @players.select { |player| player.to_s.casecmp(unit.to_s) == 0 }
      end

      def apply(bids:, tricks:, scores:)
        updated_scores = unit_ids.each_with_object({}) do |unit, result|
          result[unit] = scores.fetch(unit, 0).to_i
        end
        units = unit_ids.map do |unit|
          points, earned = score_unit(members_for(unit), bids, tricks)
          if !quicksand?
            current_bags = updated_scores[unit] % 10
            points -= ((current_bags + earned) / 10) * 100
          end
          updated_scores[unit] += points
          UnitResult.new(
            unit: unit,
            points: points,
            score: updated_scores[unit]
          )
        end
        ScoreResult.new(scores: updated_scores, units: units)
      end

      private

      def score_unit(members, bids, tricks)
        nil_players = members.select { |player| bids.fetch(player, -1).to_i == 0 }
        regular_players = members.reject { |player| bids.fetch(player, -1).to_i == 0 }
        points = 0
        bags = 0

        nil_players.each do |player|
          won = tricks.fetch(player, 0).to_i
          points += won == 0 ? 100 : -100
          if won > 0 && !quicksand?
            points += won
            bags += won
          end
        end

        if !regular_players.empty?
          bid = regular_players.sum { |player| bids.fetch(player, 0).to_i }
          won = regular_players.sum { |player| tricks.fetch(player, 0).to_i }
          contract_points, contract_bags = score_regular_contract(bid, won)
          points += contract_points
          bags += contract_bags
        end

        [points, bags]
      end

      def score_regular_contract(bid, won)
        if won < bid
          points = quicksand? ? -10 * (bid - won) : -10 * bid
          return [points, 0]
        end

        extra = won - bid
        points = if quicksand?
          10 * bid - 10 * extra
        else
          10 * bid + extra
        end
        if !quicksand?
          points += 20 if [3, 4].include?(@players.length) && [1, 2].include?(bid) && won == bid
          threshold = DIFFICULT_CONTRACT_THRESHOLD.fetch(@players.length)
          points += 10 * (bid - threshold + 1) if bid >= threshold
        end
        [points, quicksand? ? 0 : extra]
      end

      def build_assignment
        size = team_size
        return nil if size <= 0

        GameRoomTeams::Assignment.new(
          players: @players,
          team_size: size,
          seats: @options[GameRoomTeams::OPTION_KEY]
        )
      rescue ArgumentError
        nil
      end

      def team_size
        return @options["team_size"].to_i if @options.key?("team_size")

        @options["partnership"] == true ? 2 : 0
      end

      def quicksand?
        @options["quicksand"] == true
      end
    end

    def id
      "spades"
    end

    def name
      _("Spades")
    end

    def rule_sections
      # Generated from docs/rulebooks/spades.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:contracts, GameRoomRules.translate("Promise a number of tricks, then try to take them"),
          GameRoomRules.translate("A trick is one card played by each player in turn. One player wins those cards and starts the next trick. In Spades, you first promise how many tricks you will win. Taking too few is expensive, but taking far too many can hurt as well. Spades are always trumps: they beat cards of the other suits."),
          GameRoomRules.translate("Game Room supports three to six players. Three players receive 17 cards each after removing one two; four receive 13 from the full deck; five receive 10 after removing two twos; six receive eight after removing all twos. Cards rank from two up to ace. The dealer rotates, and the next player starts both bidding and the first trick."),
          GameRoomRules.translate("Individual play is the default. Four players may form two pairs; six may form three pairs or two teams of three. At three or five players everyone plays individually. Teams share a score. Their members are assigned before starting, using the proposed alternating seats or the master's chosen valid arrangement."),
          GameRoomRules.translate("Each player declares a number from zero to the size of their hand. You do not have to outbid the previous player. In a team, partners' positive declarations add together into one contract. A declaration of zero, called nil, remains that person's separate promise to win no tricks.")),
        rule_section(:tricks, GameRoomRules.translate("Following suit and breaking spades"),
          GameRoomRules.translate("The first card of a trick sets its suit. You must follow that suit if you can. Game Room has one exception: if the ace is your only spade, you may keep it when spades are led and play another suit instead. When you cannot follow suit, you may play any card; you are not forced to use a trump."),
          GameRoomRules.translate("The highest spade wins. If nobody played a spade, the highest card of the led suit wins. A high card in another suit does not win merely because it is high. For example, an ace of hearts cannot beat a low club in a club-led trick unless hearts were the led suit instead."),
          GameRoomRules.translate("You cannot lead with a spade until someone has used a spade on a trick led in another suit. This is called breaking spades. If your hand contains only spades, you may lead one anyway. Whoever wins a trick chooses the first card of the next.")),
        rule_section(:points, GameRoomRules.translate("Contracts, nils and bags"),
          GameRoomRules.translate("Under normal scoring, meeting a positive contract earns ten points per promised trick and one per extra trick. Missing the contract loses ten times the whole bid. A bid of four with five tricks therefore gives 41, while the same bid with three tricks gives minus 40, before any other bonuses or bag penalties."),
          GameRoomRules.translate("Extra tricks are called bags. They are already included in the score, but accumulate between deals: each set of ten also costs 100 points. A successful nil gives 100. Taking even one trick after declaring nil costs 100; in normal scoring its tricks also become bags. A failed nil's tricks do not help a partner fulfil an ordinary contract."),
          GameRoomRules.translate("There are also contract bonuses. With three or four players, a contract of one or two made exactly gives 20 extra points. A successful large contract adds ten per level starting at ten with three players, seven with four, six with five or five with six. For example, a four-player contract of eight earns an extra 20 for reaching levels seven and eight."),
          GameRoomRules.translate("The target score is a positive number, normally 300. Scores are checked after the deal. A sole leader at or above the target wins; a tie for first place means another deal. In a team game compare team scores, not individual tricks.")),
        rule_section(:variants, GameRoomRules.translate("Changing the kind of challenge"),
          GameRoomRules.translate("No Hell prevents the last bidder from making the sum of all declarations equal the number of tricks available. Someone will therefore miss a contract or take extra tricks. It is off by default."),
          GameRoomRules.translate("Quicksand replaces the normal contract calculation. An exact contract gives ten times the bid, each extra trick subtracts ten, and a missed contract costs ten for each missing trick. There are no accumulated bags or the normal small- and large-contract bonuses. Nil still gives or costs 100. This option is off by default."),
          GameRoomRules.translate("Suicide is for teams of two. At least one partner in each pair must declare nil; both may do so. A positive bid must be at least four. It changes bidding, not the chosen scoring system. Suicide is off by default and cannot be combined with No Hell."),
          GameRoomRules.translate("Omniscient bots, off by default, deliberately gives bots knowledge of every current hand. Ordinary bots use their own cards and public play. The mode does not change what cards people are allowed to play.")),
        rule_section(:controls, GameRoomRules.translate("Game keyboard shortcuts"),
          GameRoomRules.translate("Arrows: browse cards."),
          GameRoomRules.translate("Enter: play the selected card."),
          GameRoomRules.translate("B: during bidding, enter your bid; otherwise read the bids."),
          GameRoomRules.translate("C: read the trick cards."),
          GameRoomRules.translate("Ctrl+C: browse the trick cards."),
          GameRoomRules.translate("F: read the led suit."),
          GameRoomRules.translate("I: read your progress in the round."),
          GameRoomRules.translate("V: read everyone's tricks taken and bids."),
          GameRoomRules.translate("S: read scores and bags."),
          GameRoomRules.translate("Z: next legal card; play it automatically if it is the only unambiguous option."),
          GameRoomRules.translate("Shift+Z: previous legal card; play it automatically if it is the only unambiguous option."),
          GameRoomRules.translate("T: read whose turn it is."),
          GameRoomRules.translate("Shift+C: sort by suit or colour; press again to reverse the order."),
          GameRoomRules.translate("Shift+H: sort by rank or value; press again to reverse the order."),
          GameRoomRules.translate("Shift+M: restore the order in which cards were received."))
      ]
    end

    def minimum_players
      3
    end

    def maximum_players
      6
    end

    def supports_bots?
      true
    end

    def bot_strategy
      @bot_strategy ||= SpadesLearning::Strategy.new
    end

    def perfect_information?
      false
    end

    def bot_observation(replay, actor)
      state = replay.state
      {
        "players" => state[:players],
        "scores" => state[:scores],
        "round" => state[:round],
        "phase" => state[:phase],
        "current_player" => state[:current_player],
        "hand" => hand_for(state, actor).to_a,
        "opponent_card_counts" => state[:players].each_with_object({}) do |candidate, result|
          result[candidate] = state[:hands].fetch(candidate, []).length if !same_user?(candidate, actor)
        end,
        "bids" => state[:bids],
        "tricks" => state[:tricks],
        "current_trick" => state[:current_trick],
        "spades_broken" => state[:spades_broken],
        "winner" => state[:winner]
      }
    end

    def bot_action_score(replay, actor, action, context: nil)
      state = replay.state
      if action["action"].to_s.start_with?("bid_")
        hand = hand_for(state, actor).to_a
        strong = hand.count { |card| ["A", "K"].include?(card_rank(card)) }
        strong += hand.count { |card| card_suit(card) == "S" && RANKS.index(card_rank(card)).to_i >= 8 }
        target = [[strong, 0].max, cards_per_player(state[:players].length)].min
        bid = selection_value(action, "bid")
        return 1_000.0 - (bid - target).abs * 100.0
      end

      card = action["card"].to_s
      rank = RANKS.index(card_rank(card)).to_i
      trump = card_suit(card) == "S" ? 20 : 0
      if state[:current_trick].empty?
        return -(rank + trump).to_f
      end

      led = card_suit(state[:current_trick].first[:card])
      follows = card_suit(card) == led
      -(rank + trump).to_f + (follows ? 5.0 : 0.0)
    end

    # Fair bots compute every feature from the player's own hand, public
    # scores, bids and the public play log. A table may explicitly enable the
    # separate omniscient challenge mode, whose private decision context also
    # contains the remaining hands. The public bot observation stays fair in
    # both modes, so private cards never leak into the player-facing API.
    def bot_action_features(replay, actor, action, context: nil)
      state = replay.state
      return bidding_bot_features(state, actor, action) if state[:phase] == :bidding
      return playing_bot_features(replay, actor, action, context || bot_decision_context(replay, actor)) if state[:phase] == :playing

      {}
    end

    # This context is shared by every candidate card in one decision. Apart
    # from making decisions faster, it keeps the intentional information
    # boundary in one auditable place.
    def bot_decision_context(replay, actor, plan_round: true)
      state = replay.state
      public_context = bot_public_play_context(replay)
      hand = hand_for(state, actor).to_a
      played_cards = public_context[:played_cards]
      unseen_cards = deck_for(state[:players].length) - hand - played_cards
      omniscient = omniscient_bots?(state)
      known_hands = if omniscient
        state[:players].each_with_object({}) do |player, result|
          result[player_key(state, player)] = hand_for(state, player).to_a.dup
        end
      end
      void_suits = if omniscient
        known_hands.each_with_object({}) do |(player, cards), result|
          result[player.to_s] = SUITS.select do |suit|
            cards.none? { |card| card_suit(card) == suit }
          end
        end
      else
        public_context[:void_suits].each_with_object({}) do |(player, suits), result|
          result[player.to_s] = suits.to_a.dup
        end
      end
      state[:players].each do |player|
        next if same_user?(player, actor)

        entry = (void_suits[player.to_s] ||= [])
        SUITS.each do |suit|
          # If every unplayed card of a suit is in our own hand, public card
          # counting proves that every opponent is void even when nobody has
          # failed to follow that suit yet.
          next if unseen_cards.any? { |card| card_suit(card) == suit }

          entry << suit if !entry.include?(suit)
        end
      end
      legal = legal_cards(state, actor)
      probability_context = {
        played_cards: played_cards,
        void_suits: void_suits,
        unseen_cards: unseen_cards,
        omniscient: omniscient,
        known_hands: known_hands
      }
      win_probabilities = legal.each_with_object({}) do |card, result|
        result[card] = bot_trick_win_probability(state, actor, card, probability_context)
      end
      winning_cards = legal.select { |card| win_probabilities.fetch(card, 0.0) >= 0.5 }
      losing_cards = legal - winning_cards
      result = {
        omniscient: omniscient,
        played_cards: played_cards,
        public_plays: public_context[:public_plays],
        void_suits: void_suits,
        unseen_cards: unseen_cards,
        win_probabilities: win_probabilities,
        winning_cards: winning_cards,
        cheapest_winner: winning_cards.min_by { |card| bot_card_cost(state, card) },
        cash_contract_run: bot_cash_contract_run(state, actor, winning_cards),
        highest_loser: losing_cards.reject { |card| card_suit(card) == "S" }.max_by { |card| RANKS.index(card_rank(card)).to_i },
        score: bot_score_context(state, actor)
      }
      result[:known_hands] = known_hands if omniscient
      if state[:phase] == :playing
        result[:expiring_control] = bot_expiring_contract_control(state, actor, result)
      end
      result[:round_plan] = if plan_round
        spades_round_planner.plan(state: state, actor: actor, information: result)
      else
        { phase: state[:phase], scores: {}, raw_scores: {}, worlds: 0, exact_information: false }
      end
      if state[:phase] == :bidding
        result[:bid_threat] = bot_bid_threat_context(state, actor, result[:round_plan])
      end
      result
    end

    def bot_allied?(replay, first, second)
      assignment = team_assignment(replay.state[:options], players: replay.players)
      return super if assignment == nil

      assignment.team_index_for(first) == assignment.team_index_for(second)
    end

    def bot_reward(replay, actor)
      return 0.0 if !replay.finished?

      assignment = team_assignment(replay.state[:options], players: replay.players)
      return super if assignment == nil

      team = assignment.team_index_for(actor)
      replay.winner.to_s == "team:#{team}" ? 1.0 : -1.0
    end

    def option_definitions
      [
        OptionDefinition.new(
          key: "score_limit",
          label: _("Score limit"),
          kind: :integer,
          default: 300
        ),
        OptionDefinition.new(
          key: "team_size",
          label: _("Team arrangement"),
          kind: :choice,
          default: 0,
          choices: [
            OptionChoice.new(value: 0, label: _("Individual play")),
            OptionChoice.new(value: 2, label: _("Teams of two")),
            OptionChoice.new(value: 3, label: _("Teams of three"))
          ]
        ),
        OptionDefinition.new(
          key: "no_hell",
          label: _("No hell"),
          kind: :boolean,
          default: false,
          visible_if: ->(options) { options["suicide"] != true || options["no_hell"] == true }
        ),
        OptionDefinition.new(
          key: "quicksand",
          label: _("Quicksand scoring"),
          kind: :boolean,
          default: false
        ),
        OptionDefinition.new(
          key: "suicide",
          label: _("Suicide"),
          kind: :boolean,
          default: false,
          visible_if: ->(options) { options["no_hell"] != true || options["suicide"] == true }
        ),
        OptionDefinition.new(
          key: "omniscient_bots",
          label: _("Omniscient bots (they can see every hand)"),
          kind: :boolean,
          default: false
        )
      ]
    end

    def normalize_options(values)
      source = values.is_a?(Hash) ? values.dup : {}
      has_team_size = source.key?("team_size") || source.key?(:team_size)
      if !has_team_size
        legacy = if source.key?("partnership")
          source["partnership"]
        elsif source.key?(:partnership)
          source[:partnership]
        end
        source["team_size"] = legacy == true ? 2 : 0 if legacy != nil
      end
      super(source)
    end

    def team_size(options, player_count:)
      normalize_options(options)["team_size"].to_i
    end

    def options_error(options, player_count: nil)
      values = normalize_options(options)
      return _("The score limit must be greater than zero.") if values["score_limit"].to_i <= 0
      return _("No Hell and Suicide cannot be enabled together.") if values["no_hell"] && values["suicide"]

      team_size = values["team_size"].to_i
      if values["suicide"] && team_size != 2
        return _("Suicide requires teams of two.")
      end
      if player_count != nil
        count = player_count.to_i
        if team_size == 2 && ![4, 6].include?(count)
          return _("Teams of two require four or six players.")
        end
        if team_size == 3 && count != 6
          return _("Teams of three require exactly six players.")
        end
      end

      nil
    end

    def options_summary(options)
      values = normalize_options(options)
      arrangement = case values["team_size"].to_i
      when 2 then _("teams of two")
      when 3 then _("teams of three")
      else _("individual play")
      end
      variants = [arrangement]
      variants << _("No hell") if values["no_hell"]
      variants << _("Quicksand") if values["quicksand"]
      variants << _("Suicide") if values["suicide"]
      variants << _("omniscient bots") if values["omniscient_bots"]
      _("to %{score} points; %{variants}") % {
        score: values["score_limit"],
        variants: variants.join(", ")
      }
    end

    def replay(session, events, repository)
      players = repository.players_for(session)
      options = options_from_json(session["options"])
      scoring = Scoring.new(players, options)
      state = initial_state(players, options, scoring)
      accepted = []
      history = [starting_history(players)]

      events.each do |event|
        break if state[:winner] != nil

        applied = apply_replay_event(state, event, session, repository, history, scoring)
        accepted << event if applied
      end

      Replay.new(
        board: nil,
        players: players,
        current_player: state[:current_player],
        winner: state[:winner],
        draw: false,
        accepted_events: accepted,
        history: history,
        state: state
      )
    end

    # Training matches can contain thousands of actions. Replaying the whole
    # event stream after every card makes their running time quadratic. The
    # production replay remains the source of truth; the simulator merely uses
    # the same event applicators to extend its cached replay in place.
    def incremental_replay(replay, session, events, repository)
      return nil if replay == nil || replay.state == nil

      state = replay.state
      options = options_from_json(session["options"])
      scoring = Scoring.new(replay.players, options)
      events.each do |event|
        break if state[:winner] != nil

        if apply_replay_event(state, event, session, repository, replay.history, scoring)
          replay.accepted_events << event
        end
      end
      replay.current_player = state[:current_player]
      replay.winner = state[:winner]
      replay.draw = false
      replay
    end

    def automatic_action(replay, actor, context: nil)
      state = replay.state
      return nil if state == nil || state[:winner] != nil
      return nil if !same_user?(actor, replay.players.first)
      return nil if ![:awaiting_deal, :round_complete].include?(state[:phase])

      { "kind" => "command", "action" => "deal" }
    end

    def active_actors(replay)
      replay.current_player == nil ? [] : [replay.current_player]
    end

    def legal_actions(replay, actor, context: nil)
      state = replay.state
      return [] if state == nil || state[:winner] != nil
      return [] if !same_user?(state[:current_player], actor)

      case state[:phase]
      when :bidding
        legal_bid_values(state, actor).map do |bid|
          { "kind" => "command", "action" => "bid_#{bid}", "bid" => bid }
        end
      when :playing
        legal_cards(state, actor).map do |card|
          { "kind" => "card", "action" => "select", "zone" => "hand", "card" => card, "card_id" => card }
        end
      else
        []
      end
    end

    def playable_card_navigation(replay, viewer)
      state = replay.state
      return nil if state == nil || state[:phase] != :playing
      return nil if !same_user?(state[:current_player], viewer)

      actions = legal_actions(replay, viewer).select do |action|
        action["kind"] == "card" && action["action"] == "select"
      end
      grouped = actions.group_by { |action| action["card_id"].to_s }
      card_navigation_spec(
        hand_id: "hand",
        card_actions: grouped,
        automatic_card_ids: grouped.keys
      )
    end

    def action_for(selection, replay, actor, context: nil)
      state = replay.state
      return [:finished, nil] if replay.finished?

      if selection["kind"].to_s == "command" && selection["action"].to_s == "deal"
        return [:not_your_turn, nil] if !same_user?(actor, replay.players.first)
        return [:invalid, nil] if ![:awaiting_deal, :round_complete].include?(state[:phase])
        return [:invalid, nil] if context == nil || context.random_source == nil

        round = state[:round].to_i + 1
        seed = random_seed(context.random_source)
        dealer = if state[:dealer_index] == nil
          seed.to_i(16) % replay.players.length
        else
          (state[:dealer_index].to_i + 1) % replay.players.length
        end
        return [:ok, event_plan("deal", [round, dealer, seed].join("|"))]
      end

      return [:not_your_turn, nil] if !same_user?(state[:current_player], actor)

      case state[:phase]
      when :bidding
        return [:invalid, nil] if selection["kind"].to_s != "command"
        bid = selection_value(selection, "bid")
        if !selection.key?("bid")
          match = /\Abid_(\d+)\z/.match(selection["action"].to_s)
          return [:invalid, nil] if match == nil
          bid = match[1].to_i
        end
        return [:invalid_bid, nil] if !legal_bid_values(state, actor).include?(bid)

        [:ok, event_plan("bid", bid.to_s)]
      when :playing
        return [:invalid, nil] if selection["kind"].to_s != "card"
        return [:invalid, nil] if selection["action"].to_s != "select"
        card = selection["card"].to_s
        hand = hand_for(state, actor)
        return [:card_not_in_hand, nil] if hand == nil || !hand.include?(card)
        return [:must_follow_suit, nil] if !legal_cards(state, actor).include?(card)

        [:ok, event_plan("play", card)]
      else
        [:invalid, nil]
      end
    end

    def hand_sorting_available?(replay, viewer)
      !hand_for(replay.state, viewer).to_a.empty?
    end

    def surface_spec(replay, viewer)
      card_table_spec(replay.state, viewer)
    end

    def move_error(status)
      case status
      when :invalid_bid
        _("This bid is not allowed with the selected Spades rules.")
      when :card_not_in_hand
        _("This card is not in your hand.")
      when :must_follow_suit
        _("You must follow the suit that was led.")
      else
        super
      end
    end

    def describe_event(event, repository, replay, viewer)
      event_id = repository.event_id(event)
      entries = replay.history.select { |entry| entry.event_id.to_i == event_id }
      return nil if entries.empty?

      entries.map(&:text)
    end

    def result_text(replay)
      return nil if replay.winner == nil

      _("%{winner} won the game.") % { winner: unit_label(replay.state, replay.winner) }
    end

    def participant_scores(replay)
      state = replay.state
      scoring = Scoring.new(state[:players], state[:options])
      scoring.unit_ids.each_with_object({}) do |unit, scores|
        scoring.members_for(unit).each { |player| scores[player] = state[:scores].fetch(unit, 0) }
      end
    end

    def shortcut_features
      [:bidding] + super + [
        :hand,
        :table_cards,
        :table_cards_list,
        :led_suit,
        :round_summary,
        :round_information,
        :scores
      ]
    end

    # Keep an explicit delegator so a development soft reload replaces the
    # pre-feature implementation that older builds defined on this class.
    def game_shortcuts(replay, viewer)
      super
    end

    def shortcut_feature_data(feature, replay, viewer)
      state = replay.state
      return nil if state == nil

      case feature.to_sym
      when :bidding
        bids = legal_bid_values(state, viewer)
        if bids.empty?
          {
            message: bids_information_text(state)
          }
        else
          {
            kind: :number_input,
            label: _("make a bid"),
            prompt: _("Enter your bid. Allowed values: %{values}.") % { values: bids.join(", ") },
            action_kind: "command",
            action_name: "bid",
            value_key: "bid",
            allowed_values: bids,
            invalid_message: move_error(:invalid_bid)
          }
        end
      when :hand
        { message: hand_information_text(state, viewer) }
      when :table_cards
        { message: table_cards_information_text(state) }
      when :table_cards_list
        table_cards_browse_data(state)
      when :led_suit
        { message: led_suit_information_text(state) }
      when :round_summary
        { message: round_information_text(state) }
      when :round_information
        { message: personal_round_information_text(state, viewer) }
      when :scores
        { message: _("Scores: %{scores}.") % { scores: score_text(state, sorted: true) } }
      else
        super
      end
    end

    private

    def apply_replay_event(state, event, session, repository, history, scoring)
      actor = repository.actor_of(event, session)
      case event["action"].to_s
      when "deal"
        apply_deal(state, event, actor, repository, history)
      when "bid"
        apply_bid(state, event, actor, repository, history)
      when "play"
        apply_play(state, event, actor, repository, history, scoring)
      else
        false
      end
    end

    def bidding_bot_features(state, actor, action)
      bid = selection_value(action, "bid")
      maximum = cards_per_player(state[:players].length)
      estimate = estimated_bot_bid(state, actor)
      # The mean hand estimate is useful during play, but a contract should
      # also survive an opponent deliberately attacking it. In a three-player
      # game, two or fewer spades and several long side suits make clustered
      # K/Q/J honors especially fragile: an opponent can become void and ruff
      # them. Keep the calibrated mean intact and apply only a small bidding
      # reserve for that specific shape.
      bid_target = estimate - estimated_contract_safety_reserve(state, actor)
      difference = (bid - bid_target) / [maximum, 1].max.to_f
      hand = hand_for(state, actor).to_a
      suit_lengths = SUITS.each_with_object({}) do |suit, result|
        result[suit] = hand.count { |card| card_suit(card) == suit }
      end
      certain = estimated_certain_tricks(state, actor)
      certain_difference = (bid - certain) / [maximum, 1].max.to_f
      bid_ratio = bid.to_f / [maximum, 1].max
      table_projection = bot_table_bid_projection(state, actor, bid)
      remaining_bidders = table_projection[:remaining_bidders]
      table_target = table_projection[:target]
      projected_table_bid = table_projection[:projected]
      table_difference = (projected_table_bid - table_target) / [maximum, 1].max.to_f
      assignment = team_assignment(state[:options], players: state[:players])
      known_team_bids = if assignment == nil
        0
      else
        assignment.teammates_for(actor).reject { |player| same_user?(player, actor) }.sum do |player|
          state[:bids].fetch(player, 0).to_i
        end
      end
      score = bot_score_context(state, actor)
      nil_risk = estimated_nil_risk(state, actor)
      {
        "distance" => -difference.abs,
        "overbid" => -[difference, 0.0].max,
        "underbid" => -[-difference, 0.0].max,
        "nil_safety" => bid == 0 ? [[(2.0 - estimate) / 2.0, -1.0].max, 1.0].min : 0.0,
        "contract_size" => bid_ratio,
        "certain_tricks" => -certain_difference.abs,
        "nil_risk" => bid == 0 ? nil_risk : 0.0,
        "void_value" => suit_lengths.count { |_suit, length| length == 0 }.to_f / 3.0 * bid_ratio,
        "trump_length" => suit_lengths["S"].to_f / [maximum, 1].max * bid_ratio,
        "team_bid_balance" => assignment == nil ? 0.0 : -[known_team_bids + bid - maximum, 0].max.to_f / [maximum, 1].max,
        "table_bid_balance" => -table_difference.abs,
        "table_underbid_pressure" => -[-table_difference, 0.0].max,
        "table_overbid_pressure" => -[table_difference, 0.0].max,
        "last_bid_table_balance" => remaining_bidders == 0 ? -table_difference.abs : 0.0,
        "trailing_aggression" => [score[:deficit], 0.0].max * bid_ratio,
        "leading_caution" => [-score[:deficit], 0.0].max * bid_ratio,
        "bag_pressure_bid" => state[:options]["quicksand"] == true ? 0.0 : score[:bags].to_f / 9.0 * bid_ratio,
        "quicksand_precision" => state[:options]["quicksand"] == true ? -difference.abs : 0.0
      }
    end

    # Policy profiles may retain different learned weights, but deliberately
    # overloading the table is a rule-level tactical risk shared by every
    # Spades variant. Keep this small fixed adjustment outside those weights so
    # the same obvious correction is not trained independently for every
    # player count, partnership layout and scoring style.
    def bot_policy_score_adjustment(state, actor, action, context = nil)
      if state[:phase] == :playing
        return bot_nil_safety_score_adjustment(state, actor, action, context) +
          bot_opponent_bag_pressure_score_adjustment(state, actor, action) +
          bot_last_seat_winner_conservation_score_adjustment(state, actor, action) +
          bot_future_control_conservation_score_adjustment(state, actor, action, context) +
          bot_expiring_control_score_adjustment(state, actor, action, context) +
          bot_match_defense_score_adjustment(state, actor, action, context) +
          bot_partner_nil_risk_adjustment(action, context)
      end
      return 0.0 if state[:phase] != :bidding

      bid = selection_value(action, "bid")
      projection = bot_table_bid_projection(state, actor, bid)
      overflow = [projection[:projected] - projection[:target], 0.0].max
      -overflow * 0.85 + bot_nil_bid_context_score_adjustment(state, actor, bid) +
        bot_certain_trick_nil_score_adjustment(state, actor, bid) +
        bot_bid_threat_score_adjustment(bid, context) +
        bot_match_closing_bid_score_adjustment(state, actor, bid, context)
    end
    public :bot_policy_score_adjustment

    def bot_partner_nil_risk_adjustment(action, context)
      plan = context.is_a?(Hash) ? context[:round_plan] : nil
      risks = plan.is_a?(Hash) ? plan.fetch(:partner_nil_risks, {}) : {}
      return 0.0 unless risks.length > 1
      extra = risks.fetch(action["card"].to_s, 0.0) - risks.values.min
      # Preserve control when the difference is tiny/uncertain. A concrete
      # avoidable danger to nil weighs more than a generic saved-honour bonus.
      extra >= 0.25 ? -60.0 * extra : 0.0
    end

    # A complete-round rollout is still heuristic while most cards remain in
    # hand. In particular it can count the same fragile side-suit expectation
    # as though every opponent would cooperate with the contract. This compact
    # audit starts at the rollout's preferred bid and asks whether each of its
    # last tricks depends on an exposed honor or unsupported weak trump. When
    # two independent hazards overlap, the fallback bid is audited as well;
    # this prevents rejecting six only to accept an equally fragile five. The
    # calibrated mean hand estimate remains unchanged.
    def bot_bid_threat_context(state, actor, round_plan)
      raw_scores = round_plan.is_a?(Hash) ? round_plan.fetch(:raw_scores, {}) : {}
      planned_entry = raw_scores.max_by { |bid, score| [score.to_f, -bid.to_i] }
      planned_bid = planned_entry == nil ? 0 : planned_entry.first.to_i
      return empty_bid_threat_context if planned_bid < 2

      hand = hand_for(state, actor).to_a
      estimate = estimated_bot_bid(state, actor)
      certain = estimated_certain_tricks(state, actor).to_f
      reliance = [estimate - certain, 0.0].max
      spades = hand.count { |card| card_suit(card) == "S" }
      long_side_suits = SUITS.reject { |suit| suit == "S" }.count do |suit|
        hand.count { |card| card_suit(card) == suit } >= 5
      end

      ruff_exposure = exact_bid_ruff_exposure(state, actor)
      weak_trump = bid_weak_trump_pressure(state, actor, spades, reliance)
      correlated_shape = reliance >= 1.5 && long_side_suits > 0 ? 0.15 : 0.0
      shape_pressure = ruff_exposure + weak_trump + correlated_shape
      # Each distinct exact hazard can invalidate one marginal trick. Recheck
      # that many consecutive declarations instead of attaching the entire
      # correction only to the rollout winner. Correlated shape and table load
      # amplify a hazard but do not manufacture extra rejected tricks.
      risk_depth = [
        ruff_exposure > 0.0,
        weak_trump > 0.0
      ].count(true)
      risk_depth = 1 if shape_pressure >= 0.4 && risk_depth == 0
      lowest_risky_bid = [planned_bid - risk_depth + 1, 2].max
      highest_bid = raw_scores.keys.map(&:to_i).max.to_i
      bid_pressures = {}
      if shape_pressure >= 0.4
        (lowest_risky_bid..highest_bid).each do |candidate_bid|
          table = bid_table_load_pressure(state, actor, candidate_bid)
          bid_pressures[candidate_bid] = [shape_pressure + table[:pressure], 1.0].min
        end
      end
      # Table loading is an amplifier, not an independent reason to underbid.
      # A robust hand may safely allocate the final trick. A fragile marginal
      # trick becomes more dangerous when the known bids, or a plausible pending
      # bid, leave no spare trick with which to absorb a forecasting error.
      table = bid_table_load_pressure(state, actor, planned_bid)
      {
        planned_bid: planned_bid,
        pressure: bid_pressures.fetch(planned_bid, 0.0),
        bid_pressures: bid_pressures,
        risk_depth: risk_depth,
        lowest_risky_bid: bid_pressures.empty? ? 0 : lowest_risky_bid,
        ruff_exposure: ruff_exposure,
        weak_trump: weak_trump,
        correlated_shape: correlated_shape,
        projected_bid_low: table[:low],
        projected_bid_high: table[:high],
        table_pressure: table[:pressure]
      }
    end

    def empty_bid_threat_context
      {
        planned_bid: 0,
        pressure: 0.0,
        bid_pressures: {},
        risk_depth: 0,
        lowest_risky_bid: 0,
        ruff_exposure: 0.0,
        weak_trump: 0.0,
        correlated_shape: 0.0,
        projected_bid_low: 0.0,
        projected_bid_high: 0.0,
        table_pressure: 0.0
      }
    end

    def bot_bid_threat_score_adjustment(bid, context)
      threat = context.is_a?(Hash) ? context[:bid_threat] : nil
      return 0.0 if !threat.is_a?(Hash)

      pressures = threat[:bid_pressures]
      if pressures.is_a?(Hash)
        pressure = pressures.fetch(bid.to_i, 0.0).to_f
        return -BID_THREAT_MAX_PENALTY * pressure
      end
      return 0.0 if bid.to_i < threat[:planned_bid].to_i

      -BID_THREAT_MAX_PENALTY * threat[:pressure].to_f
    end

    # If the complete-round planner projects both its preferred declaration
    # and the declaration immediately below it as match wins, keep the safer
    # contract. The bot only needs its own score and the planner's match-win
    # projection; later opponents do not have to declare first. Repeat the
    # scoring check with the extra trick expected by the original declaration,
    # preserving the higher bid whenever lowering it would create bags whose
    # penalty removes the win.
    def bot_match_closing_bid_score_adjustment(state, actor, bid, context)
      plan = context.is_a?(Hash) ? context[:round_plan] : nil
      return 0.0 if !plan.is_a?(Hash)

      raw_scores = plan.fetch(:raw_scores, {})
      planned_entry = raw_scores.max_by { |candidate, score| [score.to_f, -candidate.to_i] }
      return 0.0 if planned_entry == nil

      planned_bid = planned_entry.first.to_i
      candidate_bid = bid.to_i
      return 0.0 if candidate_bid != planned_bid || candidate_bid < 2

      lower_bid = candidate_bid - 1
      planned_score = raw_scores.fetch(candidate_bid) { raw_scores[candidate_bid.to_s] }
      lower_score = raw_scores.fetch(lower_bid) { raw_scores[lower_bid.to_s] }
      return 0.0 if planned_score == nil || lower_score == nil
      return 0.0 if planned_score.to_f < PLANNING_MATCH_LOSS_RAW_THRESHOLD ||
        lower_score.to_f < PLANNING_MATCH_LOSS_RAW_THRESHOLD
      return 0.0 if !bot_lower_bid_safely_closes_match?(
        state, actor, lower_bid, candidate_bid
      )

      -MATCH_CLOSING_BID_PENALTY
    end

    def bot_lower_bid_safely_closes_match?(state, actor, lower_bid, original_bid)
      actor_key = player_key(state, actor)
      return false if actor_key == nil

      assignment = team_assignment(state[:options], players: state[:players])
      members = assignment == nil ? [actor_key] : assignment.teammates_for(actor_key)
      return false if members.any? do |member|
        !same_user?(member, actor_key) && state[:bids].fetch(member, -1).to_i == 0
      end

      projected_tricks = [
        original_bid.to_i,
        estimated_bot_bid(state, actor_key).ceil
      ].max
      maximum = cards_per_player(state[:players].length)
      projected_tricks = [projected_tricks, maximum].min
      unit = bot_score_context(state, actor_key)[:unit].to_s
      limit = [state[:options]["score_limit"].to_i, 1].max
      strongest_opponent = state[:scores].reject do |candidate, _score|
        candidate.to_s == unit
      end.values.map(&:to_i).max || 0
      [lower_bid.to_i, projected_tricks].uniq.all? do |won|
        projected_score = bot_projected_unit_score(
          state, actor_key, lower_bid, won, unit
        )
        projected_score >= limit && projected_score > strongest_opponent
      end
    end

    def bot_projected_unit_score(state, actor, bid, won, unit)
      bids = state[:bids].dup
      bids[player_key(state, actor)] = bid.to_i
      tricks = state[:players].each_with_object({}) do |player, result|
        player_bid = bids.fetch(player_key(state, player), 0).to_i
        result[player_key(state, player)] = player_bid == 0 ? 0 : player_bid
      end
      tricks[player_key(state, actor)] = won.to_i
      result = Scoring.new(state[:players], state[:options]).apply(
        bids: bids,
        tricks: tricks,
        scores: state[:scores]
      )
      result.scores.fetch(unit, state[:scores].fetch(unit, 0)).to_i
    end

    def exact_bid_ruff_exposure(state, actor)
      return 0.0 if !omniscient_bots?(state)

      exposure = exact_side_suit_control_profile(state, actor).values.sum do |profile|
        factor = case profile[:shortest_trump_opponent].to_i
        when 0 then 0.70
        when 1 then 0.28
        when 2 then 0.20
        else 0.10
        end
        profile[:threatened_controls].to_i * factor
      end
      [exposure, 0.85].min
    end

    def bid_weak_trump_pressure(state, actor, spades, reliance)
      return 0.0 if reliance < 1.25

      if omniscient_bots?(state)
        actor_key = player_key(state, actor)
        strongest_opponent = state[:players].reject do |player|
          same_user?(player, actor_key) || bot_state_allied?(state, actor_key, player)
        end.map do |player|
          hand_for(state, player).to_a.count { |card| card_suit(card) == "S" }
        end.max.to_i
        return 0.0 if strongest_opponent < spades + 2

        # Three or four low spades are not independent winners when a hostile
        # hand owns a substantially longer trump suit and this hand has no
        # short side suit in which to spend them. Preserve the historical rule
        # for genuinely short trump holdings, but also detect this exact
        # dominated shape without penalizing a long, top-controlled trump run.
        if spades > 2
          return 0.0 if reliance < 2.5

          top_controls = exact_top_control_cards(state, actor, "S").length
          side_lengths = SUITS.reject { |suit| suit == "S" }.map do |suit|
            hand_for(state, actor).to_a.count { |card| card_suit(card) == suit }
          end
          short_side_suits = side_lengths.count { |length| length <= 2 }
          return 0.0 if strongest_opponent < spades + 4 ||
            short_side_suits > 0 || side_lengths.max.to_i < 6

          unsupported = [spades - top_controls - short_side_suits, 0].max
          return 0.0 if unsupported < 2
        end

        spades > 2 ? 0.45 : 0.55
      else
        return 0.0 if spades > 2

        # Without private cards this remains deliberately weaker and requires
        # another signal (long-suit correlation or a loaded table) before the
        # combined threshold can affect a declaration.
        0.30
      end
    end

    def bid_table_load_pressure(state, actor, planned_bid)
      maximum = cards_per_player(state[:players].length).to_f
      target = bot_table_bid_target(state, actor)
      actor_key = player_key(state, actor)
      pending = state[:players].reject do |player|
        same_user?(player, actor_key) ||
          state[:bids].keys.any? { |bidder| same_user?(bidder, player) }
      end
      known = state[:bids].values.sum(&:to_i) + planned_bid.to_i
      ranges = pending.map do |player|
        estimate = if omniscient_bots?(state)
          estimated_bot_bid(state, player)
        else
          target / [state[:players].length, 1].max
        end
        [[estimate.floor - 1, 0].max, [estimate.ceil + 1, maximum.to_i].min]
      end
      low = known + ranges.sum { |range| range[0] }
      high = known + ranges.sum { |range| range[1] }
      pressure = if low >= maximum
        0.30
      elsif high >= maximum
        0.25
      elsif high >= target
        0.15
      else
        0.0
      end
      { low: low.to_f, high: high.to_f, pressure: pressure }
    end

    # Bidding first makes a nil intrinsically less certain because neither the
    # partner's ability to cover nor the opponents' need to take tricks is
    # known yet. Already announced bids provide modest evidence in the other
    # direction. Keep this adjustment deliberately small: hand shape and the
    # complete-round planner remain the primary nil decision makers.
    def bot_nil_bid_context_score_adjustment(state, actor, bid)
      return 0.0 if bid.to_i != 0

      players = state[:players].to_a
      actor_key = player_key(state, actor)
      return 0.0 if actor_key == nil || players.length <= 1

      announced = state[:bids].to_h.reject { |player, _value| same_user?(player, actor_key) }
      remaining = [players.length - announced.length - 1, 0].max
      adjustment = -0.6 * remaining.to_f / (players.length - 1)
      maximum = [cards_per_player(players.length), 1].max.to_f
      expected = maximum / players.length
      assignment = team_assignment(state[:options], players: players)
      teammates = if assignment == nil
        []
      else
        assignment.teammates_for(actor_key).reject { |player| same_user?(player, actor_key) }
      end
      opponents = players.reject do |player|
        same_user?(player, actor_key) || teammates.any? { |teammate| same_user?(teammate, player) }
      end

      known_teammates = teammates.select { |player| announced.key?(player) }
      known_opponents = opponents.select { |player| announced.key?(player) }
      partner_evidence = known_teammates.sum do |player|
        announced.fetch(player, 0).to_f - expected
      end
      opponent_evidence = known_opponents.sum do |player|
        announced.fetch(player, 0).to_f - expected
      end
      adjustment += partner_evidence / maximum * 1.5
      # High opposing bids mean those players hold more likely winners and are
      # less free to duck every trick solely to attack nil. This is weaker
      # evidence than a partner's cover bid because opponents remain hostile.
      adjustment += opponent_evidence / maximum * 0.6
      [[adjustment, -1.5].max, 1.0].min
    end

    # With exact hands, a cashable top control is a proof that nil cannot
    # succeed against best defence. A sampled round rollout may still prefer
    # nil because of one cooperative line, so keep this rule outside the
    # learned profiles and make the impossible declaration uncompetitive.
    # The public estimator is intentionally not used as a veto: its historical
    # "certain" feature contains nominal honours that may still be discarded or
    # ruffed when the other hands are unknown.
    def bot_certain_trick_nil_score_adjustment(state, actor, bid)
      return 0.0 if bid.to_i != 0 || !omniscient_bots?(state)
      return 0.0 if estimated_certain_tricks(state, actor).to_i <= 0

      -CERTAIN_TRICK_NIL_PENALTY
    end

    # A completed contract is normally followed by overtrick avoidance. That
    # priority must yield when an opponent can end the whole match by making the
    # contract still in progress. Reward a reliable trick only while it can
    # actually deny that opponent; do not overtake an ally or another opponent
    # who is already taking the trick away from the match threat.
    def bot_match_defense_score_adjustment(state, actor, action, context)
      return 0.0 if !context.is_a?(Hash)

      threats = bot_match_contract_threats(state, actor)
      return 0.0 if threats.empty?

      leader = if state[:current_trick].to_a.empty?
        nil
      else
        trick_winner(state[:current_trick])
      end
      if leader != nil && threats.none? { |threat| bot_state_allied?(state, threat[:player], leader) }
        return 0.0
      end

      card = action["card"].to_s
      probability = context.fetch(:win_probabilities, {}).fetch(card, 0.0).to_f
      return 0.0 if probability <= 0.0

      urgency = threats.map { |threat| threat[:urgency].to_f }.max.to_f
      MATCH_DEFENSE_TRICK_PRIORITY * probability * urgency
    end

    def bot_match_contract_threats(state, actor)
      remaining_tricks = hand_for(state, actor).to_a.length
      return [] if remaining_tricks <= 0

      limit = [state[:options]["score_limit"].to_i, 1].max
      actor_unit = bot_score_context(state, actor)[:unit].to_s
      seen_units = {}
      state[:players].each_with_object([]) do |player, result|
        next if bot_state_allied?(state, actor, player)

        unit = bot_score_context(state, player)[:unit].to_s
        next if seen_units[unit]

        seen_units[unit] = true
        contract = bot_regular_contract(state, player)
        next if contract[:bid].to_i <= 0 || contract[:need].to_i <= 0
        next if contract[:need].to_i > remaining_tricks

        projected_score = bot_projected_contract_score(state, unit, contract)
        next if projected_score < limit
        next if projected_score <= state[:scores].fetch(actor_unit, 0).to_i

        result << {
          player: player_key(state, player),
          unit: unit,
          projected_score: projected_score,
          urgency: 0.75 + 0.25 * contract[:need].to_f / remaining_tricks
        }
      end
    end

    def bot_projected_contract_score(state, unit, contract)
      tricks = state[:tricks].dup
      scoring = Scoring.new(state[:players], state[:options])
      members = scoring.members_for(unit)
      regular = members.reject { |player| state[:bids].fetch(player, -1).to_i == 0 }
      recipient = regular.first
      if recipient != nil
        tricks[recipient] = tricks.fetch(recipient, 0).to_i + contract[:need].to_i
      end
      scoring.apply(
        bids: state[:bids],
        tricks: tricks,
        scores: state[:scores]
      ).scores.fetch(unit, state[:scores].fetch(unit, 0)).to_i
    end

    # When playing last, the trick winner is certain. If our contract is
    # already complete and an opponent has also completed theirs, deliberately
    # leaving that opponent an overtrick is useful at eight bags and especially
    # at nine, where the next bag causes the standard hundred-point penalty.
    # Earlier seats receive no correction because later cards may change the
    # winner; Quicksand has no persistent bags at all.
    def bot_opponent_bag_pressure_score_adjustment(state, actor, action)
      return 0.0 if state[:options]["quicksand"] == true
      return 0.0 if state[:current_trick].to_a.length != state[:players].to_a.length - 1
      return 0.0 if bot_contract_remaining(state, actor) > 0

      actor_key = player_key(state, actor)
      card = action["card"].to_s
      return 0.0 if actor_key == nil || card.empty?

      assignment = team_assignment(state[:options], players: state[:players])
      if assignment != nil
        active_partner_nil = assignment.teammates_for(actor_key).any? do |player|
          !same_user?(player, actor_key) &&
            state[:bids].fetch(player, -1).to_i == 0 &&
            state[:tricks].fetch(player, 0).to_i == 0
        end
        return 0.0 if active_partner_nil
      end

      completed_trick = state[:current_trick] + [{ player: actor_key, card: card }]
      winner = trick_winner(completed_trick)
      return 0.0 if winner == nil || bot_state_allied?(state, actor_key, winner)
      return 0.0 if state[:bids].fetch(player_key(state, winner), -1).to_i == 0
      return 0.0 if bot_regular_contract(state, winner)[:need] > 0

      bags = bot_score_context(state, winner)[:bags].to_i
      return 0.0 if bags < 8

      bags >= 9 ? 8.0 : 3.0
    end

    # Several cards can have exactly the same immediate result when the bot is
    # last to play. While a regular contract is still outstanding, prefer the
    # winner that preserves the greatest number of mathematically certain top
    # spades. Once every remaining required trick is still covered, prefer the
    # alternative that leaves the smallest surplus of those controls. This
    # prevents wasting an ace that is needed later without forcing a completed
    # contract to retain an avoidable future overtrick.
    def bot_last_seat_winner_conservation_score_adjustment(state, actor, action)
      players = state[:players].to_a
      return 0.0 if state[:current_trick].to_a.length != players.length - 1

      actor_key = player_key(state, actor)
      return 0.0 if actor_key == nil || state[:bids].fetch(actor_key, -1).to_i == 0

      card = action["card"].to_s
      return 0.0 if card.empty?

      winning_cards = legal_cards(state, actor).select do |candidate|
        completed = state[:current_trick] + [{ player: actor_key, card: candidate }]
        same_user?(trick_winner(completed), actor_key)
      end
      return 0.0 if winning_cards.length < 2 || !winning_cards.include?(card)

      need_after = [bot_contract_remaining(state, actor) - 1, 0].max
      candidates = winning_cards.map do |candidate|
        [candidate, bot_guaranteed_top_spades_after(state, actor_key, candidate)]
      end
      safe = candidates.select { |_candidate, controls| controls >= need_after }
      preferred = if !safe.empty?
        minimum_surplus = safe.map { |_candidate, controls| controls - need_after }.min
        exact = safe.select { |_candidate, controls| controls - need_after == minimum_surplus }
        if need_after > 0
          exact.min_by { |candidate, _controls| bot_card_cost(state, candidate) }
        else
          exact.max_by { |candidate, _controls| bot_card_cost(state, candidate) }
        end
      else
        maximum_controls = candidates.map(&:last).max
        candidates.select { |_candidate, controls| controls == maximum_controls }
          .min_by { |candidate, _controls| bot_card_cost(state, candidate) }
      end

      # Protecting an otherwise uncovered required trick is a hard tactical
      # constraint. When every candidate already keeps the contract secure,
      # surplus control is only a modest bag-avoidance preference: the round
      # planner may override it to break an opponent's contract.
      strength = safe.length == candidates.length ? 3.0 : 18.0
      preferred.first == card ? strength : -strength
    end

    # Top spades form a conservative, public-information proof of future tricks:
    # their ownership distribution is irrelevant until the first outstanding
    # spade not held by the actor is reached. Reading the union of remaining
    # hands reveals no private location and therefore keeps fair bots fair.
    def bot_guaranteed_top_spades_after(state, actor, played_card)
      actor_hand = hand_for(state, actor).to_a.dup
      index = actor_hand.index(played_card)
      actor_hand.delete_at(index) if index != nil

      remaining = state[:hands].to_h.values.flat_map(&:to_a)
      index = remaining.index(played_card)
      remaining.delete_at(index) if index != nil
      remaining.select { |candidate| card_suit(candidate) == "S" }
        .sort_by { |candidate| -RANKS.index(card_rank(candidate)).to_i }
        .take_while { |candidate| actor_hand.include?(candidate) }
        .length
    end

    # Do not throw away a newly promoted side-suit winner underneath a card
    # which has already won the current trick. This is provable from public
    # cards alone in cases such as KC under AC, so the protection is available
    # to fair bots as well as to the perfect-information challenge mode.
    def bot_future_control_conservation_score_adjustment(state, actor, action, context)
      card = action["card"].to_s
      return 0.0 if !bot_future_control_discard?(state, actor, card, context)

      -FUTURE_CONTROL_DISCARD_PENALTY
    end

    def bot_future_control_discard?(state, actor, card, context = nil)
      trick = state[:current_trick].to_a
      return false if trick.empty? || bot_contract_remaining(state, actor) <= 0

      actor_key = player_key(state, actor)
      return false if actor_key == nil || state[:bids].fetch(actor_key, -1).to_i == 0
      return false if card.to_s.empty?

      completed = trick + [{ player: actor_key, card: card }]
      temporarily_winning = same_user?(trick_winner(completed), actor_key)

      suit = card_suit(card)
      rank = RANKS.index(card_rank(card)).to_i
      cheaper_loser = legal_cards(state, actor).any? do |candidate|
        next false if card_suit(candidate) != suit
        next false if RANKS.index(card_rank(candidate)).to_i >= rank

        candidate_trick = trick + [{ player: actor_key, card: candidate }]
        !same_user?(trick_winner(candidate_trick), actor_key)
      end
      return false if !cheaper_loser

      known_hands = context.is_a?(Hash) ? context[:known_hands] : nil
      if temporarily_winning
        return false if !known_hands.is_a?(Hash)

        return bot_last_opponent_overcard_promotes_control?(
          state, actor_key, card, known_hands
        )
      end
      if known_hands.is_a?(Hash)
        ordered = state[:players].flat_map do |player|
          key = player_key(state, player)
          known_hands.fetch(key) { hand_for(state, key).to_a }.map { |candidate| [key, candidate] }
        end.select { |_player, candidate| card_suit(candidate) == suit }
          .sort_by { |_player, candidate| -RANKS.index(card_rank(candidate)).to_i }
        controls = ordered.take_while { |player, _candidate| same_user?(player, actor_key) }
          .map(&:last)
        return controls.include?(card)
      end

      played = context.is_a?(Hash) ? context.fetch(:played_cards, []).to_a : []
      accounted = played + trick.map { |play| play[:card].to_s } + hand_for(state, actor_key).to_a
      deck_for(state[:players].length).none? do |candidate|
        card_suit(candidate) == suit &&
          RANKS.index(card_rank(candidate)).to_i > rank &&
          !accounted.include?(candidate)
      end
    end
    public :bot_future_control_discard?

    # The existing conservation rule normally sees a card only after it is
    # already losing. An omniscient bot in the penultimate seat can instead
    # know that its temporarily winning honor will be covered by the final
    # opponent. Preserve that honor when the covering card promotes it in the
    # hypothetical cheap-duck continuation.
    def bot_last_opponent_overcard_promotes_control?(state, actor, card, known_hands)
      trick = state[:current_trick].to_a
      return false if trick.empty?

      led_suit = card_suit(trick.first[:card])
      return false if card_suit(card) != led_suit

      actor_index = state[:players].index { |player| same_user?(player, actor) }
      return false if actor_index == nil

      remaining = state[:players].length - trick.length - 1
      return false if remaining != 1

      last_player = state[:players][(actor_index + 1) % state[:players].length]
      return false if bot_state_allied?(state, actor, last_player)

      last_key = player_key(state, last_player)
      last_hand = known_hands.fetch(last_key) { hand_for(state, last_key).to_a }
      legal_replies = legal_cards_for_led_suit(last_hand, led_suit)
      return false if legal_replies.empty?

      rank = RANKS.index(card_rank(card)).to_i
      cover = legal_replies.select do |candidate|
        card_suit(candidate) == led_suit &&
        RANKS.index(card_rank(candidate)).to_i > rank
      end.min_by { |candidate| RANKS.index(card_rank(candidate)).to_i }
      return false if cover == nil

      remaining_suit = state[:players].flat_map do |player|
        key = player_key(state, player)
        known_hands.fetch(key) { hand_for(state, key).to_a }
          .map { |candidate| [key, candidate] }
      end.select { |_player, candidate| card_suit(candidate) == led_suit }
      cover_index = remaining_suit.index do |player, candidate|
        same_user?(player, last_key) && candidate == cover
      end
      remaining_suit.delete_at(cover_index) if cover_index != nil
      controls = remaining_suit.sort_by do |_player, candidate|
        -RANKS.index(card_rank(candidate)).to_i
      end.take_while { |player, _candidate| same_user?(player, actor) }
        .map(&:last)
      controls.include?(card)
    end

    # When a bot has the lead, a top side-suit run may have only one or two
    # safe cashing opportunities before a short opponent can ruff. Prefer a
    # currently winning card from that run over a low card of the same suit.
    # Drawing trump or switching suits remains available to the round planner.
    def bot_expiring_control_score_adjustment(state, actor, action, context)
      control = if context.is_a?(Hash) && context.key?(:expiring_control)
        context[:expiring_control]
      else
        bot_expiring_contract_control(state, actor, context)
      end
      return 0.0 if control == nil

      card = action["card"].to_s
      return EXPIRING_CONTROL_PRIORITY if control[:control_cards].include?(card)
      return -EXPIRING_CONTROL_PRIORITY if card_suit(card) == control[:suit]

      0.0
    end

    def bot_expiring_contract_control(state, actor, context = nil)
      return nil if !state[:current_trick].to_a.empty?
      return nil if bot_contract_remaining(state, actor) <= 0

      exact = omniscient_bots?(state) ||
        (context.is_a?(Hash) && context[:known_hands].is_a?(Hash))
      return nil if !exact

      legal = legal_cards(state, actor)
      candidates = exact_side_suit_control_profile(state, actor).values.filter_map do |profile|
        next if profile[:safe_controls].to_i <= 0
        next if profile[:threatened_controls].to_i <= 0
        next if profile[:shortest_trump_opponent].to_i > 2

        controls = profile[:control_cards].select { |card| legal.include?(card) }
        next if controls.empty?

        profile.merge(
          control_cards: controls,
          preferred: controls.min_by { |card| bot_card_cost(state, card) }
        )
      end
      candidates.min_by do |profile|
        [profile[:shortest_trump_opponent], -profile[:threatened_controls], bot_card_cost(state, profile[:preferred])]
      end
    end
    public :bot_expiring_contract_control

    # Fixed nil safety is intentionally independent from trained profile
    # weights and from the round planner. If a rollout is tied or unavailable,
    # the ordinary Spades policy still may not choose a card an opponent can
    # deliberately duck under. Among cards guaranteed to lose the trick, shed
    # the highest one first.
    def bot_nil_safety_score_adjustment(state, actor, action, context)
      actor_key = player_key(state, actor)
      return 0.0 if actor_key == nil
      return 0.0 if state[:bids].fetch(actor_key, -1).to_i != 0
      return 0.0 if state[:tricks].fetch(actor_key, 0).to_i != 0

      card = action["card"].to_s
      return 0.0 if card.empty?

      risk = bot_nil_retention_risk(state, actor_key, card, context)
      rank_value = RANKS.index(card_rank(card)).to_i / (RANKS.length - 1).to_f
      -80.0 * risk + 6.0 * rank_value * (1.0 - risk)
    end

    # Estimate whether the nil bidder can be left winning after all remaining
    # seats act. With complete hands this is a hostile exact calculation:
    # opponents duck whenever possible, while partners cover whenever
    # possible. Fair bots use the same method inside every sampled planning
    # world; outside the planner they retain a conservative public estimate.
    def bot_nil_retention_risk(state, actor, card, context = nil)
      actor_key = player_key(state, actor)
      return 0.0 if actor_key == nil

      trick = state[:current_trick] + [{ player: actor_key, card: card }]
      return 0.0 if !same_user?(trick_winner(trick), actor_key)

      remaining = state[:players].length - trick.length
      return 1.0 if remaining <= 0

      known_hands = context.is_a?(Hash) ? context[:known_hands] : nil
      if known_hands.is_a?(Hash)
        current = actor_key
        remaining.times do
          current = next_player(state[:players], current)
          current_key = player_key(state, current)
          hand = known_hands.fetch(current_key) { state[:hands].fetch(current_key, []) }
          led_suit = card_suit(trick.first[:card])
          legal = legal_cards_for_led_suit(hand, led_suit)
          return 0.0 if legal.empty?

          allied = bot_state_allied?(state, actor_key, current_key)
          preferred = legal.select do |reply|
            winner = trick_winner(trick + [{ player: current_key, card: reply }])
            allied ? !same_user?(winner, actor_key) : same_user?(winner, actor_key)
          end
          if preferred.empty?
            # An opponent that cannot duck is forced to cover the nil. An ally
            # that cannot cover plays cheaply and lets later seats try.
            return 0.0 if !allied
            chosen = legal.min_by { |reply| bot_card_cost(state, reply) }
          else
            chosen = preferred.min_by { |reply| bot_card_cost(state, reply) }
          end
          trick << { player: current_key, card: chosen }
          return 0.0 if !same_user?(trick_winner(trick), actor_key)
        end
        return 1.0
      end

      predicted_win = if context.is_a?(Hash)
        context.fetch(:win_probabilities, {}).fetch(card, 0.0).to_f
      else
        0.0
      end
      rank_value = RANKS.index(card_rank(card)).to_i / (RANKS.length - 1).to_f
      [[predicted_win + (1.0 - predicted_win) * rank_value, 0.0].max, 1.0].min
    end

    # Round planning is shared by all trained profiles. The learned policy
    # remains useful for local card technique and tie-breaking, while this
    # fixed adjustment makes complete-round consequences (contracts, bags,
    # nils and score position) matter in every Spades variant.
    def bot_planning_score_adjustment(state, _actor, action, context)
      plan = context.is_a?(Hash) ? context[:round_plan] : nil
      return 0.0 if !plan.is_a?(Hash)

      key = if state[:phase] == :bidding
        selection_value(action, "bid")
      else
        action["card"].to_s
      end
      score = plan.fetch(:scores, {})[key]
      return 0.0 if score == nil

      weight = state[:phase] == :bidding ? 7.0 : 9.0
      weight *= 1.2 if plan[:exact_information] == true
      raw_scores = plan.fetch(:raw_scores, {})
      raw_score = raw_scores[key]
      best_raw_score = raw_scores.values.compact.map(&:to_f).max
      total_cards = state[:hands].to_h.values.sum { |hand| hand.to_a.length }
      exact_continuation = state[:phase] == :playing &&
        plan[:exact_limit].to_i > 0 && total_cards <= plan[:exact_limit].to_i
      # A roughly thousand-point terminal swing denotes a projected match
      # result. Before the exact endgame boundary that result still depends on
      # heuristic rollout play, even when an omniscient bot knows every hand.
      # Do not let such an approximate projection use the unconditional veto;
      # the ordinary confidence-scaled adjustment below may still advise the
      # learned policy. Exact endgames retain the veto, as do ordinary
      # missed-contract outliers such as the build-80 dominated-lead case.
      approximate_match_loss = !exact_continuation && raw_score != nil &&
        raw_score.to_f <= -PLANNING_MATCH_LOSS_RAW_THRESHOLD
      # Confidence describes the margin between the two best choices. It may
      # legitimately be zero when several safe cards tie, but that must not
      # erase a decisive conclusion about a single losing outlier. Exact
      # complete-round evaluation can therefore veto a choice that trails the
      # best continuation by at least a missed-contract-sized swing, while the
      # learned policy remains responsible for choosing among the tied leaders.
      if plan[:exact_information] == true &&
          plan[:confidence].to_f < PLANNING_FULL_CONFIDENCE_MARGIN &&
          raw_score != nil && best_raw_score != nil &&
          best_raw_score - raw_score.to_f >= PLANNING_DOMINATED_RAW_MARGIN &&
          !approximate_match_loss
        return -PLANNING_DOMINATED_CHOICE_PENALTY
      end
      confidence_factor = if exact_continuation
        1.0
      elsif plan.key?(:confidence)
        [[plan[:confidence].to_f / PLANNING_FULL_CONFIDENCE_MARGIN, 0.0].max, 1.0].min
      else
        1.0
      end
      score.to_f * weight * confidence_factor
    end
    public :bot_planning_score_adjustment

    def playing_bot_features(replay, actor, action, context)
      state = replay.state
      card = action["card"].to_s
      rank_value = RANKS.index(card_rank(card)).to_i / (RANKS.length - 1).to_f
      trick = state[:current_trick]
      last_to_play = trick.length == state[:players].length - 1
      leader = trick.empty? ? nil : trick_winner(trick)
      winner_after = trick_winner(trick + [{ player: player_key(state, actor), card: card }])
      wins = same_user?(winner_after, actor)
      partner_winning = leader != nil && !same_user?(leader, actor) && bot_state_allied?(state, actor, leader)
      need = bot_contract_remaining(state, actor)
      own_bid = state[:bids].fetch(player_key(state, actor), -1).to_i
      own_tricks = state[:tricks].fetch(player_key(state, actor), 0).to_i
      nil_active = own_bid == 0 && own_tricks == 0
      led_suit = trick.empty? ? nil : card_suit(trick.first[:card])
      sloughing = led_suit != nil && card_suit(card) != led_suit
      actor_key = player_key(state, actor)
      assignment = team_assignment(state[:options], players: state[:players])
      teammates = assignment == nil ? [] : assignment.teammates_for(actor).reject { |player| same_user?(player, actor) }
      opponents = state[:players].reject do |player|
        same_user?(player, actor) || teammates.any? { |partner| same_user?(partner, player) }
      end
      active_nil = state[:players].select do |player|
        state[:bids].fetch(player, -1).to_i == 0 && state[:tricks].fetch(player, 0).to_i == 0
      end
      partner_nil = active_nil.find { |player| teammates.any? { |partner| same_user?(partner, player) } }
      opponent_nil = active_nil.find { |player| opponents.any? { |opponent| same_user?(opponent, player) } }
      protecting_partner_nil = partner_nil != nil
      partner_nil_has_played = partner_nil != nil && trick.any? do |play|
        same_user?(play[:player], partner_nil)
      end
      actor_index = state[:players].index { |player| same_user?(player, actor) }
      next_player = actor_index == nil ? nil : state[:players][(actor_index + 1) % state[:players].length]
      partner_nil_plays_next = partner_nil != nil && next_player != nil && same_user?(next_player, partner_nil)
      leader_is_partner_nil = leader != nil && partner_nil != nil && same_user?(leader, partner_nil)
      leader_is_opponent_nil = leader != nil && opponent_nil != nil && same_user?(leader, opponent_nil)
      higher_unseen = bot_higher_unseen_count(card, context[:unseen_cards])
      hand = hand_for(state, actor).to_a
      suit_length = hand.count { |candidate| card_suit(candidate) == card_suit(card) }
      void_suits = context[:void_suits]
      opponent_voids = opponents.count { |player| void_suits.fetch(player.to_s, []).include?(card_suit(card)) }
      partner_voids = teammates.count { |player| void_suits.fetch(player.to_s, []).include?(card_suit(card)) }
      score = context[:score]
      quicksand = state[:options]["quicksand"] == true
      non_spade_available = legal_cards(state, actor).any? { |candidate| card_suit(candidate) != "S" }
      win_probability = context.fetch(:win_probabilities, {}).fetch(card) do
        bot_trick_win_probability(state, actor, card, context)
      end
      # A high side-suit card is not a known winner when a player who still
      # has to act is publicly known to be void and may ruff it. Keep this in
      # sync with bot_trick_win_probability instead of looking only for a
      # higher card in the led suit.
      known_winner = higher_unseen == 0 && win_probability >= 1.0
      contract_plan = bot_contract_plan(state, actor, context)
      contract_pressure = protecting_partner_nil ? 1.0 : contract_plan[:contract_pressure]
      completed_avoidance = protecting_partner_nil ? 0.0 : contract_plan[:completed_avoidance_pressure]
      early_avoidance = protecting_partner_nil ? 0.0 : contract_plan[:early_avoidance_pressure]
      denial = nil_active ? { value: 0.0, forced: 0.0, tightness: 0.0 } :
        bot_opponent_contract_denial(state, actor, leader, wins, opponents)
      {
        "low_card" => 1.0 - rank_value,
        "trump_cost" => card_suit(card) == "S" ? -1.0 : 0.0,
        "last_win_needed" => last_to_play && wins ? contract_pressure : 0.0,
        "last_win_unneeded" => last_to_play && wins ? completed_avoidance : 0.0,
        "nil_win" => wins && nil_active ? 1.0 : 0.0,
        "protect_partner" => partner_winning && !wins ? 1.0 : 0.0,
        "overtake_partner" => partner_winning && wins ? 1.0 : 0.0,
        "discard_high" => sloughing && !wins && card_suit(card) != "S" ? rank_value : 0.0,
        "lead_spade" => trick.empty? && card_suit(card) == "S" ? 1.0 : 0.0,
        "win_before_last" => !last_to_play && need > 0 ? win_probability : 0.0,
        "bag_risk_win" => completed_avoidance > 0.0 && bot_bag_risk?(state, actor) ?
          win_probability * completed_avoidance : 0.0,
        "cheapest_winner" => win_probability >= 0.5 &&
          (protecting_partner_nil || contract_pressure >= [completed_avoidance, early_avoidance].max) &&
          context[:cheapest_winner] == card ? 1.0 : 0.0,
        "cash_contract_run" => context[:cash_contract_run] == card ? 1.0 : 0.0,
        "highest_safe_loser" => !wins && completed_avoidance > 0.0 && context[:highest_loser] == card ? completed_avoidance : 0.0,
        "needed_win_probability" => win_probability * contract_pressure,
        "unneeded_win_probability" => win_probability * completed_avoidance,
        "unneeded_high_release" => rank_value * (1.0 - win_probability) * completed_avoidance,
        "early_avoid_win_probability" => win_probability * early_avoidance,
        "early_avoid_high_release" => rank_value * (1.0 - win_probability) * early_avoidance,
        "early_avoid_safe_loser" => !wins && context[:highest_loser] == card ? early_avoidance : 0.0,
        "known_winner_needed" => known_winner && wins ? contract_pressure : 0.0,
        "waste_known_winner" => known_winner && !wins ? contract_pressure : 0.0,
        "higher_cards_unseen" => wins ? higher_unseen.to_f / [context[:unseen_cards].length, 1].max : 0.0,
        "lead_short_suit" => trick.empty? ? 1.0 - suit_length.to_f / [hand.length, 1].max : 0.0,
        "lead_into_opponent_void" => trick.empty? ? opponent_voids.to_f / [opponents.length, 1].max : 0.0,
        "lead_into_partner_void" => trick.empty? ? partner_voids.to_f / [teammates.length, 1].max : 0.0,
        "draw_trump" => trick.empty? && card_suit(card) == "S" && hand.count { |candidate| card_suit(candidate) == "S" } >= 3 ? 1.0 : 0.0,
        "partner_nil_cover" => leader_is_partner_nil && wins ? 1.0 : 0.0,
        "partner_nil_safe_lead" => trick.empty? && partner_nil != nil ? rank_value : 0.0,
        "partner_nil_lead_control" => protecting_partner_nil && trick.empty? ? win_probability : 0.0,
        # Taking control helps an active nil only when the partner still has to
        # play immediately after us, or when the partner is currently winning
        # the trick. Do not burn winners merely because we are leading, when
        # opponents can still intervene before the partner, or after the
        # partner has already discarded safely.
        "partner_nil_control" => protecting_partner_nil && !trick.empty? &&
          ((!partner_nil_has_played && partner_nil_plays_next) || leader_is_partner_nil) ? win_probability : 0.0,
        "partner_nil_distant_control" => protecting_partner_nil && !trick.empty? &&
          !partner_nil_has_played && !partner_nil_plays_next ? win_probability : 0.0,
        "opponent_nil_feed" => leader_is_opponent_nil && !wins ? 1.0 : 0.0,
        "opponent_nil_pressure" => trick.empty? && opponent_nil != nil ? 1.0 - rank_value : 0.0,
        "deny_opponent_contract" => denial[:value],
        "force_opponent_set" => denial[:forced],
        "tight_table_denial" => denial[:tightness],
        "trailing_contract_win" => win_probability * [score[:deficit], 0.0].max * contract_pressure,
        "leading_avoid_extra" => win_probability * [-score[:deficit], 0.0].max * completed_avoidance,
        "quicksand_extra_win" => quicksand ? win_probability * completed_avoidance : 0.0,
        "quicksand_needed_win" => quicksand ? win_probability * contract_pressure : 0.0,
        "bag_penalty_imminent" => !quicksand && completed_avoidance > 0.0 && score[:bags] >= 8 ?
          win_probability * completed_avoidance : 0.0,
        "preserve_trump" => card_suit(card) == "S" && !wins && non_spade_available ? -1.0 : 0.0
      }
    end

    def bot_public_play_context(replay)
      events = replay.accepted_events.to_a
      last_deal = events.rindex { |event| event["action"].to_s == "deal" }
      round_events = last_deal == nil ? [] : events[(last_deal + 1)..]
      plays = round_events.to_a.select { |event| event["action"].to_s == "play" }
      void_suits = Hash.new { |hash, player| hash[player] = [] }
      ace_played = plays.any? { |event| event["value"].to_s == "AS" }
      plays.each_slice(replay.players.length) do |trick|
        next if trick.empty?

        led_suit = card_suit(trick.first["value"])
        trick.each do |event|
          next if card_suit(event["value"]) == led_suit

          player = event["actor"].to_s
          missing = led_suit == "S" && !ace_played ? "S_except_ace" : led_suit
          void_suits[player] << missing if !void_suits[player].include?(missing)
        end
      end
      {
        played_cards: plays.map { |event| event["value"].to_s },
        public_plays: plays.map do |event|
          { player: event["actor"].to_s, card: event["value"].to_s }
        end,
        void_suits: void_suits
      }
    end

    def bot_card_wins?(state, actor, card)
      winner = trick_winner(state[:current_trick] + [{ player: player_key(state, actor), card: card }])
      same_user?(winner, actor)
    end

    def bot_card_cost(state, card)
      led_suit = state[:current_trick].empty? ? card_suit(card) : card_suit(state[:current_trick].first[:card])
      trump = card_suit(card) == "S" && led_suit != "S" ? 1 : 0
      [trump, RANKS.index(card_rank(card)).to_i]
    end

    # A long run of reliable winners can disappear as soon as opponents become
    # void and start ruffing. Early bag avoidance may still shed genuinely
    # spare tricks, but it must first cash enough cards from such a run to make
    # the outstanding contract. Requiring one winner more than the current need
    # keeps the existing cautious behavior for isolated aces and other single
    # controls while protecting sequences such as A-K-Q-J.
    def bot_cash_contract_run(state, actor, reliable_winners)
      return nil if !state[:current_trick].empty?

      need = bot_contract_remaining(state, actor)
      return nil if need <= 0

      runs = reliable_winners.group_by { |card| card_suit(card) }.values.filter_map do |cards|
        next if cards.length <= need

        cards.min_by { |card| bot_card_cost(state, card) }
      end
      runs.min_by { |card| bot_card_cost(state, card) }
    end

    def bot_higher_unseen_count(card, unseen_cards)
      rank = RANKS.index(card_rank(card)).to_i
      unseen_cards.count do |candidate|
        card_suit(candidate) == card_suit(card) && RANKS.index(card_rank(candidate)).to_i > rank
      end
    end

    def bot_contract_plan(state, actor, context = nil)
      assignment = team_assignment(state[:options], players: state[:players])
      actor_key = player_key(state, actor)
      members = assignment == nil ? [actor_key] : assignment.teammates_for(actor)
      regular = members.reject { |player| state[:bids].fetch(player, -1).to_i == 0 }
      required = regular.sum { |player| state[:bids].fetch(player, 0).to_i }
      won = regular.sum { |player| state[:tricks].fetch(player, 0).to_i }
      need = [required - won, 0].max
      partner_expected = regular.reject { |player| same_user?(player, actor) }.sum do |player|
        [state[:bids].fetch(player, 0).to_i - state[:tricks].fetch(player, 0).to_i, 0].max
      end
      actor_required = [need - partner_expected, 0].max
      remaining = [hand_for(state, actor).to_a.length, 1].max
      probable = estimated_bot_bid(state, actor)
      certain = estimated_certain_tricks(state, actor).to_f
      probable_surplus = probable - actor_required
      certain_surplus = certain - actor_required
      projected_winners = if state[:current_trick].empty? && context != nil &&
          context[:win_probabilities].is_a?(Hash)
        context[:win_probabilities].values.sum(&:to_f)
      else
        probable
      end
      projected_overtricks = [projected_winners - actor_required, 0.0].max

      if need <= 0
        completed_avoidance = bot_overtrick_avoidance_pressure(
          state, actor, [projected_winners, 0.0].max
        )
        return {
          contract_pressure: 0.0,
          completed_avoidance_pressure: completed_avoidance,
          early_avoidance_pressure: 0.0,
          avoidance_pressure: completed_avoidance,
          probable_surplus: probable_surplus,
          certain_surplus: certain_surplus,
          projected_overtricks: projected_overtricks
        }
      end

      urgency = [[actor_required.to_f / remaining, 0.0].max, 1.0].min
      shortage = [-probable_surplus, 0.0].max / [actor_required, 1].max.to_f
      contract_pressure = [urgency + shortage + (certain_surplus < 0.0 ? 0.25 : 0.0), 1.0].min
      # One accidental overtrick is normally cheaper than breaking a contract.
      # Start ducking early only with at least two independently projected spare
      # tricks, and scale that caution using public card probabilities and the
      # number of bags already carried by this player or team.
      minimum_early_surplus = 2.0
      covered_surplus = [certain_surplus, probable_surplus].max
      avoidance_pressure = if covered_surplus >= minimum_early_surplus
        bot_overtrick_avoidance_pressure(state, actor, projected_overtricks) * 0.75
      else
        0.0
      end
      {
        contract_pressure: contract_pressure,
        completed_avoidance_pressure: 0.0,
        early_avoidance_pressure: avoidance_pressure,
        avoidance_pressure: avoidance_pressure,
        probable_surplus: probable_surplus,
        certain_surplus: certain_surplus,
        projected_overtricks: projected_overtricks
      }
    end

    def bot_overtrick_avoidance_pressure(state, actor, projected_overtricks)
      extras = [projected_overtricks.to_f, 0.0].max
      return 0.0 if extras <= 0.0
      return 1.0 if state[:options]["quicksand"] == true

      bags = bot_score_context(state, actor)[:bags].to_i
      bag_ratio = [[bags.to_f / 9.0, 0.0].max, 1.0].min
      tolerated = 1.0 - bag_ratio * 0.75
      excess = extras - tolerated
      return 0.0 if excess <= 0.0

      [[0.2 + excess * 0.35 + bag_ratio * 0.5, 0.0].max, 1.0].min
    end

    def bot_regular_contract(state, actor)
      assignment = team_assignment(state[:options], players: state[:players])
      members = assignment == nil ? [player_key(state, actor)] : assignment.teammates_for(actor)
      regular = members.reject { |player| state[:bids].fetch(player, -1).to_i == 0 }
      bid = regular.sum { |player| state[:bids].fetch(player, 0).to_i }
      tricks = regular.sum { |player| state[:tricks].fetch(player, 0).to_i }
      { bid: bid, tricks: tricks, need: [bid - tricks, 0].max }
    end

    def bot_opponent_contract_denial(state, actor, leader, wins, opponents)
      return { value: 0.0, forced: 0.0, tightness: 0.0 } if leader == nil || !wins
      return { value: 0.0, forced: 0.0, tightness: 0.0 } if !opponents.any? { |player| same_user?(player, leader) }

      contract = bot_regular_contract(state, leader)
      return { value: 0.0, forced: 0.0, tightness: 0.0 } if contract[:need] <= 0

      remaining = [hand_for(state, actor).to_a.length, 1].max
      remaining_after = [remaining - 1, 0].max
      maximum = [cards_per_player(state[:players].length), 1].max
      total_bids = state[:bids].values.sum(&:to_i)
      urgency = [contract[:need].to_f / remaining, 1.0].min
      contract_value = [contract[:bid].to_f / maximum, 1.0].min
      tightness = [[total_bids.to_f / maximum - 0.65, 0.0].max, 1.0].min
      {
        value: [0.25 + urgency * 0.5 + contract_value * 0.5, 1.5].min,
        forced: contract[:need] > remaining_after ? 1.0 : 0.0,
        tightness: tightness
      }
    end

    # Estimate whether a card that is provisionally winning will still win
    # after the remaining players act. Only the public trick, the actor's hand
    # and unseen cards are used. This lets a bot that has made its contract
    # distinguish a genuinely dangerous winner from a high card that can be
    # safely shed under a likely higher card.
    def bot_trick_win_probability(state, actor, card, context)
      if context[:omniscient] == true
        return bot_exact_trick_win_probability(state, actor, card, context)
      end

      actor_key = player_key(state, actor)
      trick = state[:current_trick] + [{ player: actor_key, card: card }]
      return 0.0 if !same_user?(trick_winner(trick), actor)

      remaining_players = state[:players].length - trick.length
      return 1.0 if remaining_players <= 0

      led_suit = card_suit(trick.first[:card])
      winning_play = trick.find { |play| same_user?(play[:player], actor_key) }
      winning_card = winning_play[:card]
      winning_suit = card_suit(winning_card)
      winning_rank = RANKS.index(card_rank(winning_card)).to_i
      threats = context[:unseen_cards].count do |candidate|
        candidate_suit = card_suit(candidate)
        candidate_rank = RANKS.index(card_rank(candidate)).to_i
        if winning_suit == "S"
          candidate_suit == "S" && candidate_rank > winning_rank
        else
          candidate_suit == led_suit && candidate_rank > winning_rank
        end
      end
      unknown = context[:unseen_cards].length
      slots = [remaining_players * hand_for(state, actor).to_a.length, unknown].min
      probability_no_threat = bot_probability_without_targets(unknown, threats, slots)

      # A side-suit winner can also lose to a ruff. Public play history tells
      # us which players are already void in the led suit. Estimate the chance
      # that none of the remaining spades is in the hands of those players.
      # If every remaining player is void, any unseen spade makes the ruff
      # certain; with only one known void the result remains probabilistic.
      if winning_suit != "S" && led_suit != "S"
        future_players = state[:players].reject do |player|
          trick.any? { |play| same_user?(play[:player], player) }
        end
        void_players = future_players.count do |player|
          context[:void_suits].fetch(player.to_s, []).include?(led_suit)
        end
        if void_players > 0
          unseen_spades = context[:unseen_cards].count { |candidate| card_suit(candidate) == "S" }
          void_slots = [void_players * hand_for(state, actor).to_a.length, unknown].min
          probability_no_threat *= bot_probability_without_targets(unknown, unseen_spades, void_slots)
        end
      end
      [[probability_no_threat, 0.0].max, 1.0].min
    end

    # Resolve the rest of the current trick against the actual remaining
    # hands. Opponents choose a reply that defeats the candidate whenever one
    # exists, while partners cooperate. This is a compact double-dummy search
    # over one trick rather than an expensive search over the entire match.
    def bot_exact_trick_win_probability(state, actor, card, context)
      actor_key = player_key(state, actor)
      trick = state[:current_trick] + [{ player: actor_key, card: card }]
      return 0.0 if !same_user?(trick_winner(trick), actor)

      remaining = state[:players].length - trick.length
      return 1.0 if remaining <= 0

      actor_index = state[:players].index { |player| same_user?(player, actor) }
      return 0.0 if actor_index == nil

      future_players = (1..remaining).map do |offset|
        state[:players][(actor_index + offset) % state[:players].length]
      end
      bot_exact_trick_outcome(
        state,
        actor,
        trick,
        future_players,
        context.fetch(:known_hands)
      ) ? 1.0 : 0.0
    end

    def bot_exact_trick_outcome(state, actor, trick, future_players, known_hands)
      if future_players.empty?
        return same_user?(trick_winner(trick), actor)
      end

      player = future_players.first
      hand = known_hands.fetch(player_key(state, player), [])
      led_suit = card_suit(trick.first[:card])
      legal = legal_cards_for_led_suit(hand, led_suit)
      return same_user?(trick_winner(trick), actor) if legal.empty?

      cooperative = bot_state_allied?(state, actor, player)
      legal.each do |candidate|
        actor_wins = bot_exact_trick_outcome(
          state,
          actor,
          trick + [{ player: player_key(state, player), card: candidate }],
          future_players.drop(1),
          known_hands
        )
        return true if cooperative && actor_wins
        return false if !cooperative && !actor_wins
      end
      !cooperative
    end

    def spades_round_planner
      @spades_round_planner ||= SpadesPlanning::RoundPlanner.new(self)
    end

    def bot_probability_without_targets(unknown, targets, slots)
      available_cards = [unknown.to_i, 0].max
      target_cards = [[targets.to_i, 0].max, available_cards].min
      draws = [[slots.to_i, 0].max, available_cards].min
      return 1.0 if target_cards == 0 || draws == 0

      probability = 1.0
      draws.times do |index|
        available = available_cards - index
        safe = available_cards - target_cards - index
        return 0.0 if safe <= 0

        probability *= safe.to_f / available
      end
      probability
    end

    # Top consecutive trumps are guaranteed independently of unknown hands.
    # Prune only strict score dominance, not merely bids below an average.
    def undominated_bot_bids(state, actor, bids)
      return bids unless state[:options]["team_size"].to_i == 0 && !state[:options]["no_hell"]
      hand = hand_for(state, actor).to_a
      guaranteed = RANKS.reverse.take_while { |rank| hand.include?("#{rank}S") }.length
      return bids if guaranteed.zero? || bids.length <= 1
      scoring = Scoring.new(state[:players], state[:options])
      values = bids.to_h do |bid|
        outcomes = (guaranteed..cards_per_player(state[:players].length)).map do |won|
          scoring.apply(bids: state[:bids].merge(actor => bid), tricks: { actor => won }, scores: state[:scores]).scores[actor]
        end
        [bid, outcomes]
      end
      bids.reject do |bid|
        bids.any? do |other|
          next false if other == bid
          pairs = values[bid].zip(values[other])
          pairs.all? { |old, replacement| replacement >= old } && pairs.any? { |old, replacement| replacement > old }
        end
      end
    end

    def estimated_bot_bid(state, actor)
      hand = hand_for(state, actor).to_a
      suit_lengths = SUITS.each_with_object({}) do |suit, result|
        result[suit] = hand.count { |card| card_suit(card) == suit }
      end
      estimate = hand.sum do |card|
        length = suit_lengths[card_suit(card)]
        case card_rank(card)
        when "A" then 0.95
        when "K" then length <= 5 ? 0.65 : 0.35
        when "Q" then length <= 4 ? 0.35 : 0.12
        when "J" then length <= 3 ? 0.18 : 0.05
        else 0.0
        end
      end
      spades = suit_lengths["S"].to_i
      estimate += [spades - 3, 0].max * 0.35
      suit_totals = SUITS.each_with_object({}) do |suit, result|
        result[suit] = deck_for(state[:players].length).count { |card| card_suit(card) == suit }
      end
      short_suit_opportunities = SUITS.reject { |suit| suit == "S" }.sum do |suit|
        shortage = case suit_lengths[suit]
        when 0 then 1.0
        when 1 then 0.65
        when 2 then 0.30
        else 0.0
        end
        shortage * (13.0 / [suit_totals[suit], 1].max)
      end
      ruff_capacity = [spades - 2, 0].max
      estimate += [short_suit_opportunities, ruff_capacity].min * 0.45
      estimate += SUITS.reject { |suit| suit == "S" }.count { |suit| suit_lengths[suit] == 0 } * 0.10
      estimate *= BID_STRENGTH_SCALE.fetch(state[:players].length)
      estimate = estimated_omniscient_bid(state, actor, estimate) if omniscient_bots?(state)
      [[estimate, 0.0].max, cards_per_player(state[:players].length).to_f].min
    end

    # Perfect information is most useful in bidding when a nominal top-card
    # sequence can already be seen to survive, or to be vulnerable to a ruff.
    # Keep the calibrated public estimate as the baseline and adjust only the
    # part that the exact distribution can prove or disprove.
    def estimated_omniscient_bid(state, actor, public_estimate)
      side_profiles = exact_side_suit_control_profile(state, actor)
      side_controls = side_profiles.values.sum do |profile|
        profile[:safe_controls].to_f + profile[:threatened_controls].to_f * 0.35
      end
      spade_controls = exact_top_control_cards(state, actor, "S").length.to_f
      exact_controls = side_controls + spade_controls
      public_controls = estimated_public_certain_tricks(state, actor).to_f
      public_estimate + (exact_controls - public_controls) * 0.75
    end

    def omniscient_bots?(state)
      options = state[:options]
      options.is_a?(Hash) && options["omniscient_bots"] == true
    end

    def estimated_contract_safety_reserve(state, actor)
      return 0.0 if state[:players].length != 3
      return 0.0 if state[:options]["quicksand"] == true

      hand = hand_for(state, actor).to_a
      spades = hand.count { |card| card_suit(card) == "S" }
      return 0.0 if spades >= 3

      vulnerable_suits = SUITS.reject { |suit| suit == "S" }.count do |suit|
        cards = hand.select { |card| card_suit(card) == suit }
        next false if cards.length < 5

        cards.count { |card| %w[K Q J].include?(card_rank(card)) } >= 2
      end
      [vulnerable_suits * 0.5, 1.0].min
    end

    def bot_table_bid_target(state, actor)
      maximum = cards_per_player(state[:players].length).to_f
      score = bot_score_context(state, actor)
      # Allocating every trick creates a knife-edge table:
      # one contested overtrick automatically breaks another contract. This is
      # true for every player count and for both individual and team contracts,
      # and it also remains true in Quicksand: paying ten points for an extra
      # trick can be profitable when it breaks an opponent's contract. Keep the
      # reasoning in the shared model rather than tuning every policy profile.
      # In standard Spades a player or team close to the ten-bag penalty may
      # accept that risk. Match-position aggression remains a separate learned
      # feature and must not silently erase the shared safety margin.
      bag_relief = if state[:options]["quicksand"] == true
        0.0
      else
        [[(score[:bags] - 6).to_f / 3.0, 0.0].max, 1.0].min
      end
      buffer = 1.0 - bag_relief
      maximum - buffer
    end

    def bot_table_bid_projection(state, actor, bid)
      target = bot_table_bid_target(state, actor)
      remaining = [state[:players].length - state[:bids].length - 1, 0].max
      average = target / [state[:players].length, 1].max
      {
        target: target,
        remaining_bidders: remaining,
        projected: state[:bids].values.sum(&:to_i) + bid.to_i + remaining * average
      }
    end

    def estimated_certain_tricks(state, actor)
      if omniscient_bots?(state)
        side_controls = exact_side_suit_control_profile(state, actor).values.sum do |profile|
          profile[:safe_controls].to_i
        end
        spade_controls = exact_top_control_cards(state, actor, "S").length
        return [side_controls + spade_controls, cards_per_player(state[:players].length)].min
      end

      estimated_public_certain_tricks(state, actor)
    end

    # This is the historical public-hand feature used by the trained bidding
    # profiles. It describes nominal top-card strength, not a mathematical
    # guarantee. Perfect-information bots compare it with the actually cashable
    # controls instead of assuming every A-K-Q-J run survives intact.
    def estimated_public_certain_tricks(state, actor)
      hand = hand_for(state, actor).to_a
      certain = SUITS.sum do |suit|
        ranks = hand.select { |card| card_suit(card) == suit }.map { |card| card_rank(card) }
        %w[A K Q J].take_while { |rank| ranks.include?(rank) }.length
      end
      spades = hand.count { |card| card_suit(card) == "S" }
      voids = SUITS.reject { |suit| suit == "S" }.count do |suit|
        hand.none? { |card| card_suit(card) == suit }
      end
      certain += [[spades - 4, 0].max, voids].min
      [certain, cards_per_player(state[:players].length)].min
    end

    def exact_top_control_cards(state, actor, suit)
      actor_key = player_key(state, actor)
      return [] if actor_key == nil

      state[:players].flat_map do |player|
        key = player_key(state, player)
        hand_for(state, key).to_a.select { |card| card_suit(card) == suit }.map do |card|
          [key, card]
        end
      end.sort_by { |_player, card| -RANKS.index(card_rank(card)).to_i }
        .take_while { |player, _card| same_user?(player, actor_key) }
        .map(&:last)
    end

    # A side-suit control is safely cashable only while every hostile player
    # who still owns trump can follow suit. The remaining cards in the top run
    # are correlated: once the shortest opponent becomes void, all of them are
    # exposed together rather than remaining independent "certain" tricks.
    def exact_side_suit_control_profile(state, actor)
      actor_key = player_key(state, actor)
      return {} if actor_key == nil

      opponents = state[:players].reject do |player|
        same_user?(player, actor_key) || bot_state_allied?(state, actor_key, player)
      end
      trump_opponents = opponents.select do |player|
        hand_for(state, player).to_a.any? { |card| card_suit(card) == "S" }
      end
      SUITS.reject { |suit| suit == "S" }.each_with_object({}) do |suit, result|
        controls = exact_top_control_cards(state, actor_key, suit)
        shortest = if trump_opponents.empty?
          controls.length
        else
          trump_opponents.map do |player|
            hand_for(state, player).to_a.count { |card| card_suit(card) == suit }
          end.min.to_i
        end
        safe = [controls.length, shortest].min
        result[suit] = {
          suit: suit,
          control_cards: controls,
          safe_controls: safe,
          threatened_controls: [controls.length - safe, 0].max,
          shortest_trump_opponent: shortest
        }
      end
    end

    def estimated_nil_risk(state, actor)
      hand = hand_for(state, actor).to_a
      maximum = cards_per_player(state[:players].length)
      risk = hand.sum do |card|
        rank = RANKS.index(card_rank(card)).to_i
        suit_length = hand.count { |candidate| card_suit(candidate) == card_suit(card) }
        high = [rank - 8, 0].max / 4.0
        card_suit(card) == "S" ? high * 1.4 : high / [suit_length, 1].max
      end
      [risk / [maximum, 1].max, 1.5].min
    end

    def bot_score_context(state, actor)
      assignment = team_assignment(state[:options], players: state[:players])
      unit = if assignment == nil
        player_key(state, actor)
      else
        "team:#{assignment.team_index_for(actor)}"
      end
      own_score = state[:scores].fetch(unit, 0).to_i
      opponent_scores = state[:scores].reject { |candidate, _score| candidate.to_s == unit.to_s }.values.map(&:to_i)
      opponent_score = opponent_scores.max || 0
      limit = [state[:options]["score_limit"].to_i, 1].max
      deficit = [[(opponent_score - own_score).to_f / limit, -2.0].max, 2.0].min
      {
        unit: unit,
        own_score: own_score,
        opponent_score: opponent_score,
        deficit: deficit,
        bags: state[:options]["quicksand"] == true ? 0 : own_score % 10
      }
    end

    def bot_state_allied?(state, first, second)
      assignment = team_assignment(state[:options], players: state[:players])
      return same_user?(first, second) if assignment == nil

      assignment.team_index_for(first) == assignment.team_index_for(second)
    end

    def bot_contract_remaining(state, actor)
      assignment = team_assignment(state[:options], players: state[:players])
      members = assignment == nil ? [player_key(state, actor)] : assignment.teammates_for(actor)
      regular = members.reject { |player| state[:bids].fetch(player, -1).to_i == 0 }
      required = regular.sum { |player| state[:bids].fetch(player, 0).to_i }
      won = regular.sum { |player| state[:tricks].fetch(player, 0).to_i }
      required - won
    end

    def bot_bag_risk?(state, actor)
      return false if state[:options]["quicksand"] == true

      assignment = team_assignment(state[:options], players: state[:players])
      unit = if assignment == nil
        player_key(state, actor)
      else
        "team:#{assignment.team_index_for(actor)}"
      end
      state[:scores].fetch(unit, 0).to_i % 10 >= 7 && bot_contract_remaining(state, actor) <= 0
    end

    def current_turn_shortcut_text(replay, _viewer)
      turn_information_text(replay.state)
    end

    def initial_state(players, options, scoring)
      units = scoring.unit_ids
      {
        players: players,
        options: options,
        units: units,
        scores: units.each_with_object({}) { |unit, result| result[unit] = 0 },
        round: 0,
        phase: :awaiting_deal,
        dealer_index: nil,
        seed: nil,
        hands: players.each_with_object({}) { |player, result| result[player] = [] },
        bids: {},
        tricks: players.each_with_object({}) { |player, result| result[player] = 0 },
        current_trick: [],
        spades_broken: false,
        current_player: nil,
        winner: nil
      }
    end

    def apply_deal(state, event, actor, repository, history)
      return false if !same_user?(actor, state[:players].first)
      return false if ![:awaiting_deal, :round_complete].include?(state[:phase])

      round, dealer, seed = parse_deal(event["value"])
      return false if round != state[:round] + 1
      return false if !dealer.between?(0, state[:players].length - 1)
      if state[:dealer_index] != nil
        expected_dealer = (state[:dealer_index] + 1) % state[:players].length
        return false if dealer != expected_dealer
      end

      hands = deal_hands(state[:players], dealer, seed)
      return false if hands.values.map(&:length).uniq.length != 1

      state[:round] = round
      state[:phase] = :bidding
      state[:dealer_index] = dealer
      state[:seed] = seed
      state[:hands] = hands
      state[:bids] = {}
      state[:tricks] = state[:players].each_with_object({}) { |player, result| result[player] = 0 }
      state[:current_trick] = []
      state[:spades_broken] = false
      state[:current_player] = state[:players][(dealer + 1) % state[:players].length]
      event_id = repository.event_id(event)
      history << HistoryEntry.new(
        key: "deal:#{round}",
        text: _("Round %{round} was dealt. %{dealer} is the dealer.") % {
          round: round,
          dealer: participant_name(state[:players][dealer])
        },
        event_id: event_id,
        actor: actor,
        kind: :deal
      )
      true
    rescue ArgumentError
      false
    end

    def apply_bid(state, event, actor, repository, history)
      return false if state[:phase] != :bidding
      return false if !same_user?(actor, state[:current_player])

      bid = Integer(event["value"].to_s, 10)
      return false if !legal_bid_values(state, actor).include?(bid)

      player = player_key(state, actor)
      state[:bids][player] = bid
      event_id = repository.event_id(event)
      history << HistoryEntry.new(
        key: "bid:#{event_id}",
        text: bid == 0 ?
          _("%{player} bid nil.") % { player: participant_name(actor) } :
          _("%{player} bid %{count}.") % { player: participant_name(actor), count: bid },
        event_id: event_id,
        actor: actor,
        kind: :bid,
        value: bid
      )
      if state[:bids].length == state[:players].length
        state[:phase] = :playing
        state[:current_player] = state[:players][(state[:dealer_index] + 1) % state[:players].length]
      else
        state[:current_player] = next_player(state[:players], actor)
      end
      true
    rescue ArgumentError
      false
    end

    def apply_play(state, event, actor, repository, history, scoring)
      return false if state[:phase] != :playing
      return false if !same_user?(actor, state[:current_player])

      card = event["value"].to_s
      hand = hand_for(state, actor)
      return false if hand == nil || !hand.include?(card)
      return false if !legal_cards(state, actor).include?(card)

      hand.delete_at(hand.index(card))
      state[:spades_broken] = true if card_suit(card) == "S"
      state[:current_trick] << { player: player_key(state, actor), card: card }
      event_id = repository.event_id(event)
      history << HistoryEntry.new(
        key: "play:#{event_id}",
        text: _("%{player} played %{card}.") % {
          player: participant_name(actor),
          card: card_label(card)
        },
        event_id: event_id,
        actor: actor,
        kind: :play,
        value: card
      )

      if state[:current_trick].length == state[:players].length
        winner = trick_winner(state[:current_trick])
        state[:tricks][winner] += 1
        history << HistoryEntry.new(
          key: "trick:#{event_id}",
          text: _("%{player} won the trick.") % { player: participant_name(winner) },
          event_id: event_id,
          actor: winner,
          kind: :trick
        )
        state[:current_trick] = []
        if state[:hands].values.all?(&:empty?)
          complete_round(state, scoring, event_id, history)
        else
          state[:current_player] = winner
        end
      else
        state[:current_player] = next_player(state[:players], actor)
      end
      true
    end

    def complete_round(state, scoring, event_id, history)
      result = scoring.apply(
        bids: state[:bids],
        tricks: state[:tricks],
        scores: state[:scores]
      )
      state[:scores] = result.scores
      result.units.each do |unit|
        history << HistoryEntry.new(
          key: "score:#{state[:round]}:#{unit.unit}",
          text: _("%{unit}: %{change} points this round, %{score} total.") % {
            unit: unit_label(state, unit.unit),
            change: signed_number(unit.points),
            score: unit.score
          },
          event_id: event_id,
          actor: "",
          kind: :score,
          value: unit.points
        )
      end

      leaders = state[:scores].group_by { |_unit, score| score }.max_by { |score, _items| score }
      winning_units = leaders == nil ? [] : leaders[1].map(&:first)
      target = state[:options]["score_limit"].to_i
      if leaders != nil && leaders[0] >= target && winning_units.length == 1
        state[:winner] = winning_units.first
        state[:phase] = :finished
        state[:current_player] = nil
        history << HistoryEntry.new(
          key: "result:#{event_id}",
          text: _("%{winner} won the game.") % { winner: unit_label(state, state[:winner]) },
          event_id: event_id,
          actor: state[:winner],
          kind: :result
        )
      else
        state[:phase] = :round_complete
        state[:current_player] = nil
      end
    end

    def card_table_spec(state, viewer)
      hand = hand_for(state, viewer).to_a.sort_by { |card| card_sort_key(card) }
      hand_cards = hand.map do |card|
        GameSurfaces::Card.new(id: card, label: card_label(card), value: card,
          sort_keys: standard_hand_sort_keys(rank: card_rank(card), suit: card_suit(card), position: hand_for(state, viewer).index(card)))
      end
      GameSurfaces::CardTableSpec.new(
        zones: [
          GameSurfaces::CardZoneSpec.new(
            id: "hand",
            header: _("Your hand"),
            cards: hand_cards,
            hand_order: hand_for(state, viewer).to_a.dup, hand_epoch: [viewer, state[:round]].join(":"),
            empty_label: _("Your hand is empty")
          )
        ]
      )
    end

    def score_text(state, sorted: false)
      units = sorted ? score_announcement_order(state[:units], state[:scores]) : state[:units]
      units.map do |unit|
        _("%{unit} %{score}") % {
          unit: unit_label(state, unit),
          score: state[:scores][unit]
        }
      end.join("; ")
    end

    def unit_label(state, unit)
      if unit.to_s.start_with?("team:")
        members = Scoring.new(state[:players], state[:options]).members_for(unit)
        return _("Team %{players}") % {
          players: members.map { |player| participant_name(player) }.join(" and ")
        }
      end

      participant_name(unit)
    end

    def turn_information_text(state)
      case state[:phase]
      when :awaiting_deal, :round_complete
        _("Waiting for the next deal.")
      when :bidding
        _("%{player} is bidding.") % { player: participant_name(state[:current_player]) }
      when :playing
        _("It is %{player}'s turn.") % { player: participant_name(state[:current_player]) }
      when :finished
        _("The game is finished. %{winner} won.") % { winner: unit_label(state, state[:winner]) }
      else
        _("No active turn.")
      end
    end

    def bids_information_text(state)
      bids = state[:players].map do |player|
        bid = state[:bids][player]
        value = if bid == nil
          _("not bid yet")
        elsif bid.to_i == 0
          _("nil")
        else
          bid.to_i.to_s
        end
        _("%{player}: %{bid}") % { player: participant_name(player), bid: value }
      end
      _("Bids: %{bids}.") % { bids: bids.join("; ") }
    end

    def table_cards_information_text(state)
      if state[:current_trick].empty?
        return _("There are no cards on the table.")
      end

      cards = state[:current_trick].map do |play|
        _("%{player}: %{card}") % {
          player: participant_name(play[:player]),
          card: card_label(play[:card])
        }
      end
      _("Cards on the table: %{cards}.") % { cards: cards.join("; ") }
    end

    def hand_information_text(state, viewer)
      cards = hand_for(state, viewer).to_a.sort_by { |card| card_sort_key(card) }
      return _("Your hand is empty.") if cards.empty?

      _("Your hand: %{cards}.") % {
        cards: cards.map { |card| card_label(card) }.join("; ")
      }
    end

    def led_suit_information_text(state)
      return _("No suit has been led.") if state[:current_trick].empty?

      suit = card_suit(state[:current_trick].first[:card])
      _("The led suit is %{suit}.") % { suit: SUIT_NAMES.fetch(suit, suit) }
    end

    def round_information_text(state)
      trick_progress = state[:players].map do |player|
        player_trick_progress_text(state, player)
      end
      completed = state[:tricks].values.sum
      total = cards_per_player(state[:players].length)
      current = [completed + 1, total].min
      _("Round %{round}. Tricks: %{tricks}. Trick %{current} of %{total}.") % {
        round: state[:round],
        tricks: trick_progress.join("; "),
        current: current,
        total: total
      }
    end

    def personal_round_information_text(state, viewer)
      player = player_key(state, viewer)
      progress = if player == nil
        _("You are not playing in this round.")
      else
        player_trick_progress_text(state, player)
      end
      completed = state[:tricks].values.sum
      total = cards_per_player(state[:players].length)
      current = [completed + 1, total].min
      _("Round %{round}. %{progress}. Trick %{current} of %{total}.") % {
        round: state[:round],
        progress: progress,
        current: current,
        total: total
      }
    end

    def player_trick_progress_text(state, player)
      bid = state[:bids][player]
      bid_text = if bid == nil
        _("not bid yet")
      elsif bid.to_i == 0
        _("nil")
      else
        bid.to_i.to_s
      end
      _("%{player}: %{tricks}/%{bid}") % {
        player: participant_name(player),
        tricks: state[:tricks].fetch(player, 0).to_i,
        bid: bid_text
      }
    end

    def legal_bid_values(state, actor)
      return [] if state[:phase] != :bidding || !same_user?(state[:current_player], actor)

      maximum = cards_per_player(state[:players].length)
      bids = (0..maximum).to_a
      if state[:options]["suicide"]
        bids.select! { |bid| bid == 0 || bid >= 4 }
        partner = suicide_partner(state, actor)
        partner_bid = state[:bids][partner]
        bids.select! { |bid| bid == 0 } if partner_bid != nil && partner_bid.to_i >= 4
      end
      if state[:options]["no_hell"] && state[:bids].length == state[:players].length - 1
        announced = state[:bids].values.sum
        bids.reject! { |bid| announced + bid == maximum }
      end
      bids
    end

    def legal_cards(state, actor)
      return [] if state[:phase] != :playing || !same_user?(state[:current_player], actor)

      hand = hand_for(state, actor).to_a
      return [] if hand.empty?
      if state[:current_trick].empty?
        non_spades = hand.reject { |card| card_suit(card) == "S" }
        return non_spades if !state[:spades_broken] && !non_spades.empty?

        return hand
      end

      led_suit = card_suit(state[:current_trick].first[:card])
      legal_cards_for_led_suit(hand, led_suit)
    end

    # QC Salon Spades permits a player whose only spade is the ace of spades
    # to withhold it even when spades were led. The ace remains a legal play,
    # but the player may discard any other card from the hand instead.
    def legal_cards_for_led_suit(hand, led_suit)
      following = hand.select { |card| card_suit(card) == led_suit }
      lone_ace_of_spades = led_suit == "S" && following.length == 1 &&
        card_rank(following.first) == "A"
      return hand if lone_ace_of_spades && hand.length > 1

      following.empty? ? hand : following
    end

    def trick_winner(trick)
      led_suit = card_suit(trick.first[:card])
      candidates = trick.select { |play| card_suit(play[:card]) == "S" }
      candidates = trick.select { |play| card_suit(play[:card]) == led_suit } if candidates.empty?
      candidates.max_by { |play| RANKS.index(card_rank(play[:card])).to_i }[:player]
    end

    def deal_hands(players, dealer, seed)
      deck = deck_for(players.length).sort_by { |card| Digest::SHA256.hexdigest("#{seed}\0#{card}") }
      hands = players.each_with_object({}) { |player, result| result[player] = [] }
      deck.each_with_index do |card, index|
        player = players[(dealer + 1 + index) % players.length]
        hands[player] << card
      end
      hands
    end

    def deck_for(player_count)
      deck = SUITS.product(RANKS).map { |suit, rank| "#{rank}#{suit}" }
      removed_twos = { 3 => 1, 4 => 0, 5 => 2, 6 => 4 }.fetch(player_count)
      SUITS.first(removed_twos).each { |suit| deck.delete("2#{suit}") }
      deck
    end

    def cards_per_player(player_count)
      deck_for(player_count).length / player_count
    end

    def parse_deal(value)
      fields = value.to_s.split("|", -1)
      raise ArgumentError, "invalid deal" if fields.length != 3

      round = Integer(fields[0], 10)
      dealer = Integer(fields[1], 10)
      seed = fields[2].to_s.downcase
      raise ArgumentError, "invalid deal seed" if seed !~ /\A[0-9a-f]{32}\z/

      [round, dealer, seed]
    end

    def random_seed(source)
      source.roll(count: 16, sides: 256).values.map do |value|
        (value.to_i - 1).to_s(16).rjust(2, "0")
      end.join
    end

    def hand_for(state, actor)
      key = player_key(state, actor)
      key == nil ? nil : state[:hands][key]
    end

    def player_key(state, actor)
      state[:players].find { |player| same_user?(player, actor) }
    end

    def next_player(players, actor)
      index = players.index { |player| same_user?(player, actor) }
      index == nil ? nil : players[(index + 1) % players.length]
    end

    def suicide_partner(state, actor)
      players = state[:players]
      index = players.index { |player| same_user?(player, actor) }
      return nil if index == nil

      assignment = team_assignment(state[:options], players: players)
      return nil if assignment == nil || assignment.team_size != 2

      assignment.teammates_for(actor).find { |player| !same_user?(player, actor) }
    end

    def card_rank(card)
      card.to_s[0]
    end

    def card_suit(card)
      card.to_s[1]
    end

    def card_label(card)
      _("%{rank} of %{suit}") % {
        rank: RANK_NAMES.fetch(card_rank(card), card_rank(card)),
        suit: SUIT_NAMES.fetch(card_suit(card), card_suit(card))
      }
    end

    def card_sort_key(card)
      playroom_hand_sort_key(card)
    end

    def signed_number(value)
      value.to_i > 0 ? "+#{value.to_i}" : value.to_i.to_s
    end
  end
end
