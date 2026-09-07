require_relative "../lib/game_rounds"
require_relative "../lib/game_random"
require_relative "../lib/game_scoring"
require_relative "../lib/hidden_submissions"

def assert(condition, message)
  raise message if !condition
end

flow = GameRoomRounds::PhaseFlow.new(
  [
    GameRoomRounds::PhaseDefinition.new(
      id: "answering",
      label: "Answering",
      allowed_actions: ["submit"],
      duration: 30
    ),
    GameRoomRounds::PhaseDefinition.new(
      id: "review",
      label: "Review",
      allowed_actions: ["accept", "reject"]
    ),
    GameRoomRounds::PhaseDefinition.new(
      id: "results",
      label: "Results",
      allowed_actions: [],
      terminal: true
    )
  ]
)
phase = flow.start(round: 2, now: 100)
assert(phase.id == "answering" && phase.deadline == 130, "phase flow created an invalid deadline")
assert(phase.remaining_seconds(115) == 15 && phase.expired?(130), "phase timing is incorrect")
assert(flow.allowed_action?(phase, "submit"), "phase rejected an allowed action")
phase = flow.transition(phase, "review", now: 131)
assert(phase.id == "review" && phase.deadline == nil, "phase transition kept an invalid deadline")
phase = flow.transition(phase, "results", now: 140)
assert(flow.terminal?(phase), "terminal phase was not recognized")

roll = GameRoomRandom::SequenceSource.new([6, 1, 4]).roll(count: 3, sides: 6)
assert(roll.values == [6, 1, 4] && roll.source == "test_sequence", "dice source returned an invalid roll")
assert(!GameRoomRandom::LocalSecureSource.new.authoritative?, "local randomness claims to be authoritative")

scores = GameRoomScoring::ScoreLedger.new
scores.add(player: "Alice", points: 10, reason: "unique answer", round_id: 1)
scores.add(player: "alice", points: 5, reason: "shared answer", round_id: 2)
scores.add(player: "Bob", points: 15, reason: "unique answer", round_id: 1)
assert(scores.total_for("ALICE") == 15, "score ledger did not normalize player names")
assert(scores.leaders.length == 2, "score ledger did not preserve a tie")

reviews = GameRoomScoring::ReviewLedger.new
reviews.record(item_id: "answer-1", reviewer: "Alice", decision: :accept)
reviews.record(item_id: "answer-1", reviewer: "Bob", decision: :challenge)
reviews.record(item_id: "answer-1", reviewer: "bob", decision: :reject)
summary = reviews.summary("answer-1")
assert(summary.counts["accept"] == 1, "manual review lost an acceptance")
assert(summary.counts["challenge"] == 0 && summary.counts["reject"] == 1, "a reviewer's replacement decision was not applied")

storage = HiddenSubmissions::MemoryStorage.new
vault = HiddenSubmissions::Vault.new(storage)
payload = {
  "country" => "Poland",
  "city" => "Poznan"
}
envelope = vault.prepare(
  session_id: 7,
  round_id: "round-1",
  user: "Alice",
  payload: payload,
  nonce: "fixed-test-nonce"
)
assert(envelope.commitment.length == 64, "hidden submission commitment has an invalid size")
assert(vault.verify(envelope), "fresh hidden submission did not verify")
restored = vault.reveal(session_id: 7, round_id: "round-1", user: "alice")
assert(restored.payload == payload, "hidden submission was not restored")
assert(
  HiddenSubmissions::Commitment.valid?(
    payload: payload,
    nonce: restored.nonce,
    commitment: restored.commitment
  ),
  "commitment verification failed"
)
tampered = payload.merge("city" => "Warsaw")
assert(
  !HiddenSubmissions::Commitment.valid?(
    payload: tampered,
    nonce: restored.nonce,
    commitment: restored.commitment
  ),
  "commitment accepted a modified answer"
)
assert(vault.discard(session_id: 7, round_id: "round-1", user: "Alice"), "hidden submission was not discarded")
assert(vault.reveal(session_id: 7, round_id: "round-1", user: "Alice") == nil, "discarded submission remained available")

puts "Game framework model tests passed"
