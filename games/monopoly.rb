require_relative "card_game"
require_relative "../lib/game_bots"
require_relative "../content/monopoly_boards"

require_relative "../lib/game_room_localization"

module GameRoomGames
  using GameRoomLocalization::Translations
  class Monopoly < CardGame
    def event_sound_cues(event:, before_replay:, after_replay:, history:, viewer:, random_variant:)
      action = event["action"].to_s
      cues = []
      cues << "roll" if action == "roll"
      cues << "play2" if %w[buy build sell mortgage unmortgage trade_accept auction_bid].include?(action)
      event_history = history
      cues << "hit1" if event_history.any? { |entry| entry.key.to_s.start_with?("group_complete:") }
      return cues.first if cues.length == 1
      return cues if !cues.empty?
    end

    def id
      "monopoly"
    end

    def save_game_error(replay)
      return _("Wait until the auction ends before saving the game.") if replay.state[:phase] == :auction

      super
    end

    def eliminated_from_game?(replay, viewer)
      replay.state.fetch(:bankrupt, {}).any? { |player, out| out && same_user?(player, viewer) }
    end

    def name
      _("Monopoly")
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
      # Generated from docs/rulebooks/monopoly.json; see tools/compile-rulebooks.rb.
      [
        rule_section(:journey, GameRoomRules.translate("A journey of buying and collecting rent"),
          GameRoomRules.translate("Two to eight players travel around the board, buy properties and charge visitors rent. Everyone starts with the cash assigned to the chosen board. Your aim is to remain solvent after all the others have gone bankrupt. Owning the most properties is useful, but is not itself a victory condition: you must still be able to meet your payments."),
          GameRoomRules.translate("On your turn, roll two dice and move by their sum. The field you reach determines what happens next: a purchase, rent, a tax, a card or another board instruction. The game moves to the next player once these decisions are settled; there is no separate End turn button. Doubles usually give you another roll, but three doubles in a row send you to jail without making the third move. Jail or a negative cash balance cancels an extra roll.")),
        rule_section(:ownership, GameRoomRules.translate("Buy a street, then complete its colour"),
          GameRoomRules.translate("An unowned street, station or utility may be bought when you land on it. The game gives its name, colour or type, and price. If you have enough cash, choose whether to buy. If you cannot afford it, the purchase is declined automatically. A property you do not buy remains available, unless the auction option sends it to auction."),
          GameRoomRules.translate("Streets belong to colour groups. Once you own every street in a group, you have a complete group: its undeveloped base rent doubles and you can start building there. For example, owning two out of three streets is still incomplete. The holdings lists show how many you own out of the whole group. Stations and utilities form their own sets, but never receive houses or hotels."),
          GameRoomRules.translate("Forbid buying properties on the first board round is off by default. If enabled, each player must first pass Start once before an unowned field offers them a purchase. This is your own first trip around the board, not the first circuit of turns taken by the table.")),
        rule_section(:auctions, GameRoomRules.translate("When a purchase becomes an auction"),
          GameRoomRules.translate("Put unsold properties up for auction is off by default. Turn it on if you want a declined purchase to be offered to the active players through bidding. Players take turns bidding or passing. Passing withdraws you from this auction. The remaining highest bidder pays their final bid and receives the property; the printed purchase price is not the amount automatically charged."),
          GameRoomRules.translate("Auction decision time is the number of seconds for one bid or pass. Zero, the default, gives unlimited time. A positive limit starts afresh for the next bidder after every accepted decision; exceeding it means an automatic pass. B lets you enter a total purchase bid, above the current bid and within your cash. Enter or G accepts the suggested next bid. You cannot save the game during an auction.")),
        rule_section(:rent, GameRoomRules.translate("Rent follows the deed"),
          GameRoomRules.translate("Landing on someone else's chargeable property makes you pay its owner. For a street, the amount depends on its rent schedule, colour group and buildings. Stations depend on how many stations the owner has. Utilities also use the dice total. A mortgaged property charges no rent. Open your holdings with V or another player's holdings with Shift+V, then press Enter on a property to check its current rent. For a utility, the description gives the multiplier of the visitor's dice total rather than using an earlier roll."),
          GameRoomRules.translate("Pay rents automatically is enabled by default. Without it, the owner decides whether to request or waive each eligible rent, and the visitor's move waits for this decision. Do not collect rent while in jail is a separate option, off by default. Enabling it removes rent income for an owner who is currently imprisoned; it does not remove their ownership.")),
        rule_section(:building, GameRoomRules.translate("Develop a group evenly"),
          GameRoomRules.translate("Manage your properties on your own turn before rolling, or while resolving your debt on that turn. To build, you need the complete colour group and no mortgages in that group. Add houses to the least developed streets first. In a three-street group you can reach one house on each before putting a second on any street. Four houses may be replaced by a hotel, the fifth development level."),
          GameRoomRules.translate("Selling reverses that process: remove buildings from the most developed streets and receive half their purchase price. The bank normally has 32 houses and 12 hotels on a 40-field board, or 48 houses and 18 hotels on a 60-field board. Turning a hotel back into four houses needs those houses to be available. If there are too few, the list explicitly offers selling all buildings in the colour group instead, still at half price."),
          GameRoomRules.translate("The building and selling lists show the colour, existing buildings and cost or proceeds. Confirm an operation with Enter and stay in the list to continue managing properties. If no operation is possible, the game explains why instead of making you select a building you cannot buy.")),
        rule_section(:mortgages, GameRoomRules.translate("Release cash without losing ownership"),
          GameRoomRules.translate("A mortgage pays you the property's mortgage value, while the property remains yours and stops earning rent. Before mortgaging a street, sell every building in its colour group. To remove the mortgage later, pay the mortgage amount plus 10%, rounded up to a whole money unit. For example, a mortgage of 100 costs 110 to clear. The lists display the actual payment before confirmation.")),
        rule_section(:trading, GameRoomRules.translate("Make an offer to another player"),
          GameRoomRules.translate("A trade may combine properties and cash from either side. E opens the players; Enter chooses a partner and announces that you are preparing an offer. It does not send an empty offer. In the form, enter the two cash amounts and choose properties from the two checkbox lists. Arrows move within a property list, while Tab moves between the form's sections. Send proposal submits the complete offer; Escape returns to the player list."),
          GameRoomRules.translate("Nothing changes hands until the recipient accepts. Both sides must still afford their payments and own the offered properties. Mortgaged properties and streets in a group with buildings cannot be traded. A bot may decline an apparently fair face-value purchase because the property completes or protects an important group; the printed price is not a promise that the owner will sell.")),
        rule_section(:debt, GameRoomRules.translate("When you owe more cash than you have"),
          GameRoomRules.translate("In Game Room, a negative balance ends your current turn. The other players take their turns before your next one begins. Then you can sell buildings, mortgage properties or arrange a trade to cover the shortfall. Roll remains the main action, but tells you how much is missing instead of rolling while the balance is negative. A payment charged outside your turn does not interrupt the current player's move."),
          GameRoomRules.translate("While in debt you may declare bankruptcy. It happens automatically on your own turn when you have no buildings left to sell and no property available to mortgage. A merely possible trade does not postpone this. If another player is your creditor, they receive your remaining properties and held jail cards, with buildings liquidated at half price. For a debt to the bank, the properties return to the bank. Bankruptcy ends your participation; the last player still solvent wins.")),
        rule_section(:jail, GameRoomRules.translate("Visiting jail is not being imprisoned"),
          GameRoomRules.translate("You are imprisoned only when a field, a card or three consecutive doubles sends you there. Simply stopping on the jail field is a visit. Before a prison roll, you may pay the exit fee or use a held jail card. Otherwise you have up to three turns to roll doubles. Successful doubles release you and move you by the roll, without an extra turn. After the third failed attempt, you pay and move by that roll."),
          GameRoomRules.translate("Lucky double one is off by default. If enabled, rolling two ones on a normal moving roll awards a quarter of the board's Start salary. The jail exit fee uses the same quarter-salary scale, rounded to whole money units.")),
        rule_section(:events, GameRoomRules.translate("Start, Free Parking and cards"),
          GameRoomRules.translate("Passing Start pays the board's salary. Double salary on Start, enabled by default, doubles that payment only when you land exactly on Start. Free parking jackpot is also on by default. Its pool starts at zero and collects eligible taxes and bank fees. Landing on Free Parking takes the whole pool and resets it to zero. Rent, trades, purchases, construction and mortgage transactions do not add to it. With the option off, Free Parking pays nothing."),
          GameRoomRules.translate("Chance and Community Chest use separate shuffled decks. A card may change money, move you, charge for buildings, send you to jail or give a retained jail-exit card. A retained card is unavailable in its deck until returned or used. Supplementary cards is enabled by default; turning it off removes the additional Game Room events, not the normal decks. Payments and destinations are adapted to the board you chose.")),
        rule_section(:boards, GameRoomRules.translate("Regional boards have their own figures"),
          GameRoomRules.translate("The default board is American / Atlantic City. A different board can change names, layout, currency, starting cash, Start salary and property economics. Larger boards also have more colour groups, stations and utilities. The profiles below are generated from the boards actually used by Game Room. Inspect individual deeds for purchase prices, rent levels and mortgage values."),
          GameRoomRules.translate("The Polish board is a custom Warsaw board. Regional data combines observed layouts and deed values with adapted salaries, fees, building costs and event cards; it is not a guarantee of matching every commercial or QC edition. In these profiles, Income Tax is one Start salary and Luxury Tax half a salary.")),
        rule_section(:board_profiles, _("Regional board details"),
          *GameRoomContent::MonopolyBoards.choices.map do |choice|
            board = GameRoomContent::MonopolyBoards.build(choice.value)
            squares = board[:squares]
            _("%{name}: %{fields} fields; currency: %{currency}; starting cash %{cash}; Start salary %{salary}; %{groups} colour groups, %{stations} stations, %{utilities} utilities; bank: %{houses} houses and %{hotels} hotels.") % {
              name: board[:name], fields: squares.length, currency: board[:currency],
              cash: board[:starting_cash], salary: board[:salary],
              groups: squares.select { |square| square[:type] == :property }.map { |square| square[:group] }.uniq.length,
              stations: squares.count { |square| square[:type] == :railroad },
              utilities: squares.count { |square| square[:type] == :utility },
              houses: board[:bank_houses], hotels: board[:bank_hotels]
            }
          end),
        rule_section(:controls, GameRoomRules.translate("Game keyboard shortcuts"),
          GameRoomRules.translate("Arrows: choose the current action or property."),
          GameRoomRules.translate("Enter: confirm the selected action."),
          GameRoomRules.translate("Escape: close the current list."),
          GameRoomRules.translate("I: read player positions and field numbers."),
          GameRoomRules.translate("T: read the turn and phase."),
          GameRoomRules.translate("C: read your cash."),
          GameRoomRules.translate("S: read player finances."),
          GameRoomRules.translate("F: read the current property's deed."),
          GameRoomRules.translate("D: browse unowned properties."),
          GameRoomRules.translate("Shift+D: browse the board."),
          GameRoomRules.translate("V: browse your properties."),
          GameRoomRules.translate("Shift+V: browse other players' properties."),
          GameRoomRules.translate("H: build houses or hotels."),
          GameRoomRules.translate("Shift+H: sell buildings."),
          GameRoomRules.translate("K: mortgage properties."),
          GameRoomRules.translate("Shift+K: unmortgage properties."),
          GameRoomRules.translate("E: prepare a trade."),
          GameRoomRules.translate("A: accept an incoming offer."),
          GameRoomRules.translate("R: reject an incoming offer."),
          GameRoomRules.translate("B: during an auction, enter your own total bid."),
          GameRoomRules.translate("G: during an auction, accept the suggested bid."),
          GameRoomRules.translate("Space: request rent when manual collection is available."),
          GameRoomRules.translate("P: pay to leave jail."),
          GameRoomRules.translate("J: use a get-out-of-jail card."))
      ]
    end

    def option_definitions
      [
        OptionDefinition.new(key: "board", label: _("Board to use"), kind: :choice, default: "atlantic_city", choices: GameRoomContent::MonopolyBoards.choices),
        OptionDefinition.new(key: "free_parking_jackpot", label: _("Free parking jackpot"), kind: :boolean, default: true),
        OptionDefinition.new(key: "double_salary_on_start", label: _("Double salary when landing on Start"), kind: :boolean, default: true),
        OptionDefinition.new(key: "forbid_first_round_purchase", label: _("Forbid buying properties on the first board round"), kind: :boolean, default: false),
        OptionDefinition.new(key: "no_rent_in_jail", label: _("Do not collect rent while in jail"), kind: :boolean, default: false),
        OptionDefinition.new(key: "lucky_double_one", label: _("Lucky double one"), kind: :boolean, default: false),
        OptionDefinition.new(key: "supplementary_cards", label: _("Supplementary Chance and Community Chest cards"), kind: :boolean, default: true),
        OptionDefinition.new(key: "automatic_rent", label: _("Pay rents automatically"), kind: :boolean, default: true),
        OptionDefinition.new(key: "auction_unsold", label: _("Put unsold properties up for auction"), kind: :boolean, default: false),
        OptionDefinition.new(key: "auction_decision_time", label: _("Auction decision time in seconds; 0 means no limit"), kind: :integer, default: 0,
          summary_label: _("Auction decision time"), summary_unit: :seconds, omit_zero: true,
          visible_if: { "auction_unsold" => true })
      ]
    end

    def options_error(options, player_count: nil)
      values = normalize_options(options)
      return _("Auction decision time cannot be negative.") if values["auction_decision_time"].to_i < 0
      super
    end

    def rules_option_visible?(definition, options)
      return false if definition.key.to_s == "auction_decision_time" && options[definition.key.to_s].to_i.zero?
      super
    end

    def options_summary(options)
      values = normalize_options(options)
      board = GameRoomContent::MonopolyBoards.build(values["board"])
      _("%{board}; free parking jackpot: %{jackpot}; automatic rent: %{rent}") % {
        board: board[:name], jackpot: values["free_parking_jackpot"] ? _("on") : _("off"),
        rent: values["automatic_rent"] ? _("on") : _("off")
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
        groups_before = %w[buy trade_accept auction_bid auction_pass auction_timeout bankrupt bankrupt_auto].include?(event["action"].to_s) ? completed_colour_groups(state) : nil
        applied = case event["action"].to_s
        when "roll" then apply_roll(state, event, actor, repository, history)
        when "buy" then apply_buy(state, event, actor, repository, history)
        when "decline" then apply_decline(state, event, actor, repository, history)
        when "build", "sell", "mortgage", "unmortgage" then apply_property_action(state, event, actor, repository, history)
        when "pay_jail", "use_jail_card" then apply_jail_action(state, event, actor, repository, history)
        when "request_rent", "waive_rent" then apply_manual_rent(state, event, actor, repository, history)
        when "trade_prepare", "trade_offer", "trade_accept", "trade_reject" then apply_trade(state, event, actor, repository, history)
        when "bankrupt" then apply_bankruptcy(state, event, actor, repository, history)
        when "bankrupt_auto" then apply_automatic_bankruptcy(state, event, actor, repository, history)
        when "auction_bid", "auction_pass" then apply_auction(state, event, actor, repository, history)
        when "auction_timeout" then apply_auction_timeout(state, event, actor, repository, history)
        else false
        end
        if applied
          announce_completed_groups(state, groups_before, repository.event_id(event), history) if groups_before
          settle_debts(state, repository.event_id(event), history)
          advance_completed_turn(state) if event["action"].to_s != "trade_prepare"
          accepted << event
        end
      end
      GameRoomSessionClock.attach(state, session)
      Replay.new(board: state[:board], players: players, current_player: state[:current_player], winner: state[:winner],
        draw: false, accepted_events: accepted, history: history, state: state)
    end

    def active_actors(replay)
      replay.current_player == nil ? [] : [replay.current_player]
    end

    def automatic_action_allowed?(replay, actor, table_owner:)
      super || (!replay.finished? && same_user?(actor, replay.current_player) && unaffordable_purchase?(replay.state))
    end

    def automatic_actor(replay, viewer, table_owner:)
      return viewer if !replay.finished? && same_user?(viewer, replay.current_player) && unaffordable_purchase?(replay.state)
      super
    end

    def automatic_action_due?(replay, actor, context: nil)
      state = replay.state
      return false if replay.finished?
      return true if same_user?(actor, replay.current_player) && unaffordable_purchase?(state)
      return false if !same_user?(actor, replay.players.first)
      return true if unavoidable_bankruptcy?(state)
      state[:phase] == :auction &&
        state[:auction_deadline].to_i > 0 && context&.now != nil && context.now.to_i >= state[:auction_deadline].to_i
    end

    def automatic_action(replay, actor, context: nil)
      return nil if replay.finished? || !automatic_action_due?(replay, actor, context: context)
      return { "kind" => "command", "action" => "decline" } if same_user?(actor, replay.current_player) && unaffordable_purchase?(replay.state)
      return { "kind" => "command", "action" => "bankrupt_auto" } if unavoidable_bankruptcy?(replay.state)
      { "kind" => "command", "action" => "auction_timeout" }
    end

    def legal_actions(replay, actor, context: nil, include_trade_offers: true)
      state = replay.state
      return [] if replay.finished? || !same_user?(state[:current_player], actor)
      player = player_key(state, actor)
      actions = []
      case state[:phase]
      when :awaiting_roll
        actions << { "kind" => "command", "action" => "roll" }
        actions.concat(management_actions(state, player))
        actions.concat(trade_actions(state, player)) if include_trade_offers
        actions << { "kind" => "command", "action" => "pay_jail" } if state[:jail][player].to_i > 0 && state[:cash][player] >= board_payment(state, 50)
        actions << { "kind" => "command", "action" => "use_jail_card" } if state[:jail_cards][player].to_i > 0 && state[:jail][player].to_i > 0
        actions << { "kind" => "command", "action" => "bankrupt" } if state[:cash][player] < 0
      when :property_decision
        square = current_square(state, player)
        actions << { "kind" => "command", "action" => "buy" } if state[:cash][player] >= square[:price].to_i
        actions << { "kind" => "command", "action" => "decline" }
      when :turn_complete
        actions.concat(management_actions(state, player))
        actions.concat(trade_actions(state, player)) if include_trade_offers
        actions << { "kind" => "command", "action" => "bankrupt" } if state[:cash][player] < 0
      when :auction
        amount = state[:auction_bid].to_i + auction_increment(state)
        actions << { "kind" => "command", "action" => "auction_bid", "amount" => amount } if state[:cash][player] >= amount
        actions << { "kind" => "command", "action" => "auction_pass" }
      when :rent_decision
        actions << { "kind" => "command", "action" => "request_rent" }
        actions << { "kind" => "command", "action" => "waive_rent" }
      when :trade_response
        actions << { "kind" => "command", "action" => "trade_accept" } if valid_trade_offer?(state)
        actions << { "kind" => "command", "action" => "trade_reject" }
      end
      actions
    end

    def action_for(selection, replay, actor, context: nil)
      state = replay.state
      return [:finished, nil] if replay.finished?
      action = selection["action"].to_s
      if action == "bankrupt_auto"
        return [:invalid, nil] if !same_user?(actor, replay.players.first) || !unavoidable_bankruptcy?(state)
        return [:ok, event_plan(action, "#{player_index(state[:players], state[:current_player])}|#{state[:turn_number]}")]
      end
      if action == "auction_timeout"
        return [:invalid, nil] if state[:phase] != :auction || !automatic_action_due?(replay, actor, context: context)
        value = [state[:auction_turn], player_index(state[:players], state[:current_player]), state[:auction_deadline], context.now.to_i].join("|")
        return [:ok, event_plan("auction_timeout", value)]
      end
      return [:not_your_turn, nil] if !same_user?(state[:current_player], actor)
      if action == "auction_bid"
        amount = Integer(selection["amount"].to_s, 10)
        return [:invalid_auction_bid, nil] if state[:phase] != :auction || amount <= state[:auction_bid] || amount > state[:cash][player_key(state, actor)]
        return [:ok, event_plan(action, "#{amount}|#{auction_action_time(context, state)}")]
      end
      if action == "trade_offer"
        return [:invalid, nil] if ![:awaiting_roll, :turn_complete].include?(state[:phase])
        value = selection["offer"].to_s
        if value.empty?
          value = encode_trade_offer(
            target: Integer(selection["target"].to_s, 10),
            give_properties: selection["give_properties"],
            receive_properties: selection["receive_properties"],
            give_cash: Integer(selection["give_cash"].to_s, 10),
            receive_cash: Integer(selection["receive_cash"].to_s, 10)
          )
        end
        offer = parse_trade_offer(state, value)
        return [:invalid_trade, nil] if offer == nil
        offer[:from] = player_key(state, actor)
        return [:empty_trade, nil] if empty_trade_offer?(offer)
        return [:invalid_trade, nil] if !valid_trade_offer?(state, offer)
        return [:ok, event_plan("trade_offer", value)]
      end
      if action == "trade_prepare"
        return [:invalid_trade, nil] if ![:awaiting_roll, :turn_complete].include?(state[:phase])
        target_index = Integer(selection["target"].to_s, 10)
        target = state[:players][target_index]
        player = player_key(state, actor)
        return [:invalid_trade, nil] if target == nil || same_user?(target, player) || !active_players(state).include?(target)
        return [:ok, event_plan("trade_prepare", target_index.to_s(36))]
      end
      if action == "roll"
        deficit = -state[:cash][player_key(state, actor)].to_i
        return [("insolvent_#{deficit}").to_sym, nil] if deficit > 0
        return [:invalid, nil] if state[:phase] != :awaiting_roll || context&.random_source == nil
        dice = context.random_source.roll(count: 2, sides: 6).values.map(&:to_i)
        return [:invalid, nil] if dice.length != 2
        seed = card_seed(context.random_source)
        return [:ok, event_plan("roll", "#{dice[0]},#{dice[1]},#{seed}")]
      end
      legal = legal_actions(replay, actor, context: context)
      candidate = legal.find do |item|
        item["action"] == action && (selection["property"].to_s.empty? || item["property"].to_s == selection["property"].to_s) &&
          (action != "auction_bid" || item["amount"].to_i == selection["amount"].to_i) &&
          (action != "trade_offer" || item["offer"].to_s == selection["offer"].to_s)
      end
      return [:invalid, nil] if candidate == nil
      value = if %w[build sell mortgage unmortgage].include?(action)
        candidate["property"].to_s
      elsif action == "auction_bid"
        candidate["amount"].to_i.to_s
      elsif action == "trade_offer"
        candidate["offer"].to_s
      elsif %w[decline auction_pass].include?(action)
        auction_action_time(context, state).to_s
      else ""
      end
      [:ok, event_plan(action, value)]
    rescue ArgumentError, TypeError
      [:invalid, nil]
    end

    def surface_spec(replay, viewer)
      state = replay.state
      all_actions = legal_actions(replay, viewer, include_trade_offers: false)
      actions = all_actions.reject { |action| %w[build sell mortgage unmortgage trade_offer pay_jail use_jail_card bankrupt].include?(action["action"]) }
      player = player_key(state, viewer)
      if !replay.finished? && same_user?(state[:current_player], viewer) && player != nil && state[:cash][player].to_i < 0 && [:awaiting_roll, :turn_complete].include?(state[:phase])
        actions = [{ "kind" => "command", "action" => "roll" }]
      end
      items = actions.map.with_index do |action, index|
        GameSurfaces::PawnTrackItem.new(id: "monopoly_#{index}", label: action_label(action, state, viewer),
          action: GameSurfaces::Action.new(kind: action["kind"], name: action["action"],
            payload: action.reject { |key, _| %w[kind action].include?(key) }, source: "monopoly_actions"))
      end
      if items.empty?
        label = replay.finished? ? result_text(replay) : waiting_text(state)
        items << GameSurfaces::PawnTrackItem.new(id: "status", label: label)
      end
      menus = %w[build sell mortgage unmortgage].to_h do |operation|
        choices = all_actions.select { |a| a["action"] == operation }.map do |a|
          GameSurfaces::PawnTrackItem.new(id: "#{operation}:#{a['property']}", label: action_label(a, state, viewer),
            action: GameSurfaces::Action.new(kind: "command", name: operation,
              payload: { "property" => a["property"] }, source: "monopoly_actions"))
        end
        [operation, choices]
      end
      GameSurfaces::PawnTrackSpec.new(id: "monopoly_actions", header: _("Monopoly"), items: items,
        menus: menus, empty_label: _("No action is available"))
    end

    def participant_scores(replay)
      replay.state[:players].to_h { |player| [player, net_worth(replay.state, player)] }
    end

    def participant_status(replay, participant, connected: true)
      player = player_key(replay.state, participant)
      return _("bankrupt") if player != nil && replay.state[:bankrupt][player]
      super
    end

    def custom_game_shortcuts(replay, viewer)
      state = replay.state
      player = player_key(state, viewer)
      actions = legal_actions(replay, viewer, include_trade_offers: false)
      shortcuts = [
        announcement_shortcut(key: "i", label: _("read player positions"), message: positions_text(state)),
        announcement_shortcut(key: "c", label: _("read your cash"), message: _("Your cash: %{cash}.") % { cash: state[:cash][player].to_i }),
        announcement_shortcut(key: "s", label: _("read finances"), message: finances_text(state)),
        announcement_shortcut(key: "f", label: _("read the current deed"), message: deed_text(state, current_square(state, player))),
        browse_shortcut(key: "d", label: _("browse unowned property"), prompt: _("Unowned property"), choices: property_choices(state) { |square| state[:owners][square[:index]] == nil }),
        browse_shortcut(key: "d", modifiers: [:shift], label: _("browse the board"), prompt: _("Board"), choices: board_choices(state)),
        browse_shortcut(key: "v", label: _("browse your holdings"), prompt: _("Your holdings"), choices: property_choices(state, group_progress: true) { |square| same_user?(state[:owners][square[:index]], player) }),
        browse_shortcut(key: "v", modifiers: [:shift], label: _("browse other holdings"), prompt: _("Other holdings"), choices: property_choices(state, group_progress: true) { |square| state[:owners][square[:index]] != nil && !same_user?(state[:owners][square[:index]], player) })
      ]
      shortcuts.concat(property_action_shortcuts(actions, state, viewer))
      {
        "pay_jail" => ["p", _("pay to leave jail")],
        "use_jail_card" => ["j", _("use a Get out of jail card")],
        "request_rent" => ["space", _("request the rent")],
        "bankrupt" => ["b", _("declare bankruptcy")]
      }.each do |action_name, (key, label)|
        next if !actions.any? { |action| action["action"] == action_name }

        shortcuts << GameShortcut.new(key: key, label: label, kind: :action,
          action_kind: "command", action_name: action_name)
      end
      bid = actions.find { |action| action["action"] == "auction_bid" }
      if bid != nil
        shortcuts << GameShortcut.new(key: "g", label: _("place the next auction bid"), kind: :action,
          action_kind: "command", action_name: "auction_bid", payload: { "amount" => bid["amount"] })
      end
      if state[:phase] == :auction && same_user?(state[:current_player], viewer) && player != nil
        minimum, maximum = state[:auction_bid].to_i + 1, state[:cash][player].to_i
        if maximum >= minimum
          shortcuts << GameShortcut.new(key: "b", label: _("enter your auction bid"), kind: :number_input,
            prompt: _("Your auction bid:"), default_value: bid ? bid["amount"] : minimum,
            allowed_values: minimum..maximum, value_key: "amount", action_kind: "command", action_name: "auction_bid")
        end
      end
      if same_user?(state[:current_player], viewer) && [:awaiting_roll, :turn_complete].include?(state[:phase]) && active_players(state).length > 1
        shortcuts << GameShortcut.new(
          key: "e", label: _("arrange a trade"), kind: :staged_form, prompt: _("Choose a player for the trade"),
          action_kind: "command", action_name: "trade_prepare", value_key: "target",
          choices: active_players(state).reject { |other| same_user?(other, player) }.map do |other|
            OptionChoice.new(value: player_index(state[:players], other), label: participant_name(other))
          end
        )
      end
      {
        "trade_accept" => ["a", _("accept the trade")],
        "trade_reject" => ["r", _("reject the trade")]
      }.each do |action_name, (key, label)|
        next if !actions.any? { |action| action["action"] == action_name }

        shortcuts << GameShortcut.new(key: key, label: label, kind: :action,
          action_kind: "command", action_name: action_name)
      end
      shortcuts
    end

    def staged_form_shortcut(shortcut, replay, viewer, selection)
      return nil if shortcut.action_name != "trade_prepare"

      state = replay.state
      player = player_key(state, viewer)
      target_index = Integer(selection["target"].to_s, 10)
      target = state[:players][target_index]
      return nil if player == nil || target == nil || same_user?(player, target)

      GameShortcut.new(
        key: "e", label: _("arrange a trade"), kind: :form, prompt: _("Trade proposal"),
        action_kind: "command", action_name: "trade_offer", payload: { "target" => target_index },
        fields: trade_form_fields(state, player, target)
      )
    rescue ArgumentError, TypeError
      nil
    end

    def move_error_for(status, selection: nil, replay: nil, actor: nil)
      case status
      when :empty_trade
        _("Choose at least one property or enter different cash amounts before sending the proposal.")
      when :invalid_trade
        _("This trade is no longer valid. Check the player, properties and available cash.")
      else
        super
      end
    end

    def bot_observation(replay, actor)
      state = replay.state
      { "phase" => state[:phase], "current_player" => state[:current_player], "positions" => state[:positions],
        "cash" => state[:cash], "owners" => state[:owners], "houses" => state[:houses],
        "mortgaged" => state[:mortgaged], "jackpot" => state[:jackpot] }
    end

    def bot_action_score(replay, actor, action, context: nil)
      state = replay.state
      player = player_key(state, actor)
      cash = state[:cash][player]
      square = state[:board][action["property"].to_i]
      reserve = monopoly_cash_reserve(state, player)
      case action["action"]
      when "roll" then cash < 0 ? -20_000 : 100
      when "buy"
        property = current_square(state, actor)
        cash - property[:price] >= reserve / 2 || trade_property_value(state, property[:index], player) >= property[:price] * 2 ? 500 : -20
      when "decline" then 0
      when "build"
        return -100 if cash - square[:house_cost] < reserve
        level = state[:houses][square[:index]]
        traffic = monopoly_expected_visits(state, square[:index], player)
        income = square[:rents][level + 1] - (level.zero? ? square[:rents][0] * 2 : square[:rents][level])
        # Hotels release four houses. Preserve a house shortage unless the
        # extra income on this particular street justifies releasing them.
        shortage = level == 4 && available_houses(state) <= 4
        200 + income.to_f / square[:house_cost] * (20 + traffic * 100) - (shortage ? 60 : 0)
      when "mortgage", "sell"
        return -200 if cash >= 0
        proceeds, lost_income = monopoly_liquidation_effect(state, player, square, action["action"])
        excess = [cash + proceeds, 0].max.to_f / [proceeds, 1].max
        1000 - lost_income * 100.0 / [proceeds, 1].max - excess * 15
      when "unmortgage" then cash - unmortgage_cost(square) >= reserve ? 250 : -100
      when "bankrupt" then -10_000
      when "auction_bid"
        limit = [trade_property_value(state, state[:auction_square], player), cash - reserve / 2].min
        action["amount"].to_i <= limit ? 100 : -100
      when "pay_jail", "use_jail_card"
        undeveloped = state[:board].count { |s| s[:price] && !state[:owners][s[:index]] }
        want_exit = undeveloped >= 6 || reserve < board_payment(state, 200)
        return 50 unless want_exit
        action["action"] == "use_jail_card" ? 210 : (cash - board_payment(state, 50) >= reserve ? 200 : 40)
      when "request_rent" then 1_000
      when "waive_rent" then -1_000
      when "trade_offer"
        offer = parse_trade_offer(state, action["offer"])
        return -30_000 if offer == nil || state[:rejected_trades]["#{player}|#{action['offer']}"]
        offer[:from] = player
        return -30_000 if !valid_trade_offer?(state, offer)
        # One proposal in a turn, at least two circuits between proposals to
        # the same person. These are strategy limits, not restrictions on humans.
        return -30_000 if state[:trade_offered_turn][player] == state[:turn_number]
        previous = state[:trade_target_turn][[player, offer[:target]]]
        return -30_000 if previous && state[:turn_number] - previous < state[:players].length * 2
        target_gain = trade_gain(state, offer, offer[:target])
        target_cash = state[:cash][offer[:target]] + offer[:give_cash] - offer[:receive_cash]
        return -30_000 if target_gain < money(state, 10) || target_cash < monopoly_cash_reserve(state, offer[:target])
        if cash < 0 && offer[:receive_cash] > 0 && offer[:receive_cash] >= -cash &&
            offer[:receive_cash] >= offer_properties(offer, :give).sum { |index| state[:board][index][:mortgage] }
          1100
        else
          gain = trade_gain(state, offer, player)
          gain > money(state, 50) && cash + offer[:receive_cash] - offer[:give_cash] >= reserve ? 200 + gain.to_f / money(state, 1) : (cash < 0 ? -30_000 : -100)
        end
      when "trade_accept" then monopoly_trade_safe?(state, player) ? 500 : -500
      when "trade_reject" then monopoly_trade_safe?(state, player) ? -100 : 300
      else 0
      end
    end

    def move_error(status)
      return _("Your auction bid must exceed the current bid and fit your available cash.") if status == :invalid_auction_bid
      if status.to_s.start_with?("insolvent_")
        amount = status.to_s.delete_prefix("insolvent_").to_i
        return _("You do not have enough money. You are %{amount} short.") % { amount: amount }
      end
      super
    end

    def describe_event(event, repository, replay, viewer)
      id = repository.event_id(event).to_i
      values = replay.history.filter_map { |entry| entry.text if entry.event_id.to_i == id }
      values.empty? ? nil : values
    end

    private

    def monopoly_liquidation_effect(state, player, square, action)
      if action == "sell" && hotel_liquidation?(state, square)
        group = colour_group_squares(state, square[:group])
        proceeds = group.sum { |property| property[:house_cost] * state[:houses][property[:index]] / 2 }
        lost_income = group.sum do |property|
          level = state[:houses][property[:index]]
          (property[:rents][level] - property[:rents][0] * 2) * monopoly_expected_visits(state, property[:index], player)
        end
      elsif action == "sell"
        level = state[:houses][square[:index]]
        proceeds = square[:house_cost] / 2
        after = level == 1 ? square[:rents][0] * 2 : square[:rents][level - 1]
        lost_income = (square[:rents][level] - after) * monopoly_expected_visits(state, square[:index], player)
      else
        proceeds = square[:mortgage]
        lost_income = monopoly_expected_rent(state, square, player) * monopoly_expected_visits(state, square[:index], player)
      end
      [proceeds, [lost_income, 0].max]
    end

    def initial_state(players, options)
      board_data = GameRoomContent::MonopolyBoards.build(options["board"])
      { players: players, options: options, board_data: board_data, board: board_data[:squares],
        current_player: players.first, phase: :awaiting_roll, positions: players.to_h { |player| [player, 0] },
        laps: players.to_h { |player| [player, 0] }, cash: players.to_h { |player| [player, board_data[:starting_cash]] },
        owners: {}, houses: Hash.new(0), mortgaged: {}, jail: Hash.new(0), jail_cards: Hash.new(0),
        bankrupt: players.to_h { |player| [player, false] }, doubles: 0, extra_turn: false,
        last_roll: 0,
        jackpot: 0, auction_square: nil, auction_bid: 0, auction_leader: nil, auction_passed: {}, auction_deadline: 0, auction_turn: 0,
        auction_origin: nil, rent_payer: nil, rent_owner: nil, rent_amount: 0,
        rent_origin: nil, trade_offer: nil, trade_phase: nil, winner: nil,
        debts: {}, card_decks: nil, held_jail_cards: {}, rejected_trades: {},
        turn_number: 0, trade_offered_turn: {}, trade_target_turn: {} }
    end

    def apply_roll(state, event, actor, repository, history)
      return false if state[:phase] != :awaiting_roll || !same_user?(state[:current_player], actor)
      first_text, second_text, seed = event["value"].to_s.split(",", 3)
      first, second = Integer(first_text, 10), Integer(second_text, 10)
      return false if !first.between?(1, 6) || !second.between?(1, 6) || seed.to_s !~ /\A(?:[0-9a-f]{32}|[1-9]|1[0-6])\z/
      player = player_key(state, actor)
      return false if state[:cash][player] < 0
      initialize_card_decks(state, seed) if state[:card_decks] == nil
      state[:roll_seed] = seed
      id = repository.event_id(event)
      state[:extra_turn] = first == second
      state[:doubles] = first == second ? state[:doubles] + 1 : 0
      state[:last_roll] = first + second
      history << HistoryEntry.new(key: "roll:#{id}", text: _("%{player} rolled %{first} and %{second}.") % { player: participant_name(player), first: first, second: second }, event_id: id, actor: actor, kind: :roll)
      if state[:jail][player] > 0
        state[:extra_turn] = false
        state[:doubles] = 0
        if first == second
          state[:jail][player] = 0
          history << HistoryEntry.new(key: "jail_release:#{id}", text: _("%{player} rolled doubles and left jail.") % { player: participant_name(player) }, event_id: id, actor: actor, kind: :game)
        else
          state[:jail][player] -= 1
          if state[:jail][player] > 0
            state[:phase] = :turn_complete
            history << HistoryEntry.new(key: "jail_wait:#{id}", text: _("%{player} remains in jail.") % { player: participant_name(player) }, event_id: id, actor: actor, kind: :game)
            return true
          end
          text = pay_and_describe(state, player, bank_recipient(state), board_payment(state, 50), _("release from jail"))
          history << HistoryEntry.new(key: "jail_payment:#{id}", text: text, event_id: id, actor: player, kind: :game)
        end
      end
      if state[:doubles] >= 3
        send_to_jail(state, player)
        state[:phase] = :turn_complete
        history << HistoryEntry.new(key: "triple:#{id}", text: _("%{player} rolled three doubles and goes to jail.") % { player: participant_name(player) }, event_id: id, actor: actor, kind: :game)
        return true
      end
      movement_effects = []
      move_player(state, player, first + second, id, movement_effects)
      history << HistoryEntry.new(key: "move:#{id}", text: _("%{player} lands on %{square}.") % { player: participant_name(player), square: current_square(state, player)[:name] }, event_id: id, actor: player, kind: :game)
      history.concat(movement_effects)
      if first == 1 && second == 1 && state[:options]["lucky_double_one"]
        bonus = board_payment(state, 50)
        state[:cash][player] += bonus
        history << HistoryEntry.new(key: "lucky:#{id}", text: _("%{player} receives %{amount} for lucky double one.") % { player: participant_name(player), amount: bonus }, event_id: id, actor: player, kind: :game)
      end
      resolve_square(state, player, id, history)
      true
    rescue ArgumentError
      false
    end

    def apply_buy(state, event, actor, repository, history)
      return false if state[:phase] != :property_decision || !same_user?(state[:current_player], actor)
      player = player_key(state, actor)
      square = current_square(state, player)
      return false if state[:owners][square[:index]] != nil || state[:cash][player] < square[:price].to_i
      state[:cash][player] -= square[:price].to_i
      state[:owners][square[:index]] = player
      state[:phase] = :turn_complete
      history << HistoryEntry.new(
        key: "buy:#{repository.event_id(event)}",
        text: _("%{player} bought %{property}, %{group}, for %{price}.") % {
          player: participant_name(player), property: square[:name],
          group: property_group_label(square), price: square[:price]
        },
        event_id: repository.event_id(event), actor: actor, kind: :game
      )
      true
    end

    def apply_decline(state, event, actor, repository, history)
      return false if state[:phase] != :property_decision || !same_user?(state[:current_player], actor)
      square = current_square(state, actor)
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "decline:#{id}", text: _("%{player} declined %{property}.") % { player: participant_name(actor), property: square[:name] }, event_id: id, actor: actor, kind: :game)
      if state[:options]["auction_unsold"]
        state[:phase] = :auction
        state[:auction_square] = square[:index]
        state[:auction_bid] = 0
        state[:auction_leader] = nil
        state[:auction_passed] = {}
        state[:auction_origin] = actor
        state[:current_player] = next_active_player(state, actor)
        set_auction_deadline(state, event["value"].to_i, id)
        history << HistoryEntry.new(key: "auction_start:#{id}", text: _("Auction begins: %{property}.") % { property: property_name_and_group(square) }, event_id: id, actor: actor, kind: :game)
      else
        state[:phase] = :turn_complete
      end
      true
    end

    def advance_completed_turn(state)
      return if state[:winner] || state[:phase] == :finished
      # A new debt ends this turn, not the next player's turn. Resolution is
      # available in the debtor's next awaiting_roll phase; roll validates cash.
      if state[:phase] == :property_decision && state[:cash][state[:current_player]].to_i < 0
        state[:phase] = :turn_complete
      end
      return if state[:phase] != :turn_complete || state[:current_player] == nil

      actor = state[:current_player]
      if state[:cash][actor].to_i >= 0 && state[:extra_turn] && state[:jail][player_key(state, actor)].zero?
        state[:phase] = :awaiting_roll
        state[:extra_turn] = false
      else
        state[:turn_number] += 1
        state[:current_player] = next_active_player(state, actor)
        state[:phase] = :awaiting_roll
        state[:doubles] = 0
        state[:extra_turn] = false
      end
    end

    def apply_property_action(state, event, actor, repository, history)
      action = event["action"].to_s
      index = Integer(event["value"].to_s, 10)
      player = player_key(state, actor)
      return false if !same_user?(state[:current_player], actor) || ![:awaiting_roll, :turn_complete].include?(state[:phase]) || !same_user?(state[:owners][index], player)
      square = state[:board][index]
      # Menu rows contain costs and building counts. Confirmations are separate
      # sentences so speech/history do not repeat that management information.
      case action
      when "build"
        return false if !can_build?(state, player, square)
        description = [
          _("%{player} builds the first house on %{property}."),
          _("%{player} builds the second house on %{property}."),
          _("%{player} builds the third house on %{property}."),
          _("%{player} builds the fourth house on %{property}."),
          _("%{player} builds a hotel on %{property}.")
        ].fetch(state[:houses][index].to_i)
        state[:cash][player] -= square[:house_cost]
        state[:houses][index] += 1
      when "sell"
        return false if !can_sell_building?(state, player, square)
        if hotel_liquidation?(state, square)
          description = _("%{player} sells all buildings in the %{group}.")
          # Without four available houses a hotel cannot be downgraded.
          # The explicitly labelled alternative sells the whole colour group.
          colour_group_squares(state, square[:group]).each do |property|
            level = state[:houses][property[:index]].to_i
            state[:cash][player] += level * property[:house_cost] / 2
            state[:houses][property[:index]] = 0
          end
        else
          description = state[:houses][index] == 5 ? _("%{player} sells a hotel on %{property}.") : _("%{player} sells a house on %{property}.")
          state[:houses][index] -= 1
          state[:cash][player] += square[:house_cost] / 2
        end
      when "mortgage"
        return false if !can_mortgage?(state, player, square)
        description = _("%{player} mortgages %{property}.")
        state[:mortgaged][index] = true
        state[:cash][player] += square[:mortgage]
      when "unmortgage"
        cost = unmortgage_cost(square)
        return false if !state[:mortgaged][index] || state[:cash][player] < cost
        description = _("%{player} unmortgages %{property}.")
        state[:mortgaged].delete(index)
        state[:cash][player] -= cost
      else
        return false
      end
      id = repository.event_id(event)
      history << HistoryEntry.new(key: "property:#{id}", text: description % {
        player: participant_name(player), property: square[:name], group: property_group_label(square)
      }, event_id: id, actor: actor, kind: :game)
      true
    rescue ArgumentError
      false
    end

    def apply_jail_action(state, event, actor, repository, history)
      player = player_key(state, actor)
      return false if state[:phase] != :awaiting_roll || !same_user?(state[:current_player], actor) || state[:jail][player].zero?
      if event["action"] == "pay_jail"
        return false if state[:cash][player] < board_payment(state, 50)
        text = pay_and_describe(state, player, bank_recipient(state), board_payment(state, 50), _("release from jail"))
      else
        return false if state[:jail_cards][player].zero?
        state[:jail_cards][player] -= 1
        held = (state[:held_jail_cards][player] || []).shift
        state[:card_decks][held[0]] << held[1] if held && state[:card_decks]
        text = _("%{player} uses a Get out of jail card and leaves jail.") % { player: participant_name(player) }
      end
      state[:jail][player] = 0
      history << HistoryEntry.new(key: "jail:#{repository.event_id(event)}", text: text, event_id: repository.event_id(event), actor: actor, kind: :game)
      true
    end

    def apply_manual_rent(state, event, actor, repository, history)
      return false if state[:phase] != :rent_decision || !same_user?(state[:current_player], actor)
      owner = player_key(state, actor)
      return false if owner == nil || !same_user?(owner, state[:rent_owner])

      payer = state[:rent_payer]
      amount = state[:rent_amount].to_i
      id = repository.event_id(event)
      if event["action"].to_s == "request_rent"
        text = pay_and_describe(state, payer, owner, amount, _("rent for %{property}") % { property: state[:board][state[:rent_origin]][:name] })
      else
        text = _("%{owner} waived the rent from %{player}.") % {
          owner: participant_name(owner), player: participant_name(payer)
        }
      end
      history << HistoryEntry.new(key: "rent:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      state[:current_player] = payer
      state[:phase] = :turn_complete
      clear_manual_rent(state)
      true
    end

    def apply_trade(state, event, actor, repository, history)
      action = event["action"].to_s
      id = repository.event_id(event)
      if action == "trade_prepare"
        return false if ![:awaiting_roll, :turn_complete].include?(state[:phase]) || !same_user?(state[:current_player], actor)
        target_index = Integer(event["value"].to_s, 36)
        target = state[:players][target_index]
        player = player_key(state, actor)
        return false if target == nil || same_user?(target, player) || !active_players(state).include?(target)

        history << HistoryEntry.new(key: "trade_prepare:#{id}", text: _("%{player} is preparing a trade offer for %{target}.") % {
          player: participant_name(player), target: participant_name(target)
        }, event_id: id, actor: actor, kind: :game)
        return true
      end
      if action == "trade_offer"
        return false if ![:awaiting_roll, :turn_complete].include?(state[:phase]) || !same_user?(state[:current_player], actor)
        offer = parse_trade_offer(state, event["value"])
        return false if offer == nil
        offer[:from] = player_key(state, actor)
        return false if !valid_trade_offer?(state, offer)
        offer[:encoded] = event["value"].to_s
        state[:trade_offered_turn][offer[:from]] = state[:turn_number]
        state[:trade_target_turn][[offer[:from], offer[:target]]] = state[:turn_number]
        state[:trade_offer] = offer
        state[:trade_phase] = state[:phase]
        state[:phase] = :trade_response
        state[:current_player] = offer[:target]
        history << HistoryEntry.new(key: "trade_offer:#{id}", text: _("%{player} proposed a trade to %{target}: %{offer}.") % {
          player: participant_name(offer[:from]), target: participant_name(offer[:target]), offer: public_trade_summary(state, offer)
        }, event_id: id, actor: actor, kind: :game)
        return true
      end

      offer = state[:trade_offer]
      return false if state[:phase] != :trade_response || offer == nil || !same_user?(state[:current_player], actor) || !same_user?(offer[:target], actor)
      if action == "trade_accept"
        return false if !valid_trade_offer?(state)
        execute_trade(state, offer)
        text = _("Trade completed: %{details}.") % { details: public_trade_summary(state, offer) }
      elsif action == "trade_reject"
        state[:rejected_trades]["#{offer[:from]}|#{offer[:encoded]}"] = true
        text = _("%{player} rejected the offer from %{proposer}.") % { player: participant_name(actor), proposer: participant_name(offer[:from]) }
      else
        return false
      end
      proposer = offer[:from]
      history << HistoryEntry.new(key: "trade_result:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      state[:current_player] = proposer
      state[:phase] = state[:trade_phase] || :turn_complete
      state[:trade_offer] = nil
      state[:trade_phase] = nil
      true
    rescue ArgumentError, TypeError
      false
    end

    def apply_bankruptcy(state, event, actor, repository, history)
      player = player_key(state, actor)
      return false if !same_user?(state[:current_player], actor) || state[:cash][player] >= 0
      settle_debts(state, repository.event_id(event), history)
      creditor = (state[:debts][player] || []).find { |debt| state[:players].include?(debt[:to]) && !state[:bankrupt][debt[:to]] }&.fetch(:to)
      state[:bankrupt][player] = true
      state[:owners].keys.each do |index|
        next if !same_user?(state[:owners][index], player)
        if creditor
          state[:owners][index] = creditor
          buildings = state[:houses][index].to_i
          state[:cash][creditor] += (buildings == 5 ? 5 : buildings) * state[:board][index][:house_cost].to_i / 2
        else
          state[:owners].delete(index)
          state[:mortgaged].delete(index)
        end
        state[:houses].delete(index)
      end
      held = state[:held_jail_cards].delete(player).to_a
      if creditor
        state[:jail_cards][creditor] += state[:jail_cards][player]
        (state[:held_jail_cards][creditor] ||= []).concat(held)
      else
        held.each { |deck, card| state[:card_decks][deck] << card }
      end
      state[:jail_cards][player] = 0
      state[:cash][player] = 0
      state[:debts].delete(player)
      state[:extra_turn] = false
      state[:doubles] = 0
      id = repository.event_id(event)
      text = creditor ? _("%{player} declared bankruptcy. Remaining property goes to %{creditor}.") % { player: participant_name(player), creditor: participant_name(creditor) } : _("%{player} declared bankruptcy. Remaining property returns to the bank.") % { player: participant_name(player) }
      history << HistoryEntry.new(key: "bankrupt:#{id}", text: text, event_id: id, actor: actor, kind: :game)
      remaining = active_players(state)
      if remaining.length == 1
        state[:winner] = remaining.first
        state[:current_player] = nil
        state[:phase] = :finished
        history << result_history(event_id: id, winner: state[:winner])
      else
        state[:turn_number] += 1
        state[:current_player] = next_active_player(state, player)
        state[:phase] = :awaiting_roll
      end
      true
    end

    def unaffordable_purchase?(state)
      return false if state[:phase] != :property_decision || state[:current_player] == nil
      player = player_key(state, state[:current_player])
      square = current_square(state, player)
      square != nil && state[:owners][square[:index]] == nil && state[:cash][player] < square[:price].to_i
    end

    def unavoidable_bankruptcy?(state)
      return false if state[:winner] || ![:awaiting_roll, :turn_complete].include?(state[:phase])
      player = player_key(state, state[:current_player])
      return false if player == nil || state[:bankrupt][player] || state[:cash][player] >= 0
      management_actions(state, player).none? { |action| %w[sell mortgage].include?(action["action"]) }
    end

    def apply_automatic_bankruptcy(state, event, actor, repository, history)
      return false if !same_user?(actor, state[:players].first) || !unavoidable_bankruptcy?(state)
      index, turn = event["value"].to_s.split("|", 2).map { |value| Integer(value, 10) }
      return false if turn != state[:turn_number] || index != player_index(state[:players], state[:current_player])
      apply_bankruptcy(state, event, state[:current_player], repository, history)
    rescue ArgumentError, TypeError
      false
    end

    def apply_auction(state, event, actor, repository, history, timed_out: false)
      return false if state[:phase] != :auction || !same_user?(state[:current_player], actor)
      player = player_key(state, actor)
      if event["action"] == "auction_bid"
        amount_text, timestamp_text = event["value"].to_s.split("|", 2)
        amount = Integer(amount_text, 10)
        return false if amount <= state[:auction_bid] || amount > state[:cash][player]
        state[:auction_bid] = amount
        state[:auction_leader] = player
        text = _("%{player} bids %{amount}.") % { player: participant_name(player), amount: amount }
      else
        timestamp_text = event["value"].to_s
        state[:auction_passed][player] = true
        text = (timed_out ? _("%{player} ran out of auction time and passes.") : _("%{player} passes in the auction.")) % { player: participant_name(player) }
      end
      history << HistoryEntry.new(key: "auction_action:#{repository.event_id(event)}", text: text, event_id: repository.event_id(event), actor: actor, kind: :game)
      candidates = active_players(state).reject { |candidate| state[:auction_passed][candidate] }
      if candidates.length <= 1 && state[:auction_leader] != nil
        winner = state[:auction_leader]
        state[:cash][winner] -= state[:auction_bid]
        state[:owners][state[:auction_square]] = winner
        history << HistoryEntry.new(key: "auction:#{repository.event_id(event)}", text: _("%{player} won the auction for %{property} at %{amount}.") % { player: participant_name(winner), property: property_name_and_group(state[:board][state[:auction_square]]), amount: state[:auction_bid] }, event_id: repository.event_id(event), actor: actor, kind: :game)
        state[:current_player] = player_key(state, state[:auction_origin]) || state[:auction_origin]
        state[:phase] = :turn_complete
      elsif candidates.empty?
        history << HistoryEntry.new(key: "auction:#{repository.event_id(event)}", text: _("Auction ended without a sale: %{property}.") % { property: property_name_and_group(state[:board][state[:auction_square]]) }, event_id: repository.event_id(event), actor: actor, kind: :game)
        state[:current_player] = player_key(state, state[:auction_origin]) || state[:auction_origin]
        state[:phase] = :turn_complete
      else
        state[:current_player] = next_auction_player(state, player)
      end
      set_auction_deadline(state, timestamp_text.to_i, repository.event_id(event))
      true
    rescue ArgumentError
      false
    end

    def auction_action_time(context, state)
      (context&.now || GameRoomSessionClock.for_state(state)).to_i
    end

    def set_auction_deadline(state, timestamp, event_id)
      duration = state[:options]["auction_decision_time"].to_i
      state[:auction_turn] = event_id
      state[:auction_deadline] = state[:phase] == :auction && duration > 0 && timestamp > 0 ? timestamp + duration : 0
    end

    def apply_auction_timeout(state, event, actor, repository, history)
      return false if !same_user?(actor, state[:players].first) || state[:phase] != :auction || state[:auction_deadline].to_i <= 0
      turn, index, deadline, timestamp = event["value"].to_s.split("|", 4).map { |value| Integer(value, 10) }
      return false if turn != state[:auction_turn].to_i || index != player_index(state[:players], state[:current_player]) || deadline != state[:auction_deadline] || timestamp == nil || timestamp < deadline
      passed = event.merge("action" => "auction_pass", "value" => timestamp.to_s)
      apply_auction(state, passed, state[:current_player], repository, history, timed_out: true)
    rescue ArgumentError, TypeError
      false
    end

    def move_player(state, player, distance, event_id, history)
      previous = state[:positions][player]
      destination = (previous + distance) % state[:board].length
      if previous + distance >= state[:board].length
        state[:laps][player] += 1
        salary = state[:board_data].fetch(:salary)
        salary *= 2 if destination.zero? && state[:options]["double_salary_on_start"]
        state[:cash][player] += salary
        text = destination.zero? && state[:options]["double_salary_on_start"] ? _("%{player} receives double salary, %{amount}, for landing on Start.") : _("%{player} collected %{amount} for passing Start.")
        history << HistoryEntry.new(key: "salary:#{event_id}:#{history.length}", text: text % { player: participant_name(player), amount: salary }, event_id: event_id, actor: player, kind: :game)
      end
      state[:positions][player] = destination
    end

    def resolve_square(state, player, event_id, history)
      square = current_square(state, player)
      case square[:type]
      when :property, :railroad, :utility
        owner = state[:owners][square[:index]]
        if owner == nil
          if state[:options]["forbid_first_round_purchase"] && state[:laps][player].zero?
            state[:phase] = :turn_complete
          else
            state[:phase] = :property_decision
            history << HistoryEntry.new(key: "purchase_offer:#{event_id}:#{square[:index]}",
              text: _("%{player} may buy %{property}, %{group}, for %{price}.") % {
                player: participant_name(player), property: square[:name], group: property_group_label(square), price: square[:price]
              }, event_id: event_id, actor: player, kind: :game)
          end
        elsif !same_user?(owner, player) && !state[:mortgaged][square[:index]] && !(state[:options]["no_rent_in_jail"] && state[:jail][owner] > 0)
          rent = rent_for(state, square, owner)
          rent *= state.delete(:card_rent_multiplier).to_i if state[:card_rent_multiplier]
          rent = state.delete(:card_utility_rent) if state[:card_utility_rent]
          if state[:options]["automatic_rent"]
            text = pay_and_describe(state, player, owner, rent, _("rent for %{property}") % { property: square[:name] })
            history << HistoryEntry.new(key: "rent:#{event_id}", text: text, event_id: event_id, actor: player, kind: :game)
            state[:phase] = :turn_complete
          else
            state[:rent_payer] = player
            state[:rent_owner] = owner
            state[:rent_amount] = rent
            state[:rent_origin] = square[:index]
            state[:current_player] = owner
            state[:phase] = :rent_decision
          end
        else
          state[:phase] = :turn_complete
        end
      when :tax, :tax_luxury
        amount = square.fetch(:amount)
        text = pay_and_describe(state, player, bank_recipient(state), amount, square[:name])
        history << HistoryEntry.new(key: "tax:#{event_id}",
          text: text, event_id: event_id, actor: player, kind: :game)
        state[:phase] = :turn_complete
      when :free_parking
        if state[:options]["free_parking_jackpot"] && state[:jackpot] > 0
          state[:cash][player] += state[:jackpot]
          history << HistoryEntry.new(key: "jackpot:#{event_id}", text: _("%{player} collected the Free Parking jackpot of %{amount}.") % { player: participant_name(player), amount: state[:jackpot] }, event_id: event_id, actor: player, kind: :game)
          state[:jackpot] = 0
        end
        state[:phase] = :turn_complete
      when :go_to_jail
        send_to_jail(state, player)
        history << HistoryEntry.new(key: "go_to_jail:#{event_id}", text: _("%{player} goes to jail.") % { player: participant_name(player) }, event_id: event_id, actor: player, kind: :game)
        state[:phase] = :turn_complete
      when :jail
        history << HistoryEntry.new(key: "jail_visit:#{event_id}", text: _("%{player} is only visiting jail.") % { player: participant_name(player) }, event_id: event_id, actor: player, kind: :game)
        state[:phase] = :turn_complete
      when :chance, :community
        state[:phase] = :turn_complete
        draw_event_card(state, player, square[:type], event_id, history)
      else
        state[:phase] = :turn_complete
      end
    end


    def card_definitions(state, deck)
      targets = state[:board_data].fetch(:card_destinations)
      cards = if deck == :chance
        [[:advance, targets[:most_expensive]], [:advance, targets[:start]], [:advance, targets[:middle_group]], [:advance, targets[:after_jail]],
          [:nearest, :railroad], [:nearest, :railroad], [:nearest, :utility],
          [:collect, 50], [:jail_free], [:back, 3], [:jail], [:repairs, 25, 100],
          [:pay, 15], [:advance, targets[:first_station]], [:pay_each, 50], [:collect, 150]]
      else
        [[:advance, targets[:start]], [:collect, 200], [:pay, 50], [:collect, 50], [:jail_free],
          [:jail], [:collect, 100], [:collect, 20], [:collect_each, 10],
          [:collect, 100], [:pay, 100], [:pay, 50], [:collect, 25],
          [:repairs, 40, 115], [:collect, 10], [:collect, 100]]
      end
      cards += deck == :chance ? [[:collect, 200], [:pay_each, 25]] : [[:collect_each, 25], [:pay, 75]] if state[:options]["supplementary_cards"]
      # Scale only monetary card effects, never destinations, dice or distances.
      cards.map do |card|
        if card.first == :repairs
          [card.first, *card.drop(1).map { |amount| money(state, amount) }]
        elsif [:collect, :pay, :pay_each, :collect_each].include?(card.first)
          [card.first, *card.drop(1).map { |amount| board_payment(state, amount) }]
        else
          card
        end
      end
    end

    def initialize_card_decks(state, seed)
      state[:card_decks] = [:chance, :community].to_h do |deck|
        [deck, shuffled_cards((0...card_definitions(state, deck).length).to_a, "#{seed}:#{deck}")]
      end
    end

    def draw_event_card(state, player, deck, event_id, history)
      initialize_card_decks(state, state[:roll_seed] || event_id.to_s) if !state[:card_decks]
      index = state[:card_decks][deck].shift
      return if index == nil
      kind, amount, hotel = card_definitions(state, deck).fetch(index)
      state[:card_decks][deck] << index if kind != :jail_free
      destination = nil
      movement_effects = []
      text = case kind
      when :collect
        state[:cash][player] += amount
        _("%{player} receives %{amount} from the bank.") % { player: participant_name(player), amount: amount }
      when :pay
        pay_and_describe(state, player, bank_recipient(state), amount, _("card fee"))
      when :collect_each, :pay_each
        exceptions = []
        payments = []
        active_players(state).reject { |other| same_user?(other, player) }.each do |other|
          payer, recipient = kind == :collect_each ? [other, player] : [player, other]
          short = state[:cash][payer] < amount
          payment = pay_and_describe(state, payer, recipient, amount, _("card payment"))
          payments << payment
          exceptions << payment if short
        end
        template = if exceptions.empty?
          kind == :collect_each ? _("%{player} receives %{amount} from each other player.") : _("%{player} pays %{amount} to each other player.")
        else
          nil
        end
        template ? template % { player: participant_name(player), amount: amount } : payments.join(" ")
      when :repairs
        total = owned_squares(state, player).sum do |square|
          level = state[:houses][square[:index]].to_i
          fee = level == 5 ? hotel : level * amount
          # Costlier extension buildings have proportionate repair bills.
          # The first eight colours retain the established repair schedule.
          reference_cost = money(state, 200)
          (fee * [square[:house_cost].to_i, reference_cost].max + reference_cost - 1) / reference_cost
        end
        pay_and_describe(state, player, bank_recipient(state), total, _("property repairs"))
      when :jail_free
        state[:jail_cards][player] += 1
        (state[:held_jail_cards][player] ||= []) << [deck, index]
        _("%{player} keeps a Get out of jail card.") % { player: participant_name(player) }
      when :jail
        send_to_jail(state, player)
        _("%{player} goes to jail.") % { player: participant_name(player) }
      when :advance, :back, :nearest
        previous = state[:positions][player]
        destination = if kind == :advance
          amount
        elsif kind == :back
          (previous - amount) % state[:board].length
        else
          (1..state[:board].length).map { |distance| (previous + distance) % state[:board].length }.find { |position| state[:board][position][:type] == amount }
        end
        if kind == :back
          state[:positions][player] = destination
        else
          distance = (destination - previous) % state[:board].length
          move_player(state, player, distance, event_id, movement_effects)
        end
        if kind == :nearest && amount == :railroad
          state[:card_rent_multiplier] = 2
        elsif kind == :nearest && amount == :utility
          random = Random.new(Digest::SHA256.hexdigest("#{state[:roll_seed]}:utility:#{event_id}").to_i(16))
          state[:card_utility_rent] = (random.rand(6) + random.rand(6) + 2) * money(state, 10)
        end
        _("%{player} moves to %{square}.") % { player: participant_name(player), square: state[:board][destination][:name] }
      end
      history << HistoryEntry.new(key: "card:#{event_id}:#{deck}", text: _("%{deck}: %{effect}") % {
        deck: deck == :chance ? _("Chance") : _("Community Chest"), effect: text
      }, event_id: event_id, actor: player, kind: :game)
      history.concat(movement_effects)
      if destination
        resolve_square(state, player, event_id, history)
        state.delete(:card_rent_multiplier)
        state.delete(:card_utility_rent)
      end
    end

    def send_to_jail(state, player)
      state[:positions][player] = state[:board_data].fetch(:jail_index)
      state[:jail][player] = 3
      state[:extra_turn] = false
    end

    def bank_recipient(state)
      state[:options]["free_parking_jackpot"] ? :jackpot : :bank
    end

    def recipient_name(recipient)
      return _("the bank") if recipient == :bank
      return _("the Free Parking pool") if recipient == :jackpot
      participant_name(recipient)
    end

    # Describe the existing transfer, including its unpaid part. Keep the
    # accounting in pay_money, shared with simulations and debt settlement.
    def pay_and_describe(state, player, recipient, amount, reason)
      amount = [amount.to_i, 0].max
      paid = [[state[:cash][player], 0].max, amount].min
      pay_money(state, player, recipient, amount)
      text = if recipient == :jackpot
        _("%{player} pays %{amount} into the Free Parking pool: %{reason}.") % {
          player: participant_name(player), amount: paid, reason: reason
        }
      elsif state[:players].include?(recipient)
        _("%{player} pays %{recipient} %{amount}: %{reason}.") % {
          player: participant_name(player), recipient: participant_name(recipient), amount: paid, reason: reason
        }
      else
        _("%{player} paid %{amount} to %{recipient}: %{reason}.") % {
          player: participant_name(player), amount: paid, recipient: recipient_name(recipient), reason: reason
        }
      end
      if paid < amount
        text += " " + _("%{player} still owes %{amount} to %{recipient}.") % { player: participant_name(player), amount: amount - paid, recipient: recipient_name(recipient) }
      end
      text
    end

    def pay_money(state, player, recipient, amount)
      amount = [amount.to_i, 0].max
      paid = [[state[:cash][player], 0].max, amount].min
      state[:cash][player] -= amount
      credit_money(state, recipient, paid)
      if paid < amount
        (state[:debts][player] ||= []) << { to: recipient, amount: amount - paid }
      end
    end

    def credit_money(state, recipient, amount)
      if recipient == :jackpot
        state[:jackpot] += amount
      elsif state[:players].include?(recipient) && !state[:bankrupt][recipient]
        state[:cash][recipient] += amount
      end
    end

    def settle_debts(state, event_id = nil, history = nil)
      loop do
        paid_any = false
        state[:debts].each do |player, debts|
          available = [state[:cash][player] + debts.sum { |debt| debt[:amount] }, 0].max
          debts.each do |debt|
            paid = [available, debt[:amount]].min
            next if paid <= 0
            debt[:amount] -= paid
            available -= paid
            credit_money(state, debt[:to], paid)
            if history != nil
              text = _("%{player} repays %{amount} of debt to %{recipient}.") % { player: participant_name(player), amount: paid, recipient: recipient_name(debt[:to]) }
              if debt[:amount] > 0
                text += " " + _("%{player} still owes %{amount} to %{recipient}.") % { player: participant_name(player), amount: debt[:amount], recipient: recipient_name(debt[:to]) }
              end
              history << HistoryEntry.new(key: "debt:#{event_id}:#{history.length}", text: text, event_id: event_id, actor: player, kind: :game)
            end
            paid_any = true
          end
          debts.reject! { |debt| debt[:amount] <= 0 }
        end
        break if !paid_any
      end
    end

    def management_actions(state, player)
      actions = []
      owned_squares(state, player).each do |square|
        index = square[:index].to_s
        if can_build?(state, player, square)
          actions << { "kind" => "command", "action" => "build", "property" => index }
        end
        actions << { "kind" => "command", "action" => "sell", "property" => index } if can_sell_building?(state, player, square)
        actions << { "kind" => "command", "action" => "mortgage", "property" => index } if can_mortgage?(state, player, square)
        cost = unmortgage_cost(square)
        actions << { "kind" => "command", "action" => "unmortgage", "property" => index } if state[:mortgaged][square[:index]] && state[:cash][player] >= cost
      end
      actions
    end

    def owns_group?(state, player, group)
      squares = colour_group_squares(state, group)
      squares.length > 1 && squares.all? { |square| same_user?(state[:owners][square[:index]], player) }
    end

    def colour_group_squares(state, group)
      state[:board].select { |square| square[:type] == :property && square[:group] == group }
    end

    def can_build?(state, player, square)
      return false if square == nil || square[:type] != :property || !owns_group?(state, player, square[:group])
      group = colour_group_squares(state, square[:group])
      return false if group.any? { |property| state[:mortgaged][property[:index]] }
      return false if state[:houses][square[:index]].to_i >= 5 || state[:cash][player].to_i < square[:house_cost].to_i
      level = state[:houses][square[:index]].to_i
      return false if level < 4 && available_houses(state) <= 0
      return false if level == 4 && state[:houses].values.count(5) >= state[:board_data].fetch(:bank_hotels)

      state[:houses][square[:index]].to_i == group.map { |property| state[:houses][property[:index]].to_i }.min
    end

    def can_sell_building?(state, player, square)
      return false if square == nil || square[:type] != :property || !same_user?(state[:owners][square[:index]], player)
      group = colour_group_squares(state, square[:group])
      level = state[:houses][square[:index]].to_i
      if hotel_liquidation?(state, square)
        return group.all? { |property| same_user?(state[:owners][property[:index]], player) } &&
          square[:index] == group.select { |property| state[:houses][property[:index]] == 5 }.map { |property| property[:index] }.min
      end
      level > 0 && level == group.map { |property| state[:houses][property[:index]].to_i }.max
    end

    def hotel_liquidation?(state, square)
      square != nil && state[:houses][square[:index]] == 5 && available_houses(state) < 4
    end

    def available_houses(state)
      state[:board_data].fetch(:bank_houses) - state[:houses].values.reject { |level| level == 5 }.sum
    end

    def can_mortgage?(state, player, square)
      return false if square == nil || !same_user?(state[:owners][square[:index]], player) || state[:mortgaged][square[:index]]
      return false if state[:houses][square[:index]].to_i > 0
      return true if square[:type] != :property

      colour_group_squares(state, square[:group]).all? { |property| state[:houses][property[:index]].to_i.zero? }
    end

    def rent_for(state, square, owner)
      if square[:type] == :railroad
        count = owned_squares(state, owner).count { |item| item[:type] == :railroad }
        return money(state, [25, 50, 100, 200, 400, 600].fetch(count - 1))
      end
      if square[:type] == :utility
        utilities = owned_squares(state, owner).count { |item| item[:type] == :utility }
        return state[:last_roll].to_i * money(state, [4, 10, 25, 50].fetch(utilities - 1))
      end
      houses = state[:houses][square[:index]].to_i
      rent = square[:rents][houses]
      rent *= 2 if houses.zero? && owns_group?(state, owner, square[:group])
      rent
    end

    def current_square(state, player)
      key = player_key(state, player) || player
      state[:board][state[:positions][key].to_i]
    end

    def player_key(state, actor)
      state[:players].find { |player| same_user?(player, actor) }
    end

    def active_players(state)
      state[:players].reject { |player| state[:bankrupt][player] }
    end

    def next_active_player(state, actor)
      index = player_index(state[:players], actor)
      state[:players].length.times do
        index = (index + 1) % state[:players].length
        return state[:players][index] if !state[:bankrupt][state[:players][index]]
      end
      actor
    end

    def next_auction_player(state, actor)
      candidate = next_active_player(state, actor)
      state[:players].length.times do
        return candidate if !state[:auction_passed][candidate]
        candidate = next_active_player(state, candidate)
      end
      candidate
    end

    def auction_increment(state)
      [money(state, 10), (state[:auction_bid] * 0.1).ceil].max
    end

    def money(state, amount)
      amount * state[:board_data].fetch(:money_factor)
    end

    def board_payment(state, amount)
      # Reference 40-square salary is 200. Use the selected board's salary
      # for unverified flat fees/prizes, rounding half up in integer units.
      (amount * state[:board_data].fetch(:salary) + 100) / 200
    end

    def owned_squares(state, player)
      state[:board].select { |square| same_user?(state[:owners][square[:index]], player) }
    end

    def net_worth(state, player)
      state[:cash][player].to_i + owned_squares(state, player).sum { |square| square[:price].to_i + state[:houses][square[:index]].to_i * square[:house_cost].to_i }
    end

    def action_label(action, state, viewer)
      index = action["property"].to_i
      property = state[:board][index]
      case action["action"]
      when "roll" then _("Roll the dice")
      when "buy" then _("Buy")
      when "decline" then _("Do not buy")
      when "build" then _("Build on %{property}; buildings: %{count}; cost: %{amount}") % {
        property: property_name_and_group(property), count: building_count_text(state, property), amount: property[:house_cost] }
      when "sell"
        if hotel_liquidation?(state, property)
          _("Sell all buildings in %{group}; receive %{amount}; no houses in the bank") % {
            group: property_group_label(property), amount: colour_group_squares(state, property[:group]).sum { |s| state[:houses][s[:index]].to_i * s[:house_cost] / 2 } }
        else
          _("Sell a building on %{property}; buildings: %{count}; receive %{amount}") % {
            property: property_name_and_group(property), count: building_count_text(state, property), amount: property[:house_cost] / 2 }
        end
      when "mortgage" then _("Mortgage %{property}; receive %{amount}") % { property: property_name_and_group(property), amount: property[:mortgage] }
      when "unmortgage" then _("Unmortgage %{property}; cost: %{amount}") % { property: property_name_and_group(property), amount: unmortgage_cost(property) }
      when "pay_jail" then _("Pay %{amount} to leave jail") % { amount: board_payment(state, 50) }
      when "use_jail_card" then _("Use a Get out of jail card")
      when "bankrupt" then _("Declare bankruptcy")
      when "auction_bid" then _("Bid %{amount}") % { amount: action["amount"] }
      when "auction_pass" then _("Pass in the auction")
      when "request_rent" then _("Request %{amount} rent from %{player}") % { amount: state[:rent_amount], player: participant_name(state[:rent_payer]) }
      when "waive_rent" then _("Do not request this rent")
      when "trade_offer" then trade_label(state, action["offer"])
      when "trade_accept" then _("Accept the proposed trade")
      when "trade_reject" then _("Reject the proposed trade")
      else action["action"]
      end
    end

    def trade_actions(state, player)
      return [] if player == nil
      own = tradeable_squares(state, player)
      active_players(state).reject { |target| same_user?(target, player) }.flat_map do |target|
        theirs = tradeable_squares(state, target)
        target_index = player_index(state[:players], target)
        offers = own.map do |square|
          encode_trade_offer(target: target_index, give_property: square[:index], receive_cash: square[:price])
        end
        offers.concat(theirs.filter_map do |square|
          next if state[:cash][player].to_i < square[:price].to_i
          encode_trade_offer(target: target_index, receive_property: square[:index], give_cash: square[:price])
        end)
        offers.concat(own.product(theirs).map do |given, received|
          encode_trade_offer(target: target_index, give_property: given[:index], receive_property: received[:index])
        end)
        # Add negotiated prices, sharing the gain from completing a group.
        # Exact face-value offers remain legal for the human trade form/replay.
        [[own, player, target, true], [theirs, target, player, false]].each do |squares, seller, buyer, selling|
          squares.each do |square|
            probe = parse_trade_offer(state, encode_trade_offer(target: target_index,
              give_property: selling ? square[:index] : -1, receive_property: selling ? -1 : square[:index]))
            probe[:from] = player
            loss = -trade_gain(state, probe, seller)
            gain = trade_gain(state, probe, buyer)
            next if gain <= loss + money(state, 20)
            price = (loss + gain) / 2
            offers << encode_trade_offer(target: target_index,
              give_property: selling ? square[:index] : -1, receive_property: selling ? -1 : square[:index],
              receive_cash: selling ? price : 0, give_cash: selling ? 0 : price)
          end
        end
        offers.map { |offer| { "kind" => "command", "action" => "trade_offer", "offer" => offer } }
      end
    end

    def tradeable_squares(state, player)
      owned_squares(state, player).select { |square| tradeable_index?(state, square[:index]) }
    end

    TRADE_OFFER_VERSION = "2".freeze
    TRADE_CASH_LIMIT = 99_999_999

    def encode_trade_offer(target:, give_property: -1, receive_property: -1, give_properties: nil, receive_properties: nil, give_cash: 0, receive_cash: 0)
      give = normalize_offer_indices(give_properties, give_property)
      receive = normalize_offer_indices(receive_properties, receive_property)
      [
        TRADE_OFFER_VERSION,
        Integer(target.to_s, 10).to_s(36),
        property_mask(give).to_s(36),
        property_mask(receive).to_s(36),
        Integer(give_cash.to_s, 10),
        Integer(receive_cash.to_s, 10)
      ].join("|")
    end

    def parse_trade_offer(state, value)
      parts = value.to_s.split("|", -1)
      if parts.length == 6 && parts.first == TRADE_OFFER_VERSION
        target_index = Integer(parts[1], 36)
        give_mask = Integer(parts[2], 36)
        receive_mask = Integer(parts[3], 36)
        give_cash = Integer(parts[4], 10)
        receive_cash = Integer(parts[5], 10)
        return nil if give_mask < 0 || receive_mask < 0
        return nil if (give_mask >> state[:board].length) != 0 || (receive_mask >> state[:board].length) != 0
        give = indices_from_property_mask(give_mask, state[:board].length)
        receive = indices_from_property_mask(receive_mask, state[:board].length)
      elsif value.to_s.start_with?("{")
        data = JSON.parse(value)
        target_index = data.fetch("target")
        return nil if !target_index.is_a?(Integer)
        give = data.fetch("give_properties")
        receive = data.fetch("receive_properties")
        return nil if !give.is_a?(Array) || !receive.is_a?(Array)
        return nil if (give + receive).any? { |index| !index.is_a?(Integer) || index < 0 }
        give_cash, receive_cash = data.fetch("give_cash"), data.fetch("receive_cash")
        return nil if !give_cash.is_a?(Integer) || !receive_cash.is_a?(Integer)
      else
        return nil if parts.length != 5
        target_index, given, received, give_cash, receive_cash = parts.map { |part| Integer(part, 10) }
        return nil if given < -1 || received < -1
        give, receive = given == -1 ? [] : [given], received == -1 ? [] : [received]
      end
      return nil if !target_index.between?(0, state[:players].length - 1) || give.uniq != give || receive.uniq != receive
      { target: state[:players][target_index], give_property: give.first || -1, receive_property: receive.first || -1,
        give_properties: give, receive_properties: receive, give_cash: give_cash, receive_cash: receive_cash }
    rescue ArgumentError, TypeError, KeyError, JSON::ParserError
      nil
    end

    def normalize_offer_indices(indices, single)
      values = indices == nil ? (single.to_i < 0 ? [] : [single]) : indices.to_a
      values.map { |index| Integer(index.to_s, 10) }.uniq.sort
    end

    def property_mask(indices)
      indices.to_a.reduce(0) do |mask, index|
        raise ArgumentError, "invalid property index" if index.to_i < 0
        mask | (1 << index.to_i)
      end
    end

    def indices_from_property_mask(mask, board_length)
      board_length.times.select { |index| (mask & (1 << index)) != 0 }
    end

    def empty_trade_offer?(offer)
      offer_properties(offer, :give).empty? && offer_properties(offer, :receive).empty? &&
        offer[:give_cash].to_i == offer[:receive_cash].to_i
    end

    def valid_trade_offer?(state, offer = state[:trade_offer])
      return false if offer == nil || !active_players(state).include?(offer[:from]) || !active_players(state).include?(offer[:target])
      return false if same_user?(offer[:from], offer[:target])
      return false if offer[:give_cash] < 0 || offer[:receive_cash] < 0
      return false if offer[:give_cash] > TRADE_CASH_LIMIT || offer[:receive_cash] > TRADE_CASH_LIMIT
      return false if empty_trade_offer?(offer)
      return false if offer[:give_cash] > 0 && state[:cash][offer[:from]].to_i + offer[:receive_cash] < offer[:give_cash]
      return false if offer[:receive_cash] > 0 && state[:cash][offer[:target]].to_i + offer[:give_cash] < offer[:receive_cash]
      offer_properties(offer, :give).each do |index|
        return false if !same_user?(state[:owners][index], offer[:from]) || !tradeable_index?(state, index)
      end
      offer_properties(offer, :receive).each do |index|
        return false if !same_user?(state[:owners][index], offer[:target]) || !tradeable_index?(state, index)
      end
      true
    end

    def tradeable_index?(state, index)
      square = state[:board][index]
      square != nil && [:property, :railroad, :utility].include?(square[:type]) &&
        state[:houses][index].to_i.zero? && !state[:mortgaged][index] &&
        (square[:type] != :property || colour_group_squares(state, square[:group]).all? { |property| state[:houses][property[:index]].to_i.zero? })
    end

    def execute_trade(state, offer)
      from = offer[:from]
      target = offer[:target]
      state[:cash][from] += offer[:receive_cash] - offer[:give_cash]
      state[:cash][target] += offer[:give_cash] - offer[:receive_cash]
      offer_properties(offer, :give).each { |index| state[:owners][index] = target }
      offer_properties(offer, :receive).each { |index| state[:owners][index] = from }
    end

    def trade_label(state, value)
      offer = parse_trade_offer(state, value)
      return _("Trade") if offer == nil
      parts = []
      offer_properties(offer, :give).each { |index| parts << _("give %{property}") % { property: property_name_and_group(state[:board][index]) } }
      parts << _("give %{amount}") % { amount: offer[:give_cash] } if offer[:give_cash] > 0
      offer_properties(offer, :receive).each { |index| parts << _("receive %{property}") % { property: property_name_and_group(state[:board][index]) } }
      parts << _("receive %{amount}") % { amount: offer[:receive_cash] } if offer[:receive_cash] > 0
      _("Trade with %{player}: %{details}") % { player: participant_name(offer[:target]), details: parts.join(", ") }
    end

    def public_trade_summary(state, offer)
      [[:give, offer[:from], offer[:target]], [:receive, offer[:target], offer[:from]]].filter_map do |side, from, target|
        assets = offer_properties(offer, side).map { |index| property_name_and_group(state[:board][index]) }
        cash = offer["#{side}_cash".to_sym].to_i
        assets << _("cash: %{amount}") % { amount: cash } if cash > 0
        next if assets.empty?
        _("%{from} to %{target}: %{assets}") % { from: participant_name(from), target: participant_name(target), assets: assets.join(", ") }
      end.join("; ")
    end

    def offer_properties(offer, side)
      offer["#{side}_properties".to_sym] || (offer["#{side}_property".to_sym].to_i >= 0 ? [offer["#{side}_property".to_sym]] : [])
    end

    def trade_form_fields(state, player, target)
      own = tradeable_squares(state, player).map do |square|
        OptionChoice.new(value: square[:index], label: property_name_and_group(square))
      end
      theirs = tradeable_squares(state, target).map do |square|
        OptionChoice.new(value: square[:index], label: property_name_and_group(square))
      end
      own = [OptionChoice.new(value: nil, label: _("No matching property."))] if own.empty?
      theirs = [OptionChoice.new(value: nil, label: _("No matching property."))] if theirs.empty?
      [
        OptionDefinition.new(key: "give_cash", label: _("Money you offer"), kind: :integer, default: 0),
        OptionDefinition.new(key: "receive_cash", label: _("Money you request"), kind: :integer, default: 0),
        OptionDefinition.new(key: "give_properties", label: _("Your properties in the offer"), kind: :multiple_choice, choices: own),
        OptionDefinition.new(key: "receive_properties", label: _("Requested properties from %{player}") % { player: participant_name(target) }, kind: :multiple_choice, choices: theirs)
      ]
    end

    def monopoly_cash_reserve(state, player)
      rents = state[:board].filter_map do |square|
        owner = state[:owners][square[:index]]
        monopoly_expected_rent(state, square, owner) if owner && !same_user?(owner, player) && !state[:mortgaged][square[:index]]
      end
      baseline = [board_payment(state, 100) + rents.max(3).sum / 3, board_payment(state, 500)].min
      exposure = monopoly_landing_probabilities(state).fetch(player, {}).sum do |index, probability|
        square = state[:board][index]
        owner = state[:owners][index]
        rent = owner && !same_user?(owner, player) && !state[:mortgaged][index] ? monopoly_expected_rent(state, square, owner) : 0
        probability * rent
      end
      [baseline, board_payment(state, 100) + (exposure * 2).ceil].max
    end

    def monopoly_expected_rent(state, square, owner)
      return 0 if state[:options]["no_rent_in_jail"] && state[:jail][owner].to_i > 0
      # The last roll is not the next visitor's utility rent multiplier.
      forecast = square[:type] == :utility ? state.merge(last_roll: 7) : state
      rent_for(forecast, square, owner).to_i
    end

    def monopoly_landing_probabilities(state)
      key = [state[:positions], state[:jail], state[:bankrupt], state[:board].length].inspect
      return @monopoly_landings if @monopoly_landing_key == key
      @monopoly_landing_key = key
      @monopoly_landings = state[:players].to_h do |player|
        distribution = Hash.new(0.0)
        unless state[:bankrupt][player]
          1.upto(6) do |first|
            1.upto(6) do |second|
              next if state[:jail][player].to_i > 1 && first != second
              index = (state[:positions][player] + first + second) % state[:board].length
              distribution[index] += 1.0 / 36
            end
          end
        end
        [player, distribution]
      end
    end

    def monopoly_expected_visits(state, index, owner)
      monopoly_landing_probabilities(state).sum do |player, probabilities|
        !same_user?(player, owner) && !state[:bankrupt][player] ? probabilities.fetch(index, 0.0) + 2.0 / state[:board].length : 0.0
      end
    end

    def monopoly_trade_safe?(state, player)
      offer = state[:trade_offer]
      return false unless offer && trade_gain(state, offer, player) >= 0
      cash = state[:cash][player] + offer[:give_cash] - offer[:receive_cash]
      after = state.merge(owners: state[:owners].dup)
      offer_properties(offer, :give).each { |index| after[:owners][index] = player }
      offer_properties(offer, :receive).each { |index| after[:owners][index] = offer[:from] }
      return false if cash < monopoly_cash_reserve(after, player)
      own_gain = trade_gain(state, offer, player)
      rival_gain = trade_gain(state, offer, offer[:from])
      own_gain + board_payment(state, 100) >= rival_gain * 0.5
    end

    def trade_property_value(state, index, player)
      square = state[:board][index]
      value = square[:price].to_i
      if square[:type] == :property
        group = colour_group_squares(state, square[:group])
        others = group.reject { |property| property[:index] == index }
        owned = others.count { |property| same_user?(state[:owners][property[:index]], player) }
        # Even a solitary deed retains an option to build a group. Its face
        # price is not its liquidation value in a negotiated player trade.
        value += square[:price].to_i / 3
        value += owned * square[:price] / 2
        value += square[:price] if owned == others.length
        rivals = others.filter_map do |property|
          owner = state[:owners][property[:index]]
          owner if owner != nil && !same_user?(owner, player)
        end
        largest_rival_group = rivals.group_by { |owner| owner.to_s.downcase }.values.map(&:length).max.to_i
        if !others.empty? && largest_rival_group == others.length
          # This is the last block against an opponent's monopoly, not a
          # generic markup. Re-evaluating after the offer also credits the
          # specific buyer's newly completed group in trade_gain.
          value += group.sum { |property| property[:price].to_i } / 2
        end
      elsif square[:type] == :railroad
        value += square[:price].to_i / 4
        value += owned_squares(state, player).count { |property| property[:type] == :railroad && property[:index] != index } * money(state, 50)
      elsif square[:type] == :utility
        value += square[:price].to_i / 4
        value += square[:price].to_i / 2 if owned_squares(state, player).any? { |property| property[:type] == :utility && property[:index] != index }
      end
      value
    end

    def trade_gain(state, offer, player)
      incoming, outgoing = same_user?(offer[:from], player) ? [:receive, :give] : [:give, :receive]
      after = state.merge(owners: state[:owners].dup)
      offer_properties(offer, :give).each { |index| after[:owners][index] = offer[:target] }
      offer_properties(offer, :receive).each { |index| after[:owners][index] = offer[:from] }
      offer["#{incoming}_cash".to_sym] - offer["#{outgoing}_cash".to_sym] +
        owned_squares(after, player).sum { |s| trade_property_value(after, s[:index], player) } -
        owned_squares(state, player).sum { |s| trade_property_value(state, s[:index], player) }
    end

    def building_count_text(state, property)
      count = state[:houses][property[:index]].to_i
      count == 5 ? _("1 hotel") : count.to_s
    end

    def unmortgage_cost(property)
      # Exact integer ceiling: 100 + 10% must be 110, not Float's 111.
      (property[:mortgage].to_i * 11 + 9) / 10
    end

    def property_action_shortcuts(actions, state, viewer)
      definitions = {
        "build" => ["h", [], _("build a house"), _("Choose a property to build on")],
        "sell" => ["h", [:shift], _("sell a building"), _("Choose a property to sell a building from")],
        "mortgage" => ["k", [], _("mortgage a property"), _("Choose a property to mortgage")],
        "unmortgage" => ["k", [:shift], _("unmortgage a property"), _("Choose a property to unmortgage")]
      }
      definitions.map do |action_name, (key, modifiers, label, prompt)|
        available = actions.select { |action| action["action"] == action_name }
        if available.empty?
          message = if !same_user?(state[:current_player], viewer)
            _("It is not your turn.")
          elsif ![:awaiting_roll, :turn_complete].include?(state[:phase])
            _("Complete the current decision before managing property.")
          else
            { "build" => _("You cannot build now. You need a complete unmortgaged colour group, enough cash and an available building."),
              "sell" => _("You have no buildings available to sell now."),
              "mortgage" => _("You have no properties available to mortgage now."),
              "unmortgage" => _("You cannot unmortgage now. You need a mortgaged property and enough cash.") }.fetch(action_name)
          end
          next GameShortcut.new(key: key, modifiers: modifiers, label: label, kind: :announcement, message: message)
        end

        GameShortcut.new(
          key: key, modifiers: modifiers, label: label, kind: :surface,
          action_kind: "surface", action_name: "open_menu", payload: { "menu" => action_name, "focus_surface" => true }
        )
      end
    end

    def clear_manual_rent(state)
      state[:rent_payer] = nil
      state[:rent_owner] = nil
      state[:rent_amount] = 0
      state[:rent_origin] = nil
    end

    def positions_text(state)
      state[:players].map do |player|
        square = current_square(state, player)
        _("%{player}: field %{number}, %{square}") % {
          player: participant_name(player), number: square[:index], square: square[:name]
        }
      end.join("; ")
    end

    def finances_text(state)
      worth = state[:players].to_h { |player| [player, net_worth(state, player)] }
      score_announcement_order(state[:players], worth, eliminated: state[:bankrupt]).map { |player| _("%{player}: cash %{cash}, net worth %{value}") % { player: participant_name(player), cash: state[:cash][player], value: worth[player] } }.join("; ")
    end

    def deed_text(state, square)
      return _("This square has no deed.") if ![:property, :railroad, :utility].include?(square[:type])
      owner = state[:owners][square[:index]]
      buildings = square[:type] == :property ? _("; buildings: %{buildings}") % { buildings: building_count_text(state, square) } : ""
      _("%{name}; %{group}; price %{price}; owner %{owner}%{buildings}; %{mortgage}.") % {
        name: square[:name], group: property_group_label(square), price: square[:price], owner: owner == nil ? _("none") : participant_name(owner),
        buildings: buildings, mortgage: state[:mortgaged][square[:index]] ? _("mortgaged") : _("not mortgaged")
      }
    end

    def waiting_text(state)
      template = case state[:phase]
      when :property_decision then _("Waiting for %{player} to decide whether to buy.")
      when :rent_decision then _("Waiting for %{player} to collect or waive rent.")
      when :trade_response then _("Waiting for %{player} to accept or reject the trade.")
      when :auction then _("Waiting for %{player} to bid or pass.")
      else _("Waiting for %{player} to roll.")
      end
      template % { player: participant_name(state[:current_player]) }
    end

    def property_name_and_group(square)
      _("%{property}, %{group}") % { property: square[:name], group: property_group_label(square) }
    end

    def completed_colour_groups(state)
      state[:board].select { |square| square[:type] == :property }.group_by { |square| square[:group] }.filter_map do |group, squares|
        owner = state[:owners][squares.first[:index]]
        [owner, group] if owner && squares.all? { |square| same_user?(state[:owners][square[:index]], owner) }
      end
    end

    def announce_completed_groups(state, previous, event_id, history)
      (completed_colour_groups(state) - previous).each do |owner, group|
        square = state[:board].find { |item| item[:type] == :property && item[:group] == group }
        history << HistoryEntry.new(key: "group_complete:#{event_id}:#{owner}:#{group}",
          text: _("%{player} completed the %{group}.") % { player: participant_name(owner), group: property_group_label(square) },
          event_id: event_id, actor: owner, kind: :game)
      end
    end

    def property_group_label(square)
      return _("railroad") if square[:type] == :railroad
      return _("utility") if square[:type] == :utility

      {
        "brown" => _("brown group"),
        "light_blue" => _("light blue group"),
        "azure" => _("light blue group"),
        "pink" => _("pink group"),
        "purple" => _("purple group"),
        "orange" => _("orange group"),
        "red" => _("red group"),
        "yellow" => _("yellow group"),
        "green" => _("green group"),
        "dark_blue" => _("dark blue group"),
        "blue" => _("dark blue group"),
        "white" => _("white group"),
        "gray" => _("gray group"),
        "magenta" => _("magenta group")
      }.fetch(square[:group].to_s, square[:group].to_s)
    end

    def property_choices(state, group_progress: false)
      choices = state[:board].select { |square| [:property, :railroad, :utility].include?(square[:type]) && yield(square) }.map do |square|
        text = deed_text(state, square)
        if group_progress && square[:type] == :property
          owner = state[:owners][square[:index]]
          group = colour_group_squares(state, square[:group])
          owned = group.count { |member| same_user?(state[:owners][member[:index]], owner) }
          text = _("%{property}; group %{owned} of %{total}.") % {
            property: text.sub(/\.\z/, ""), owned: owned, total: group.length
          }
        end
        details = group_progress ? [ShortcutChoice.new(value: "rent", label: property_rent_text(state, square))] : square[:index]
        ShortcutChoice.new(value: details, label: text)
      end
      choices.empty? ? [ShortcutChoice.new(value: nil, label: _('No matching property.'))] : choices
    end

    def board_choices(state)
      state[:board].map do |square|
        name = [:property, :railroad, :utility].include?(square[:type]) ? property_name_and_group(square) : square[:name]
        ShortcutChoice.new(value: square[:index], label: _("%{number}. %{name}") % { number: square[:index], name: name })
      end
    end

    def property_rent_text(state, square)
      owner = state[:owners][square[:index]]
      return _("No rent: this property has no owner.") if owner == nil
      return _("No rent: this property is mortgaged.") if state[:mortgaged][square[:index]]
      if state[:options]["no_rent_in_jail"] && state[:jail][owner].to_i > 0
        return _("No rent: %{owner} is in jail.") % { owner: participant_name(owner) }
      end
      if square[:type] == :utility
        # Show the formula for a future visit, not the last player's roll.
        multiplier = rent_for(state.merge(last_roll: 1), square, owner)
        return _("Visitors pay %{multiplier} times their dice total to %{owner}.") % {
          multiplier: multiplier, owner: participant_name(owner)
        }
      end
      _("Visitors pay %{amount} to %{owner}.") % { amount: rent_for(state, square, owner), owner: participant_name(owner) }
    end
  end
end
