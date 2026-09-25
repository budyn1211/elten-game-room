# The existing native-transport regression fixture also checks late/concurrent
# answers and owner-observer progression before the new file-boundary cases.
require_relative "support/quiz_party_review_regressions"
require_relative "support/hidden_submission_files"
require "tmpdir"

Dir.mktmpdir("quiz-storage-217-") do |dir|
  $quiz_regression_now = 1000
  f = QuizReviewFixture.new
  program = HiddenSubmissionFiles.new(dir)
  main = HiddenSubmissions::ProgramStorage::DEFAULT_PATH
  recovery = main + ".recovery.json"
  f.contexts.each_value do |c|
    c.hidden_submissions = HiddenSubmissions::Vault.new(HiddenSubmissions::ProgramStorage.new(program))
  end
  program.blocked = [main]
  f.h.users.each { |u| f.h.write(u, f.plan(u).events) }
  assert(f.h.replay("Alice").state[:commitments].size == 4, "fallback lost concurrent answers")
  # Recreate both the Program wrapper and vaults: no memory-only recovery.
  program = HiddenSubmissionFiles.new(dir)
  f.contexts.each_value do |c|
    c.hidden_submissions = HiddenSubmissions::Vault.new(HiddenSubmissions::ProgramStorage.new(program))
  end
  f.auto("Alice")
  f.h.users.each { |u| f.auto(u) }
  assert(f.h.replay("Alice").state[:reveals].size == 4, "fallback failed to reveal all answers")
  program.blocked = [main, recovery]
  count = f.h.events("Alice").size
  # The user's first stack was here: a confirmed owner's reveal is cleaned up
  # while automatic_action must still return finish_question.
  f.auto("Alice")
  f.h.assert_converged("cleanup failure cannot prevent scoring")
  r = f.h.replay("Alice")
  assert(r.state[:scores].values == [1, 1, 1, 1], "cleanup failure changed scores")
  assert(f.h.events("Alice").size > count, "cleanup exception stalled the question")
  f.advance(1004)
  f.auto("Alice")
  assert(f.h.replay("Alice").state[:phase] == :answering, "cannot open next question after cleanup failure")

  f.h.users.each do |u|
    status, plan = f.answer(u)
    assert(status == :local_storage_unavailable && plan.nil?, "failed save produced a commitment")
  end
  bot_state = f.h.replay("Alice")
  bot_state.state[:players] = ["Alice", "bot:4:1"]
  coordinator = GameRoomBots::Coordinator.new
  decision = coordinator.decide(game: f.game, replay: bot_state, actor: "bot:4:1", context: f.contexts["Alice"])
  assert(decision != nil, "bot did not select an answer")
  status, plan = f.game.action_for(decision.action, bot_state, decision.actor, context: f.contexts["Alice"])
  assert(status == :local_storage_unavailable && plan.nil?, "bot save exception escaped or sent an unsaved answer")
  # Exercise the actual screen branch from the second reported stack.
  screen = GameScreen.allocate
  screen.instance_variable_set(:@table_owner, "Alice")
  screen.instance_variable_set(:@game, f.game)
  screen.define_singleton_method(:action_context) { f.contexts["Alice"] }
  f.h.as("Alice") do
    assert(!screen.send(:perform_bot_turn, bot_state, decision, lease: nil, form: nil), "screen treated failed storage as a submitted bot action")
  end
  program.blocked = []
  program.retry_now
  # Restore a fresh replay; the local test mutation above never touched wire data.
  f.h.users.each { |u| f.h.write(u, f.plan(u).events) }
  f.auto("Alice")
  f.h.users.each { |u| f.auto(u) }
  f.auto("Alice")
  f.h.assert_converged("question after storage recovery")
  assert(f.h.replay("Alice").state[:scores].values == [2, 2, 2, 2], "retry changed quiz scoring")
end
puts "Quiz storage failures: four readers, scoring, next question and bot path passed"
