require_relative '../../support/new_games_fixture'
require_relative '../../../lib/game_sounds'

# Betting sounds follow what the action did: a call matches a bet, a raise
# raises, any bet that empties the stack is an all-in, and a pass is a fold.
players = %w[Alice Bob]
repository = NewGames116Repository.new(players)
poker = GameRoomGames::Poker.new
session = { "options" => JSON.generate(poker.default_options) }
events = []
replay = poker.replay(session, events, repository)
cue_for = lambda do |actor, selection|
  before = replay
  replay = append_action(poker, session, repository, events, replay, actor, selection, context_for)
  GameRoomSounds.event_cue(game: poker, event: events.last, before_replay: before, after_replay: replay,
    repository: repository, viewer: "Alice")
end
legal = ->(actor, name) { poker.legal_actions(replay, actor).find { |action| action["action"] == name } }

assert(cue_for.call("Alice", { "kind" => "command", "action" => "deal" }) == "shuffle", "deal lost its shuffle")
first = replay.current_player
second = (players - [first]).first
raise_action = legal.call(first, "raise")
assert(cue_for.call(first, raise_action) == "poker_raise", "raise has no raise sound")
assert(cue_for.call(second, legal.call(second, "call")) == "poker_call", "calling a raise has no call sound")
actor = replay.current_player
assert(cue_for.call(actor, legal.call(actor, "check")) == "poker_check", "check has no check sound")
actor = replay.current_player
assert(cue_for.call(actor, legal.call(actor, "all_in")) == "poker_all_in", "all-in has no all-in sound")
actor = replay.current_player
assert(cue_for.call(actor, legal.call(actor, "fold")) == %w[poker_fold poker_pot], "folding the hand away has no fold and pot sounds")

# Calling an all-in with the whole stack is itself an all-in; the showdown
# result cue may follow it.
events.clear
replay = poker.replay(session, events, repository)
cue_for.call("Alice", { "kind" => "command", "action" => "deal" })
first = replay.current_player
cue_for.call(first, legal.call(first, "all_in"))
caller = replay.current_player
call = legal.call(caller, "call") || legal.call(caller, "all_in")
assert(Array(cue_for.call(caller, call)).first(2) == %w[poker_all_in poker_pot], "a stack-emptying call did not sound as all-in")

%w[poker_fold poker_check poker_call poker_raise poker_all_in poker_pot].each do |name|
  assert(GameRoomSounds::ASSET_NAMES.include?(name) && File.file?(File.expand_path("../../../Audio/#{name}.opus", __dir__)),
    "missing sound #{name}")
end

puts "PASS poker: betting sounds"
