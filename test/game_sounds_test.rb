def _(text)
  text
end

require_relative "../lib/game_sounds"

def assert(condition, message)
  raise message if !condition
end

Replay = Struct.new(:players, :winner, :draw, :state, :history, keyword_init: true) do
  def finished?
    winner != nil || draw == true
  end
end
History = Struct.new(:event_id, :kind, keyword_init: true)

class SoundGame
  attr_reader :id

  def initialize(id)
    @id = id
  end

  def bot_reward(replay, viewer)
    GameRoomParticipants.same?(replay.winner, viewer) ? 1.0 : -1.0
  end
end

repository = Object.new
repository.define_singleton_method(:event_id) { |event| event.fetch("id") }
viewer = "Alice"

def cue(game_id, event, before, after, repository, viewer)
  GameRoomSounds.event_cue(
    game: SoundGame.new(game_id),
    event: event,
    before_replay: before,
    after_replay: after,
    repository: repository,
    viewer: viewer
  )
end

playing = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: {}, history: [])
assert(cue("spades", { "id" => 1, "action" => "deal" }, playing, playing, repository, viewer) == "shuffle", "Spades did not shuffle on a deal")
assert(cue("spades", { "id" => 2, "action" => "play", "value" => "AS" }, playing, playing, repository, viewer) == "draw2", "Spades trump did not use draw2")
assert(cue("spades", { "id" => 3, "action" => "play", "value" => "AH" }, playing, playing, repository, viewer) == "play", "ordinary Spades card did not use play")

before_32 = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { total: 32, eliminated: { viewer => false, "Bob" => false } }, history: [])
after_34 = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { total: 34, eliminated: { viewer => false, "Bob" => false } }, history: [])
assert(cue("ninety_nine", { "id" => 4, "action" => "play", "value" => "05C|normal" }, before_32, after_34, repository, viewer) == "draw2", "crossing 33 did not use draw2")

before_98 = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { total: 98, eliminated: { viewer => false, "Bob" => false } }, history: [])
after_99 = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { total: 99, eliminated: { viewer => false, "Bob" => false } }, history: [])
assert(cue("ninety_nine", { "id" => 5, "actor" => viewer, "action" => "play", "value" => "0AC|one" }, before_98, after_99, repository, viewer) == "win1", "the viewer reaching exactly 99 did not use win1")
assert(cue("ninety_nine", { "id" => 6, "actor" => "Bob", "action" => "play", "value" => "0AC|one" }, before_98, after_99, repository, viewer) == "lose1", "an opponent reaching exactly 99 did not use lose1")

after_100 = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { total: 100, eliminated: { viewer => false, "Bob" => false } }, history: [])
assert(cue("ninety_nine", { "id" => 7, "actor" => viewer, "action" => "play", "value" => "02C|normal" }, before_98, after_100, repository, viewer) == "lose1", "the viewer exceeding 99 did not use lose1")
assert(cue("ninety_nine", { "id" => 8, "actor" => "Bob", "action" => "play", "value" => "02C|normal" }, before_98, after_100, repository, viewer) == "win1", "an opponent exceeding 99 did not use win1")

three_active = Replay.new(players: [viewer, "Bob", "Carol"], winner: nil, draw: false, state: { total: 10, eliminated: { viewer => false, "Bob" => false, "Carol" => false } }, history: [])
assert(cue("ninety_nine", { "id" => 9, "action" => "play", "value" => "04C|normal" }, three_active, three_active, repository, viewer) == "reverse3", "a Ninety-Nine direction change did not use reverse3")
assert(cue("ninety_nine", { "id" => 10, "action" => "play", "value" => "0JC|normal" }, playing, playing, repository, viewer) == "reverse", "a Ninety-Nine skip did not use reverse")
assert(cue("ninety_nine", { "id" => 11, "action" => "draw" }, playing, playing, repository, viewer) == "draw", "a Ninety-Nine draw did not use draw")

farkled = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: {}, history: [History.new(event_id: 12, kind: :farkle)])
assert(cue("farkle", { "id" => 12, "action" => "roll" }, playing, farkled, repository, viewer) == "farkle", "a Farkle did not replace the ordinary roll sound")
before_hot_dice = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { dice_to_roll: 2 }, history: [])
after_hot_dice = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: { dice_to_roll: 6 }, history: [])
assert(cue("farkle", { "id" => 13, "action" => "keep", "value" => "0,1" }, before_hot_dice, after_hot_dice, repository, viewer) == "replay", "hot dice did not use replay")
assert(cue("four_in_a_row", { "id" => 14, "action" => "drop" }, playing, playing, repository, viewer) == "play2", "a board piece did not use play2")
assert(cue("chess", { "id" => 141, "action" => "move" }, playing, playing, repository, viewer) == "play2", "a chess move did not use play2")
assert(cue("checkers", { "id" => 142, "action" => "move" }, playing, playing, repository, viewer) == "play2", "a checkers move did not use play2")
assert(cue("reversi", { "id" => 143, "action" => "place" }, playing, playing, repository, viewer) == "play2", "a Reversi move did not use play2")
assert(cue("ludo", { "id" => 144, "action" => "roll" }, playing, playing, repository, viewer) == "roll", "a Ludo roll did not use roll")
assert(cue("ludo", { "id" => 145, "action" => "move" }, playing, playing, repository, viewer) == "play2", "a Ludo pawn move did not use play2")
assert(cue("ludo", { "id" => 146, "action" => "move_pawn" }, playing, playing, repository, viewer) == "play2", "a semantic Ludo pawn move did not use play2")
automatic_ludo = Replay.new(players: [viewer, "Bob"], winner: nil, draw: false, state: {}, history: [History.new(event_id: 147, kind: :move)])
assert(cue("ludo", { "id" => 147, "action" => "roll" }, playing, automatic_ludo, repository, viewer) == ["roll", "play2"], "an automatic Ludo move lost one of its sounds")

won = Replay.new(players: [viewer, "Bob"], winner: viewer, draw: false, state: {}, history: [])
lost = Replay.new(players: [viewer, "Bob"], winner: "Bob", draw: false, state: {}, history: [])
assert(cue("four_in_a_row", { "id" => 15, "action" => "drop" }, playing, won, repository, viewer) == "win2", "winning a game did not use win2")
assert(cue("four_in_a_row", { "id" => 16, "action" => "drop" }, playing, lost, repository, viewer) == "lose3", "losing a game did not use lose3")

tracker = GameRoomSounds::MembershipTracker.new
assert(tracker.observe([viewer]).empty?, "the first room snapshot announced an old member")
assert(tracker.observe([viewer, "Bob"]) == ["connect"], "a room join did not use connect")
assert(tracker.observe([viewer]) == ["disconnect"], "a room departure did not use disconnect")
assert(tracker.observe([viewer, "bot:1:1"]).empty?, "a computer was announced as a human room member")

program = Object.new
played = []
program.define_singleton_method(:play_sound_from_asset) { |name| played << name }
GameRoomSounds.play_all(program, ["welcome", "connect", "not_registered"])
assert(played == ["connect"], "the sound player accepted a removed or unknown asset")

puts "Game sound tests passed"
