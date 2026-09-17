require_relative 'farkle_test'
def final_replay(state)
  GameRoomGames::Replay.new(players: state[:players],current_player: state[:current_player],winner: state[:winner],draw: state[:draw],state: state,history: [],accepted_events: [])
end
game = GameRoomGames::Farkle.new
repo = FarkleRepository.new(%w[A B C])
options = game.normalize_options('score_limit'=>100,'entry_minimum'=>0,'turn_minimum'=>0)
session = {'options'=>JSON.generate(options)}
def bank_events(id,who,values,indices)
  [farkle_event(id,who,'roll',values),farkle_event(id+1,who,'keep',indices),farkle_event(id+2,who,'bank')]
end
events = bank_events(1,'A','1,2,3,4,5,6','0,1,2,3,4,5')
r = game.replay(session,events,repo)
assert(!r.finished? && r.state[:final_round] && r.current_player == 'B','first player starts final circuit')
events += bank_events(4,'B','2,2,2,3,3,3','0,1,2,3,4,5')
r = game.replay(session,events,repo)
assert(!r.finished? && r.state[:scores]['B'] == 250,'middle player overtakes')
events << farkle_event(7,'C','roll','2,2,3,3,4,6')
r = game.replay(session,events,repo)
assert(r.finished? && r.winner == 'B' && r.current_player == nil,'final bust ends round')
assert(game.legal_actions(r,'A').empty?,'no moves after finish')
events += bank_events(8,'A','1,1,1,1,1,1','0,1,2,3,4,5')
assert(game.replay(session,events,repo).accepted_events.length == 7,'late events ignored')
tie = bank_events(1,'A','1,2,3,4,5,6','0,1,2,3,4,5') + bank_events(4,'B','1,2,3,4,5,6','0,1,2,3,4,5') + [farkle_event(7,'C','roll','2,2,3,3,4,6')]
r = game.replay(session,tie,repo)
assert(r.finished? && r.draw && !r.winner,'tied highest is draw')
last = [farkle_event(1,'A','roll','2,2,3,3,4,6'),farkle_event(2,'B','roll','2,2,3,3,4,6')] + bank_events(3,'C','1,2,3,4,5,6','0,1,2,3,4,5')
assert(game.replay(session,last,repo).winner == 'C','last player wins immediately at end of circuit')
middle = [farkle_event(1,'A','roll','2,2,3,3,4,6')] + bank_events(2,'B','1,2,3,4,5,6','0,1,2,3,4,5')
assert(game.replay(session,middle,repo).current_player == 'C','middle threshold leaves only last player')
old = {'options'=>JSON.generate(options.reject { |k,_| k == 'farkle_rules_version' })}
assert(game.replay(old,tie,repo).winner == 'A','old archives retain immediate winner')
assert(game.new_game_options(game.options_from_json(old['options']))['farkle_rules_version'] == 2,'new match upgrades rules')

state = game.send(:initial_state,%w[A B C],game.normalize_options('score_limit'=>1000,'entry_minimum'=>0,'turn_minimum'=>0))
state.merge!(phase: :awaiting_roll,current_player: 'C',turn_points: 50,dice_to_roll: 2,final_round: true)
state[:scores].merge!('A'=>1200,'B'=>800,'C'=>1000)
strategy = FarklePlanning::Strategy.new(max_future_rolls: 1)
choose = -> { strategy.choose(actions: game.legal_actions(final_replay(state),'C'),actor: 'C',game: game,replay: final_replay(state),random_source: nil) }
assert(choose.call['action'] == 'roll','do not bank a certain loss at 1050 against 1200')
state[:turn_points] = 205
assert(choose.call['action'] == 'bank','do not risk guaranteed outright final win')
state[:turn_points] = 200
assert(%w[roll bank].include?(choose.call['action']),'tie is evaluated, not treated as outright win')
state[:current_player] = 'A'
state[:turn_points] = 50
strategy.choose(actions: game.legal_actions(final_replay(state),'A'),actor: 'A',game: game,replay: final_replay(state),random_source: nil)
assert(strategy.send(:bank_payoff,100,1200,1000) > strategy.send(:bank_payoff,50,1200,1000),'points above limit retain value')
assert(strategy.instance_variable_get(:@max_future_rolls) == 1,'search budget unchanged')
puts 'Farkle final circuit, legacy replay and bot endgame: OK'
