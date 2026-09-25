# Offline models and training

This directory is deliberately outside the installed runtime. It contains the
match runner, self-play/tournament tools, Spades training, experimental MCTS,
and the unused generic phase/score models. Their namespace and algorithms are
unchanged; tools and tests require them explicitly.

Actual game strategies, trained profiles, `GameRoomSimulation::Environment`
and the deterministic random source remain in `lib/`. Moving training code
does not change a bot's strategy, budget, seed or legal actions in a live game.
