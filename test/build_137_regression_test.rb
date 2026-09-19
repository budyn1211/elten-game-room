def _(text)
  text
end

def n_(singular, plural, count)
  count.to_i == 1 ? singular : plural
end

def assert(value, message)
  raise message unless value
end

module GameSurfaces
  GridSpec = Struct.new(:width, :height, :header, :cells, :row_origin, keyword_init: true)
  CardChoice = Struct.new(:id, :label, :value, keyword_init: true)
  Card = Struct.new(:id, :label, :value, :choices, :shift_choice, :choice_header, :sort_keys, keyword_init: true)
  CardZoneSpec = Struct.new(:id, :header, :cards, :empty_label, :hand_order, :hand_epoch, keyword_init: true)
  CardTableSpec = Struct.new(:zones, keyword_init: true)
  Command = Struct.new(:id, :label, :enabled, :payload, keyword_init: true)
  CommandPanelSpec = Struct.new(:commands, keyword_init: true)
  SurfacePart = Struct.new(:id, :surface, keyword_init: true)
  CompositeSpec = Struct.new(:parts, keyword_init: true)
end

module Session
  def self.name = "Alice"
end

require_relative "../games/base"
require_relative "../games/tysiac"
require_relative "../games/ninety_nine"
require_relative "../games/four_in_a_row"
require_relative "../games/tic_tac_toe"
require_relative "../lib/bot_turn_gate"
require_relative "../lib/game_repository"

now = 10.0
gate = GameRoomBots::TurnGate.new(clock: -> { now })
lease = gate.acquire
assert(lease && !gate.ready? && gate.acquire.nil?, "two computers can act simultaneously")
now = 20.0
assert(gate.acquire.nil?, "a long-running move lost its lock")
gate.release(Object.new, attempted: true)
assert(!gate.ready?, "a foreign screen released a bot's move")
gate.release(lease, attempted: true)
now = 20.999
assert(!gate.ready?, "cooldown was measured from the start, not the end")
now = 21.0
lease = gate.acquire
assert(lease, "the next bot did not become eligible after one second")
gate.release(lease)
assert(gate.ready?, "cancelling an unsubmitted calculation created a delay")
lease = gate.acquire
gate.release(lease, attempted: true)
assert(!gate.ready?, "failed submissions can retry without the cooldown")

players = %w[Alice Bob Carol]
repository = Object.new
repository.define_singleton_method(:players_for) { |_session| players }
repository.define_singleton_method(:actor_of) { |event, *_| event.fetch("actor") }
repository.define_singleton_method(:event_id) { |event| event.fetch("id") }
event = ->(id, actor, action, value) { { "id" => id, "actor" => actor, "action" => action, "value" => value.to_s } }
tysiac = GameRoomGames::Tysiac.new
session = { "options" => JSON.generate(tysiac.default_options) }
events = [event.call(1, "Alice", "deal", "1|0|000102030405060708090a0b0c0d0e0f"),
          event.call(2, "Bob", "bid", 100), event.call(3, "Carol", "bid", "pass"),
          event.call(4, "Alice", "bid", "pass")]
%w[Alice Carol].each_with_index do |recipient, i|
  replay = tysiac.replay(session, events, repository)
  card = replay.state[:hands]["Bob"].first
  events << event.call(5 + i, "Bob", "pass_card", "#{recipient}|#{card}")
  replay = tysiac.replay(session, events, repository)
  label = tysiac.send(:card_label, card)
  entry = replay.history.find { |item| item.event_id == 5 + i && item.kind == :pass_card }
  assert(!entry.text.include?(label) && entry.text.include?(recipient), "public history reveals a passed card")
  players.each do |viewer|
    description = tysiac.describe_event(events.last, repository, replay, viewer).join
    sees_card = viewer == "Bob" || viewer == recipient
    assert(description.include?(label) == sees_card, "passed-card privacy is wrong for #{viewer}")
  end
end
replay = tysiac.replay(session, events, repository)
first_card = tysiac.surface_spec(replay, "Bob").zones.first.cards.first
assert(first_card.shift_choice == "marriage", "first lead does not route Shift+Enter to the marriage check")
selection = { "kind" => "card", "action" => "select", "card" => first_card.value, "choice_id" => "marriage" }
status, plan = tysiac.action_for(selection, replay, "Bob")
assert(status == :marriage_not_available && plan.nil?, "unavailable first marriage played a card")
status, plan = tysiac.action_for(selection.merge("choice_id" => "normal"), replay, "Bob")
assert(status == :ok && plan.events.map(&:action) == %w[contract play], "normal first lead changed")
[105, 110].each_with_index do |bid, i|
  status, plan = tysiac.action_for({ "kind" => "command", "action" => "contract", "bid" => bid }, replay, "Bob")
  assert(status == :ok, "repeated final raise was rejected")
  events << event.call(7 + i, "Bob", "contract", bid)
  replay = tysiac.replay(session, events, repository)
  assert(replay.state[:contract] == bid, "replay did not accept a repeated raise")
  shortcut = tysiac.game_shortcuts(replay, "Bob").find { |key| key.key == "b" }
  assert(shortcut.kind == :choice, "B stopped offering raises before the first card")
end
events << event.call(9, "Bob", "play", "normal|#{first_card.id}")
events << event.call(10, "Bob", "contract", 115)
replay = tysiac.replay(session, events, repository)
assert(replay.state[:contract] == 110 && !replay.accepted_events.include?(events.last), "a raise after the first card was accepted")
assert(tysiac.game_shortcuts(replay, "Bob").find { |key| key.key == "b" }.kind == :announcement, "B allows a late raise")

ninety = GameRoomGames::NinetyNine.new
state = ninety.send(:initial_state, players, ninety.default_options)
state[:phase] = :playing
state[:current_player] = "Alice"
state[:total] = 32
state[:hands]["Alice"] = ["0AH"]
history = []
assert(ninety.send(:apply_play, state, event.call(1, "Alice", "play", "0AH|one"), "Alice", repository, history), "99 fixture failed")
compact = ninety.send(:compact_penalties, history)
assert(compact.select { |entry| entry.kind == :penalty }.map(&:text) == ["Bob and Carol lose 1 token."], "equal losses were not grouped")
assert(state[:tokens] == { "Alice" => 9, "Bob" => 8, "Carol" => 8 }, "speech changed the token rules")
assert(!ninety.send(:tokens_text, state).start_with?("Tokens"), "S still reads the redundant heading")
assert(compact.first.kind == :play && compact.last.kind == :penalty, "grouping changed event chronology")

# Ninety-Nine must keep playing and drawing atomic for both a human and a
# computer, so a rate limit cannot persist only half of a turn.
["Alice", "bot:7:1"].each do |actor|
  state = ninety.send(:initial_state, [actor, "Bob"], ninety.default_options)
  state[:phase] = :playing
  state[:current_player] = actor
  state[:hands][actor] = ["03H"]
  replay = GameRoomGames::Replay.new(players: [actor, "Bob"], current_player: actor, state: state)
  status, plan = ninety.action_for({ "kind" => "card", "action" => "select", "card" => "03H|normal" }, replay, actor)
  assert(status == :ok && plan.events.map(&:action) == %w[play_draw], "#{actor} lost atomic automatic drawing")
end

[GameRoomGames::FourInARow.new, GameRoomGames::TicTacToe.new].each do |game|
  action, value = game.id == "four_in_a_row" ? ["drop", "1"] : ["place", "1,1"]
  move = event.call(1, "Alice", action, value)
  board_repository = repository.clone
  board_repository.define_singleton_method(:players_for) { |_| %w[Alice Bob] }
  replay = game.replay({}, [move], board_repository)
  assert(game.describe_event(move, board_repository, replay, "Alice") == "Alice A1.", "own board move is verbose")
  assert(game.describe_event(move, board_repository, replay, "Bob") == "Alice A1.", "remote board move is verbose")
  cells = game.surface_spec(replay, "Bob").cells
  assert(cells.flatten.count("Alice") == 1 && cells.flatten.all? { |x| ["", "Alice"].include?(x) }, "board still names empty cells or owners' pieces")
end

# Simulate a server saving play and then failing on draw. The next read must
# see play, rather than retrying the pair from the old in-memory snapshot.
bot = "bot:7:1"
session = { "id" => 1, "table_id" => 7, "player_one" => "Alice", "__players" => ["Alice", bot] }
rows = []
failure_table = Object.new
failure_table.define_singleton_method(:insert) do |values|
  raise "simulated failed draw" if values["action"] == "draw"
  row = values.merge("id" => rows.length + 1)
  rows << row
  row
end
failure_table.define_singleton_method(:select) { |**options| rows.drop(options[:offset].to_i) }
tables = Object.new
tables.define_singleton_method(:fetch) { |_| failure_table }
transport = Object.new
transport.define_singleton_method(:game_changed) { |**_| nil }
repo = GameRepository.new(Object.new, transport: transport, server_tables: tables)
assert(repo.bot_turn_controller(7).equal?(repo.bot_turn_controller(7)), "screens of one table do not share bot control")
assert(!repo.bot_turn_controller(7).equal?(repo.bot_turn_controller(8)), "unrelated tables block each other")
repo.send(:replace_event_cache, session, [])
begin
  repo.append_events(session: session, sequence: 2, actor: bot, events: [
    GameRoomGames::EventCommand.new(action: "play", value: "03H|normal"),
    GameRoomGames::EventCommand.new(action: "draw", value: "")
  ])
  raise "expected the submission to fail"
rescue RuntimeError => error
  raise unless error.message == "simulated failed draw"
end
assert(repo.send(:event_cache_entry, 1).nil?, "uncertain write retained a stale cache")
assert(repo.snapshot_for(session).events.map { |row| row["action"] } == ["play"], "reconciliation lost the saved part of the move")

puts "Build 137 focused regressions passed: pacing, partial writes, Tysiac and concise speech"
