require_relative "../support/game_session_runner_deadline"

# Poker asks the live runner to wait six seconds before dealing the next
# hand, so the showdown and pot can be heard. Only the runner waits: the
# game's automatic_action still returns the deal at once for simulations.
game = GameRoomGames::Poker.new
h = NativeRoomHarness.new(game: game, users: %w[Alice Bob], options: game.default_options)
h.start
rs = h.users.to_h { |u| [u, runner_for(h, u)] }
r = rs['Alice']
step(h, r, count: 3)
replay = h.replay('Alice')
assert(replay.state[:phase] == :betting && replay.state[:hand_number] == 1, "first hand was not dealt: #{replay.state[:phase]}")
actor = replay.current_player
fold = game.legal_actions(replay, actor).find { |action| action['action'] == 'fold' }
h.as(actor) { rs[actor].submit(session: h.session, replay: h.replay(actor), selection: fold, actor: actor) }
step(h, rs[actor], actor, count: 2)
step(h, r, count: 2)
finished = h.replay('Alice')
assert(finished.state[:phase] == :hand_complete, "fold did not finish the hand: #{finished.state[:phase]}")
assert(game.automatic_action(finished, 'Alice')['action'] == 'deal', "the rules policy itself was delayed")
assert(game.automatic_action_delay(finished, 'Alice', { 'action' => 'deal' }) == 6.0, "poker asks for no pause")
assert(game.automatic_action_delay(replay, 'Alice', { 'action' => 'deal' }) == 0.0, "the first deal is delayed")
step(h, r, count: 5)
assert(h.replay('Alice').state[:hand_number] == 1, "the runner dealt before the pause ended")
hold = r.instance_variable_get(:@automatic_hold)
assert(hold && hold.last - Process.clock_gettime(Process::CLOCK_MONOTONIC) > 5.0, "the runner hold is not about six seconds: #{hold.inspect}")
hold[-1] = 0.0 # the six seconds have elapsed
step(h, r, count: 2)
assert(h.replay('Alice').state[:hand_number] == 2, "the runner did not deal after the pause")
h.assert_converged('poker round pause')
rs.each_value(&:close)
puts 'PASS session runner: poker pause between hands'
