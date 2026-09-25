require_relative "../lib/game_bots"
raise "training strategy leaked into runtime" if GameRoomBots.const_defined?(:LearnedStrategy, false)

require_relative "../tools/training/game_training"
require_relative "../games/tic_tac_toe"

def _(text)
  text
end

policy = GameRoomTraining::PolicyTable.new
trainer = GameRoomTraining::SelfPlayTrainer.new(game: GameRoomGames::TicTacToe.new, policy: policy)
report = trainer.train(episodes: 6, seed: 38)
raise "training did not finish after extraction" unless report.episodes == 6 && report.unfinished == 0
raise "training did not update policy" unless policy.state_count > 0 && policy.decision_count > 0
puts "PASS LearnedStrategy loads only from training and completes six deterministic self-play episodes"
