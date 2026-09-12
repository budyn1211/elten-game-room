def _(text)
  text
end

def n_(singular, plural, count)
  count.to_i == 1 ? singular : plural
end

module GameSurfaces
  Action = Struct.new(:kind, :name, :payload, :source, keyword_init: true)
  CardChoice = Struct.new(:id, :label, :value, keyword_init: true)
  Card = Struct.new(:id, :label, :value, :choices, :shift_choice, :choice_header, :sort_keys, keyword_init: true)
  CardZoneSpec = Struct.new(:id, :header, :cards, :empty_label, :hand_order, :hand_epoch, keyword_init: true)
  CardTableSpec = Struct.new(:zones, keyword_init: true)
  Command = Struct.new(:id, :label, :enabled, :payload, keyword_init: true)
  CommandPanelSpec = Struct.new(:commands, keyword_init: true)
  PawnTrackItem = Struct.new(:id, :label, :action, keyword_init: true)
  PawnTrackSpec = Struct.new(:id, :header, :items, :empty_label, :activation_action, :menus, keyword_init: true)
  Die = Struct.new(:id, :value, :sides, :held, :label, :enabled, keyword_init: true)
  ScoreChoice = Struct.new(:id, :label, :value, keyword_init: true)
  RollAndScoreSpec = Struct.new(:id, :header, :dice, :categories, :can_roll, :force_categories, :empty_label, :roll_number, keyword_init: true)
  PacketCardSpec = Struct.new(:id, :header, :cards, :action_name, :allow_packet, :empty_label, :hand_order, :hand_epoch, keyword_init: true)
  SurfacePart = Struct.new(:id, :surface, keyword_init: true)
  CompositeSpec = Struct.new(:parts, keyword_init: true)
end

require "json"
require_relative "../lib/game_random"
require_relative "../games/base"
require_relative "../games/card_game"
require_relative "../games/categories" unless ENV["GAME_ROOM_FIVE_GAMES_ONLY"] == "1"
require_relative "../content/monopoly_boards"
require_relative "../games/monopoly"
require_relative "../games/yahtzee"
require_relative "../games/uno"
require_relative "../games/poker"
require_relative "../games/makao"

class NewGames116Repository
  def initialize(players)
    @players = players
  end

  def players_for(_session)
    @players
  end

  def actor_of(event, _session = nil)
    event.fetch("actor")
  end

  def event_id(event)
    event.fetch("id")
  end
end

class NewGames116Random
  Roll = Struct.new(:values, keyword_init: true)

  def initialize
    @value = 0
  end

  def roll(count:, sides:)
    values = Array.new(count) do
      @value += 1
      ((@value - 1) % sides.to_i) + 1
    end
    Roll.new(values: values)
  end
end

def assert(condition, message)
  raise message if !condition
end

def context_for(random = NewGames116Random.new)
  GameRoomGames::ActionContext.new(random_source: random, now: 1_800_000_000)
end

def append_action(game, session, repository, events, replay, actor, selection, context = nil)
  status, plan = game.action_for(selection, replay, actor, context: context)
  raise "#{game.id} rejected #{selection.inspect}: #{status}" if status != :ok
  plan.events.each do |command|
    events << { "id" => events.length + 1, "actor" => actor, "action" => command.action, "value" => command.value }
  end
  game.replay(session, events, repository)
end

players = ["Alice", "Bob", "Carol"]
repository = NewGames116Repository.new(players)

boards = GameRoomContent::MonopolyBoards::BOARD_NAMES.keys
assert(boards.length == 19 && boards.include?("poland"), "Monopoly does not expose all agreed boards")
boards.each do |board_id|
  board = GameRoomContent::MonopolyBoards.build(board_id)
  large = %w[latin_america romania balkans indonesia southeast_asia twelve_nations].include?(board_id)
  assert(board[:squares].length == (large ? 60 : 40), "Monopoly board #{board_id} has the wrong size")
  assert(board[:squares].each_with_index.all? { |square, index| square[:index] == index }, "Monopoly board indices are unstable")
  property_names = board[:squares].select { |square| square[:type] == :property }.map { |square| square[:name] }
  assert(property_names.length == (large ? 34 : 22) && property_names.uniq.length == property_names.length,
    "Monopoly board #{board_id} has missing or repeated property names")
  assert(property_names.none? { |name| name.match?(/property \d+\z/i) },
    "Monopoly board #{board_id} still contains placeholder property names")
end

categories_game = GameRoomGames::Categories.new if defined?(GameRoomGames::Categories)
if categories_game != nil
  custom_categories = categories_game.option_definitions.find { |definition| definition.key == "custom_categories" }
  assert(!categories_game.option_visible?(custom_categories, categories_game.default_options),
    "custom Categories options are visible for a built-in pool")
  assert(categories_game.option_visible?(custom_categories, categories_game.default_options.merge("category_set" => "custom")),
    "custom Categories options stay hidden for the custom pool")
end

monopoly = GameRoomGames::Monopoly.new
monopoly_session = { "options" => JSON.generate(monopoly.default_options) }
monopoly_events = []
monopoly_replay = monopoly.replay(monopoly_session, monopoly_events, repository)
assert(monopoly.legal_actions(monopoly_replay, "Alice").any? { |action| action["action"] == "roll" }, "Monopoly does not begin with Roll")
monopoly_replay = append_action(monopoly, monopoly_session, repository, monopoly_events, monopoly_replay,
  "Alice", { "kind" => "command", "action" => "roll" }, context_for)
assert(monopoly_events.first["value"].split(",").length == 3, "Monopoly roll does not contain deterministic dice and card values")
assert(monopoly_replay.state[:positions]["Alice"] > 0, "Monopoly did not move the first player")
assert(monopoly.maximum_players == 8 && monopoly.supports_bots?, "Monopoly multiplayer or bots are missing")
assert(monopoly.default_options.values_at("free_parking_jackpot", "double_salary_on_start", "supplementary_cards", "automatic_rent") == [true, true, true, true],
  "Monopoly agreed enabled defaults changed")
assert(monopoly.default_options.values_at("forbid_first_round_purchase", "no_rent_in_jail", "lucky_double_one", "auction_unsold") == [false, false, false, false],
  "Monopoly agreed disabled defaults changed")

automatic_turn = monopoly.replay(monopoly_session, [
  { "id" => 1, "actor" => "Alice", "action" => "roll", "value" => "1,3,1" }
], repository)
assert(automatic_turn.state[:phase] == :awaiting_roll && automatic_turn.current_player == "Bob",
  "Monopoly did not advance automatically after resolving a square")
assert(monopoly.legal_actions(automatic_turn, "Bob").none? { |action| action["action"] == "end_turn" },
  "Monopoly still exposes End turn")

purchase_state = monopoly.send(:initial_state, players, monopoly.default_options)
purchase_state[:positions]["Alice"] = 1
purchase_state[:phase] = :property_decision
purchase_label = monopoly.send(:action_label, { "action" => "buy" }, purchase_state, "Alice")
assert(purchase_label == "Buy", "Monopoly purchase action is not concise")
purchase_history = []
monopoly.send(:resolve_square, purchase_state, "Alice", nil, 99, purchase_history)
assert(purchase_history.last.text.include?("pink group"), "Monopoly does not announce the QC property's color before purchase")

manual_state = monopoly.send(:initial_state, players, monopoly.normalize_options("automatic_rent" => false))
manual_state[:positions]["Alice"] = 39
manual_state[:owners][1] = "Bob"
manual_history = []
manual_roll = { "id" => 1, "actor" => "Alice", "action" => "roll", "value" => "1,1,1" }
assert(monopoly.send(:apply_roll, manual_state, manual_roll, "Alice", repository, manual_history), "Manual-rent setup roll failed")
assert(manual_state[:phase] == :rent_decision && manual_state[:current_player] == "Bob", "Manual rent was not offered to the owner")
manual_rent = { "id" => 2, "actor" => "Bob", "action" => "request_rent", "value" => "" }
alice_cash = manual_state[:cash]["Alice"]
bob_cash = manual_state[:cash]["Bob"]
assert(monopoly.send(:apply_manual_rent, manual_state, manual_rent, "Bob", repository, manual_history), "Manual rent request failed")
assert(manual_state[:cash]["Alice"] < alice_cash && manual_state[:cash]["Bob"] > bob_cash, "Manual rent did not transfer money")
assert(manual_state[:phase] == :turn_complete && manual_state[:current_player] == "Alice", "Manual rent did not return the turn to the payer")

trade_state = monopoly.send(:initial_state, players, monopoly.default_options)
trade_state[:phase] = :turn_complete
trade_state[:owners][1] = "Alice"
trade_replay = GameRoomGames::Replay.new(players: players, current_player: "Alice", winner: nil,
  draw: false, accepted_events: [], history: [], state: trade_state)
offer = monopoly.legal_actions(trade_replay, "Alice").find do |action|
  action["action"] == "trade_offer" && action["offer"].start_with?("1|1|-1|")
end
assert(offer != nil, "Monopoly did not create a property sale proposal")
trade_history = []
offer_event = { "id" => 3, "actor" => "Alice", "action" => "trade_offer", "value" => offer["offer"] }
assert(monopoly.send(:apply_trade, trade_state, offer_event, "Alice", repository, trade_history), "Monopoly rejected a valid trade proposal")
accept_event = { "id" => 4, "actor" => "Bob", "action" => "trade_accept", "value" => "" }
assert(monopoly.send(:apply_trade, trade_state, accept_event, "Bob", repository, trade_history), "Monopoly rejected an accepted trade")
assert(trade_state[:owners][1] == "Bob" && trade_state[:current_player] == "Alice", "Monopoly did not transfer the property and restore the turn")
assert(offer["offer"].length <= 64, "Monopoly trade event exceeds the transport limit")

debt_state = monopoly.send(:initial_state, players, monopoly.default_options)
debt_state[:cash]["Alice"] = -25
debt_replay = GameRoomGames::Replay.new(players: players, current_player: "Alice", winner: nil,
  draw: false, accepted_events: [], history: [], state: debt_state)
debt_surface = monopoly.surface_spec(debt_replay, "Alice")
assert(debt_surface.items.length == 1 && debt_surface.items.first.action.name == "roll",
  "Monopoly debt interface exposes decisions other than the agreed Roll entry")

jackpot_state = monopoly.send(:initial_state, players, monopoly.default_options)
monopoly.send(:transfer_to_bank, jackpot_state, "Alice", 75)
assert(jackpot_state[:cash]["Alice"] == 1_425 && jackpot_state[:jackpot] == 75,
  "Monopoly did not add a bank fine to the Free Parking jackpot")
jackpot_state[:positions]["Alice"] = 20
monopoly.send(:resolve_square, jackpot_state, "Alice", 1, 30, [])
assert(jackpot_state[:cash]["Alice"] == 1_500 && jackpot_state[:jackpot].zero?,
  "Monopoly did not pay and clear the Free Parking jackpot")

utility_state = monopoly.send(:initial_state, players, monopoly.default_options)
utility_state[:last_roll] = 8
utility_state[:owners][12] = "Alice"
assert(monopoly.send(:rent_for, utility_state, utility_state[:board][12], "Alice") == 32,
  "Monopoly one-utility rent does not use four times the dice roll")
utility_state[:owners][28] = "Alice"
assert(monopoly.send(:rent_for, utility_state, utility_state[:board][12], "Alice") == 80,
  "Monopoly two-utility rent does not use ten times the dice roll")

building_state = monopoly.send(:initial_state, players, monopoly.default_options)
building_state[:owners][1] = building_state[:owners][3] = "Alice"
building_state[:houses][1] = 1
building_state[:houses][3] = 0
assert(!monopoly.send(:can_build?, building_state, "Alice", building_state[:board][1]) &&
  monopoly.send(:can_build?, building_state, "Alice", building_state[:board][3]),
  "Monopoly permits building unevenly across a colour group")
assert(monopoly.send(:can_sell_building?, building_state, "Alice", building_state[:board][1]) &&
  !monopoly.send(:can_sell_building?, building_state, "Alice", building_state[:board][3]),
  "Monopoly permits selling buildings unevenly across a colour group")
assert(!monopoly.send(:can_mortgage?, building_state, "Alice", building_state[:board][3]),
  "Monopoly permits mortgaging a colour-group property while the group has a building")

standard_cards_state = monopoly.send(:initial_state, players,
  monopoly.normalize_options("supplementary_cards" => false))
supplementary_cards_state = monopoly.send(:initial_state, players,
  monopoly.normalize_options("supplementary_cards" => true))
monopoly.send(:initialize_card_decks, standard_cards_state, "standard")
monopoly.send(:initialize_card_decks, supplementary_cards_state, "standard")
assert(standard_cards_state[:card_decks].values.all? { |deck| deck.length == 16 } &&
  supplementary_cards_state[:card_decks].values.all? { |deck| deck.length == 18 },
  "Monopoly supplementary card option does not select the expanded card set")

yahtzee = GameRoomGames::Yahtzee.new
yahtzee_session = { "options" => JSON.generate(yahtzee.default_options) }
yahtzee_events = []
yahtzee_replay = yahtzee.replay(yahtzee_session, yahtzee_events, repository)
roll = yahtzee.legal_actions(yahtzee_replay, "Alice").first
yahtzee_replay = append_action(yahtzee, yahtzee_session, repository, yahtzee_events, yahtzee_replay, "Alice", roll, context_for)
assert(yahtzee_replay.state[:dice] == yahtzee_replay.state[:dice].sort, "Yahtzee dice are not sorted")
assert(yahtzee_replay.state[:turn_rolls] == 1, "Yahtzee did not count the first roll")
yahtzee_surface = yahtzee.surface_spec(yahtzee_replay, "Alice")
assert(yahtzee_surface.header == yahtzee.name && yahtzee_surface.roll_number == 1,
  "Yahtzee does not expose the stable one-field roll surface")
shortcut_signatures = yahtzee.custom_game_shortcuts(yahtzee_replay, "Alice").map do |shortcut|
  [shortcut.key, shortcut.modifiers]
end
1.upto(6) do |value|
  assert(shortcut_signatures.include?([value.to_s, []]) && shortcut_signatures.include?([value.to_s, [:shift]]),
    "Yahtzee is missing die-value shortcut #{value}")
end
assert(shortcut_signatures.include?(["space", []]), "Yahtzee is missing the dice status shortcut")
assert(yahtzee.custom_game_shortcuts(yahtzee_replay, "Alice").all? do |shortcut|
  !shortcut.payload.key?("number")
end, "Yahtzee shortcuts still select dice by position")
score = yahtzee.legal_actions(yahtzee_replay, "Alice").find { |action| action["action"] == "score" }
yahtzee_replay = append_action(yahtzee, yahtzee_session, repository, yahtzee_events, yahtzee_replay, "Alice", score)
assert(yahtzee_replay.current_player == "Bob", "Yahtzee did not advance after scoring")
assert(yahtzee.default_options["yahtzee_bonus"] && yahtzee.default_options["joker_rule"], "Yahtzee bonus and Joker are not independent enabled defaults")

joker_state = yahtzee.send(:initial_state, players,
  yahtzee.normalize_options("yahtzee_bonus" => false, "joker_rule" => true))
joker_state[:dice] = [6, 6, 6, 6, 6]
joker_state[:turn_rolls] = 2
joker_state[:sheets]["Alice"]["yahtzee"] = 50
assert(yahtzee.send(:available_scoring_categories, joker_state, "Alice") == ["sixes"],
  "Yahtzee Joker did not require the matching open upper category")
joker_state[:sheets]["Alice"]["sixes"] = 30
joker_lower = yahtzee.send(:available_scoring_categories, joker_state, "Alice")
assert(joker_lower.include?("full_house") && !joker_lower.include?("ones"),
  "Yahtzee Joker did not move to the lower section after the matching upper category was filled")
assert(yahtzee.send(:score_category, "large_straight", joker_state[:dice], joker_state, "Alice") == 40,
  "Yahtzee Joker did not provide the fixed large-straight score")
joker_history = []
assert(yahtzee.send(:apply_score, joker_state,
  { "id" => 25, "actor" => "Alice", "action" => "score", "value" => "large_straight" },
  "Alice", repository, joker_history), "Yahtzee rejected a legal Joker category")
assert(joker_state[:yahtzee_bonuses]["Alice"].zero?,
  "Yahtzee awarded an additional bonus although that independent option was disabled")

bonus_state = yahtzee.send(:initial_state, players,
  yahtzee.normalize_options("yahtzee_bonus" => true, "joker_rule" => false))
bonus_state[:dice] = [2, 2, 2, 2, 2]
bonus_state[:turn_rolls] = 2
bonus_state[:sheets]["Alice"]["yahtzee"] = 50
bonus_history = []
assert(yahtzee.send(:apply_score, bonus_state,
  { "id" => 26, "actor" => "Alice", "action" => "score", "value" => "chance" },
  "Alice", repository, bonus_history), "Yahtzee rejected a category with Joker disabled")
assert(bonus_state[:yahtzee_bonuses]["Alice"] == 100,
  "Yahtzee did not award the independently enabled additional-Yahtzee bonus")

uno = GameRoomGames::Uno.new
uno_session = { "options" => JSON.generate(uno.default_options) }
uno_events = []
uno_replay = uno.replay(uno_session, uno_events, repository)
deal_action = uno.automatic_action(uno_replay, "Alice")
uno_replay = append_action(uno, uno_session, repository, uno_events, uno_replay, "Alice", deal_action, context_for)
assert(uno_replay.state[:hands].values.all? { |hand| hand.length == 7 }, "UNO did not deal seven cards")
assert(uno_replay.state[:discard].length == 1, "UNO has no first discard")
uno_shortcuts = uno.custom_game_shortcuts(uno_replay, "Alice")
assert(["c", "h", "d"].all? do |key|
  uno_shortcuts.any? { |shortcut| shortcut.key == key && shortcut.modifiers == [:shift] && shortcut.kind == :surface }
end, "UNO is missing the agreed local card-sorting shortcuts")
assert(uno_shortcuts.find { |shortcut| shortcut.key == "c" && shortcut.modifiers.empty? }.message !~ /Top card:/,
  "UNO still adds the redundant top-card prefix")
uno_actor = uno_replay.current_player
uno_move = uno.legal_actions(uno_replay, uno_actor).find { |action| action["action"] == "play" } ||
  uno.legal_actions(uno_replay, uno_actor).find { |action| action["action"] == "draw" }
uno_replay = append_action(uno, uno_session, repository, uno_events, uno_replay, uno_actor, uno_move)
assert(uno_replay.accepted_events.length == 2, "UNO rejected its first legal action")
assert(!uno_replay.history.last.text.match?(/[RYGB][0-9SVDF][ab0-9]/), "UNO exposed an internal card id")
assert(uno.default_options["draw_responses"] && uno.default_options["allow_optional_draw"], "UNO agreed draw defaults are missing")
assert(uno.default_options["maximum_optional_draws"] == 3, "UNO optional draw limit is not three")
uno_definitions = uno.option_definitions.to_h { |definition| [definition.key, definition] }
assert(!uno.option_visible?(uno_definitions["super_interceptions"], uno.default_options),
  "UNO shows super interceptions while interceptions are disabled")
assert(!uno.option_visible?(uno_definitions["maximum_optional_draws"], uno.default_options.merge("allow_optional_draw" => false)),
  "UNO shows the optional draw limit while optional drawing is disabled")
assert(uno.validation_error(uno.default_options.merge("allow_optional_draw" => false, "maximum_optional_draws" => 0), player_count: 3) == nil,
  "UNO validates a hidden optional draw limit")

uno_draw_state = uno.send(:initial_state, players, uno.default_options)
uno_draw_state.update(
  phase: :playing, current_player: "Alice", colour: "R", discard: ["R5a"],
  draw_pile: ["B2a"], hands: { "Alice" => ["G7a"], "Bob" => ["R1a"], "Carol" => ["Y1a"] }
)
uno_draw_history = []
assert(uno.send(:apply_draw, uno_draw_state,
  { "id" => 20, "actor" => "Alice", "action" => "draw", "value" => "" },
  "Alice", repository, uno_draw_history), "UNO rejected a normal voluntary draw")
assert(uno_draw_state[:current_player] == "Bob" && uno_draw_state[:optional_draws].zero?,
  "UNO did not end the turn after drawing with no playable card in hand")

assert(!uno.default_options["bluff_challenge"], "UNO bluff challenge is not an optional, disabled-by-default rule")
mercy_options = uno.normalize_options("deck" => "no_mercy", "advanced_responses" => true)
penalty_state = uno.send(:initial_state, players, mercy_options)
penalty_state.update(phase: :playing, current_player: "Alice", colour: "R", discard: ["RXa"],
  pending_draw: 4, pending_type: "X", pending_family: "coloured_draw",
  hands: { "Alice" => %w[GXa NF0 YSa GAa], "Bob" => ["R1a"], "Carol" => ["Y1a"] })
assert(uno.send(:playable?, penalty_state, "GXa"), "UNO No Mercy rejected an equal coloured draw response")
assert(!uno.send(:playable?, penalty_state, "NF0"), "UNO No Mercy mixed a wild and coloured draw chain")
assert(uno.send(:playable?, penalty_state, "YSa"), "UNO advanced responses rejected Skip")
skip_response_state = Marshal.load(Marshal.dump(penalty_state))
skip_response_history = []
assert(uno.send(:apply_play, skip_response_state,
  { "id" => 21, "actor" => "Alice", "action" => "play", "value" => "YSa||0" },
  "Alice", repository, skip_response_history), "UNO rejected Skip as an advanced response")
assert(skip_response_state[:pending_draw] == 4 && skip_response_state[:current_player] == "Bob",
  "UNO Skip did not pass the draw obligation to exactly the next player")

cancel_response_state = Marshal.load(Marshal.dump(penalty_state))
cancel_response_history = []
assert(uno.send(:apply_play, cancel_response_state,
  { "id" => 22, "actor" => "Alice", "action" => "play", "value" => "GAa||0" },
  "Alice", repository, cancel_response_history), "UNO rejected Discard All as an advanced response")
assert(cancel_response_state[:pending_draw].zero? && cancel_response_state[:pending_family] == nil,
  "UNO Discard All did not cancel the No Mercy draw chain")

seven_options = uno.normalize_options("zero_seven" => true)
seven_state = uno.send(:initial_state, players, seven_options)
seven_state.update(phase: :playing, current_player: "Alice", colour: "R", discard: ["R5a"],
  hands: { "Alice" => %w[R7a R9a], "Bob" => ["B1a"], "Carol" => ["G2a"] })
seven_replay = GameRoomGames::Replay.new(players: players, current_player: "Alice", winner: nil,
  draw: false, accepted_events: [], history: [], state: seven_state)
seven_actions = uno.legal_actions(seven_replay, "Alice").select { |action| action["card"] == "R7a" }
assert(seven_actions.map { |action| action["choice"] }.sort == %w[p1 p2],
  "UNO seven does not offer every other active player as a hand-swap target")
seven_history = []
assert(uno.send(:apply_play, seven_state,
  { "id" => 23, "actor" => "Alice", "action" => "play", "value" => "R7a|p2|0" },
  "Alice", repository, seven_history), "UNO rejected the selected seven target")
assert(seven_state[:hands]["Alice"] == ["G2a"] && seven_state[:hands]["Carol"] == ["R9a"],
  "UNO seven swapped with a different player than the selected target")

mercy_state = uno.send(:initial_state, players, mercy_options.merge("no_mercy_limit" => 3))
mercy_state.update(phase: :playing, current_player: "Alice",
  hands: { "Alice" => %w[R1a R2a R3a], "Bob" => ["B1a"], "Carol" => ["G1a"] })
mercy_history = []
uno.send(:apply_no_mercy, mercy_state, "Alice", 24, mercy_history)
assert(mercy_state[:round_eliminated]["Alice"] && !mercy_state[:eliminated]["Alice"],
  "UNO No Mercy removed a player from the whole match instead of only the current round")
assert(mercy_state[:scores]["Alice"] == 250,
  "UNO No Mercy did not apply the round-elimination penalty")
assert(uno.send(:next_game_active_index, mercy_state, 2, 1) == 0,
  "UNO No Mercy did not return a round-eliminated player to the next dealer rotation")

makao = GameRoomGames::Makao.new
assert(makao.supports_bots?, "Makao has no bot")
assert(makao.default_options["profile"] == "simple" && !makao.default_options["jokers"], "Makao does not default to the simple profile")
makao_definitions = makao.option_definitions.to_h { |definition| [definition.key, definition] }
assert(!makao.option_visible?(makao_definitions["jokers"], makao.default_options),
  "Makao shows custom rule switches for a ready-made profile")
assert(makao.option_visible?(makao_definitions["jokers"], makao.default_options.merge("profile" => "custom")),
  "Makao hides custom rule switches for the custom profile")
assert(!makao.option_visible?(makao_definitions["hand_size"], makao.default_options.merge("profile" => "joker")),
  "Makao shows the fixed hand size in the joker profile")
joker_options = makao.normalize_options("profile" => "joker")
assert(joker_options["jokers"] && joker_options["hand_size"] == 5, "The agreed joker profile is incomplete")
universal_joker_choices = makao.send(:card_choices_for,
  makao.send(:initial_state, players, joker_options), "X0")
assert(universal_joker_choices.length == 52 && universal_joker_choices.include?("2C") &&
  universal_joker_choices.include?("QD") && universal_joker_choices.include?("AS"),
  "Makao joker cannot represent every ordinary card")
makao_session = { "options" => JSON.generate(joker_options) }
makao_events = []
makao_replay = makao.replay(makao_session, makao_events, repository)
makao_replay = append_action(makao, makao_session, repository, makao_events, makao_replay, "Alice",
  makao.automatic_action(makao_replay, "Alice"), context_for)
assert(makao_replay.state[:hands].values.all? { |hand| hand.length == 5 }, "Makao did not deal five cards")
makao_actor = makao_replay.current_player
makao_move = makao.legal_actions(makao_replay, makao_actor).find { |action| action["action"] == "play" } ||
  makao.legal_actions(makao_replay, makao_actor).find { |action| action["action"] == "draw" }
makao_replay = append_action(makao, makao_session, repository, makao_events, makao_replay, makao_actor, makao_move)
assert(makao_replay.accepted_events.length == 2, "Makao rejected its first legal action")

skip_state = makao.send(:initial_state, players, makao.normalize_options("profile" => "joker"))
skip_state.update(phase: :playing, current_player: "Alice", hands: {
  "Alice" => %w[4C 4D 9S], "Bob" => %w[5D 6D], "Carol" => %w[7H 8H]
}, discard: ["5C"], declared_suit: "C")
skip_history = []
fours = { "id" => 1, "actor" => "Alice", "action" => "play", "value" => "4C,4D|" }
assert(makao.send(:apply_play, skip_state, fours, "Alice", repository, skip_history), "Makao did not accept a packet of fours")
assert(skip_state[:skip_penalty] == 2 && skip_state[:current_player] == "Bob", "Makao did not offer the accumulated fours to the next player")
accept_skip = { "id" => 2, "actor" => "Bob", "action" => "accept_skip", "value" => "" }
assert(makao.send(:apply_accept_skip, skip_state, accept_skip, "Bob", repository, skip_history), "Makao did not accept the waiting penalty")
assert(skip_state[:current_player] == "Carol" && skip_state[:skip_turns]["Bob"] == 1, "Makao did not preserve the remaining waiting turn")
assert(makao.send(:advance_player, skip_state, "Carol", 1) == "Alice", "Makao did not skip the penalized player on the next circuit")

joker_packet_state = makao.send(:initial_state, players, joker_options)
joker_packet_state.update(phase: :playing, current_player: "Alice", declared_suit: "C", discard: ["7C"],
  hands: { "Alice" => %w[X0 7D 9S], "Bob" => %w[5D 6D], "Carol" => %w[7H 8H] })
joker_packet_history = []
assert(makao.send(:apply_play, joker_packet_state,
  { "id" => 27, "actor" => "Alice", "action" => "play", "value" => "X0,7D|" },
  "Alice", repository, joker_packet_history), "Makao rejected a joker inferred as the packet's ordinary rank")
assert(joker_packet_state[:declared_suit] == "D",
  "Makao did not preserve the effective suit of a packet containing a joker")

king_state = makao.send(:initial_state, players, joker_options)
king_state.update(phase: :playing, current_player: "Bob", declared_suit: "S", discard: ["KS"],
  draw_penalty: 5, penalty_kind: "K",
  hands: { "Alice" => ["9S"], "Bob" => %w[KH 8D], "Carol" => ["7H"] })
king_history = []
assert(makao.send(:apply_play, king_state,
  { "id" => 28, "actor" => "Bob", "action" => "play", "value" => "KH|" },
  "Bob", repository, king_history), "Makao rejected the defensive king of hearts")
assert(king_state[:draw_penalty] == 10 && king_state[:current_player] == "Carol",
  "Makao defensive king did not pass an accumulated ten-card penalty")

packet_order_state = makao.send(:initial_state, players, makao.normalize_options("profile" => "simple"))
packet_order_state.update(phase: :playing, current_player: "Alice", declared_suit: "C", discard: ["5C"],
  hands: { "Alice" => %w[7D 7C 9S], "Bob" => ["5D"], "Carol" => ["6H"] })
assert(makao.send(:validate_packet, packet_order_state, "Alice", %w[7D 7C], "") == :illegal_card,
  "Makao accepted a packet whose first card did not match the table")
assert(makao.send(:validate_packet, packet_order_state, "Alice", %w[7C 7D], "") == :ok,
  "Makao rejected a packet whose first card matched the table")

poker = GameRoomGames::Poker.new
poker_definitions = poker.option_definitions.to_h { |definition| [definition.key, definition] }
assert(!poker.option_visible?(poker_definitions["raise_cap"], poker.default_options),
  "Poker shows the disabled raise limit")
assert(poker.option_visible?(poker_definitions["raise_cap"], poker.default_options.merge("raise_cap_enabled" => true)),
  "Poker hides the enabled raise limit")
draw_options = poker.default_options.merge("variant" => "draw", "draw_uses_blinds" => false)
assert(poker.option_visible?(poker_definitions["ante"], draw_options) &&
  !poker.option_visible?(poker_definitions["small_blind"], draw_options),
  "Draw poker does not switch from blinds to the ante fields")
assert(poker.validation_error(draw_options.merge("small_blind" => 0), player_count: 3) == nil,
  "Poker validates a hidden blind field")
assert(poker.validation_error(draw_options.merge("ante" => 0), player_count: 3) != nil,
  "Draw poker accepts an invalid visible ante")
assert(poker.options_summary(draw_options).include?("ante 5") && !poker.options_summary(draw_options).include?("blinds"),
  "Poker draw settings describe hidden blinds instead of the ante")
poker_session = { "options" => JSON.generate(poker.default_options) }
poker_events = []
poker_replay = poker.replay(poker_session, poker_events, repository)
poker_replay = append_action(poker, poker_session, repository, poker_events, poker_replay, "Alice",
  poker.automatic_action(poker_replay, "Alice"), context_for)
assert(poker_replay.state[:hands].values.all? { |hand| hand.length == 2 }, "Hold'em did not deal two private cards")
assert(poker_replay.state[:contributions].values.sum == 15, "Hold'em did not post the default blinds")
poker_actor = poker_replay.current_player
poker_move = poker.legal_actions(poker_replay, poker_actor).find { |action| %w[check call].include?(action["action"]) }
poker_replay = append_action(poker, poker_session, repository, poker_events, poker_replay, poker_actor, poker_move)
assert(poker_replay.accepted_events.length == 2, "Poker rejected its first betting action")
assert(poker.send(:five_card_rank, %w[AS KS QS JS TS]).first == 8, "Poker evaluator missed a royal straight flush")
assert(poker.send(:five_card_rank, %w[AS AD AC AH 2S]).first == 7, "Poker evaluator missed four of a kind")
assert(poker.send(:best_combination_text, %w[2C 2D]) == "one pair: 2.",
  "Poker G does not recognize a pocket pair before the flop")

all_in_state = poker.send(:initial_state, %w[Alice Bob], poker.default_options)
all_in_state.update(
  phase: :betting, current_player: "Alice", dealer_index: 0,
  hands: { "Alice" => %w[2C 2D], "Bob" => %w[3C 4D] },
  stacks: { "Alice" => 100, "Bob" => 90 }, street: 0, current_bet: 10,
  min_raise: 10, street_bets: { "Alice" => 0, "Bob" => 10 },
  contributions: { "Alice" => 0, "Bob" => 10 }, folded: {}, all_in: {}, acted: {}
)
all_in_history = []
assert(poker.send(:apply_bet, all_in_state,
  { "id" => 99, "actor" => "Alice", "action" => "bet", "value" => "all_in|100" },
  "Alice", repository, all_in_history), "Poker rejected a legal all-in")
assert(all_in_state[:phase] == :betting && all_in_state[:current_player] == "Bob",
  "Poker ended the hand immediately instead of letting the opponent answer an all-in")

heads_up_players = %w[Alice Bob]
heads_up_repository = NewGames116Repository.new(heads_up_players)
heads_up_state = poker.send(:initial_state, heads_up_players, poker.default_options)
heads_up_history = []
assert(poker.send(:apply_deal, heads_up_state,
  { "id" => 100, "actor" => "Alice", "action" => "deal", "value" => "1|0|0123456789abcdef0123456789abcdef|1800000000" },
  "Alice", heads_up_repository, heads_up_history), "Heads-up Hold'em deal failed")
assert(heads_up_state[:street_bets]["Alice"] == 5 && heads_up_state[:street_bets]["Bob"] == 10 &&
  heads_up_state[:current_player] == "Alice",
  "Heads-up Hold'em did not place the dealer in the small blind with first pre-flop action")

jacks_options = poker.normalize_options("variant" => "draw", "jacks_or_better" => true)
jacks_state = poker.send(:initial_state, players, jacks_options)
jacks_state.update(phase: :betting, current_player: "Alice", street: 0,
  hands: { "Alice" => %w[2C 4D 6H 8S TC], "Bob" => %w[3C 5D 7H 9S JC], "Carol" => %w[3D 5H 7S 9C QD] })
jacks_replay = GameRoomGames::Replay.new(players: players, current_player: "Alice", winner: nil,
  draw: false, accepted_events: [], history: [], state: jacks_state)
assert(poker.legal_actions(jacks_replay, "Alice").none? { |action| %w[raise all_in].include?(action["action"]) },
  "Jacks-or-better allowed an unqualified player to open")
jacks_state[:hands]["Alice"] = %w[JC JD 6H 8S TC]
assert(poker.legal_actions(jacks_replay, "Alice").any? { |action| action["action"] == "raise" },
  "Jacks-or-better rejected a pair of jacks as an opening hand")

first_shuffle = poker.send(:shuffled_cards, (1..52).to_a, "0123456789abcdef0123456789abcdef")
second_shuffle = poker.send(:shuffled_cards, (1..52).to_a, "0123456789abcdef0123456789abcdef")
assert(first_shuffle == second_shuffle && first_shuffle.sort == (1..52).to_a,
  "the portable card shuffle is not deterministic or lost cards")

[monopoly, yahtzee, uno, poker, makao].each do |game|
  assert(game.minimum_players >= 2 && game.maximum_players <= 8, "#{game.id} has an unsupported player range")
  assert(game.rule_book.sections.any?, "#{game.id} has no rules")
  assert(game.validation_error(game.default_options, player_count: 3) == nil, "#{game.id} rejects its defaults")
end

puts "New games 1.1.6 tests passed"
