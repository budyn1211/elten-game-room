# Background processing while Game Room is covered

Feasibility experiment, 24 September 2026. **Not a production implementation.**

This is separate from [the parallel foreground scene fix](PARALLEL_SCENE_EVENTS.md).
An active parallel Game Room can dispatch pending callbacks from its own Form.
A Game Room covered by another native ELTEN scene has its UI thread suspended;
that Form cannot provide background processing.

## Observed result on ELTEN 3.0.3

Four live trials on two accounts, private Tic-tac-toe tables, 25 accepted moves:

- Control: during a 12-second cover the native stack advanced, but its callback
  stayed queued. The game model and owner's bot resumed only after returning.
- Experimental background owner: three bot replies and all six game moves were
  persisted and delivered while the owner's GameScreen remained suspended.
- Experimental background guest: received and projected the opponent's move,
  then correctly waited for human input rather than inventing a move.
- Repeated cover/return: background and foreground bot turns alternated correctly,
  with one background reply during each of two covers.

Both clients ended with identical event IDs and board hashes. No duplicate event
presentation. Chat draft, caret, selection and focus survived each return.

The cover used a neutral Form and native insert_scene. Inputs used existing
surface handlers, not physical keys. These were not actual Messages/forum screens.

## Experimental boundary

A bounded runtime-aware worker dispatched the already-open endpoint's callbacks
and rebuilt a pure replay only after incoming records changed. No extra protocol
pump or periodic server poll was added. The real game strategy, Coordinator,
action_for, TurnController and GameRepository performed bot moves. The worker did
not consume foreground synchronization flags. Standard repository gap reads and
persisted writes were unchanged.

The game UI was not updated or spoken from the worker. A TracePoint guard found no
worker calls to UI wait/update/focus, loop_update, speak, alert or selector. The
cover waited asynchronously for the worker to stop **before** resuming GameScreen.
This controlled handoff is essential; concurrent endpoint dispatch/turn runners
were not tested or declared safe.

## Production work still required

Separate a single session runner from its foreground view, rather than moving
GameScreen#run wholesale into Thread.new. Preserve action ordering, the existing
bot lease/confirmation barrier, uncertain-write recovery and lifecycle cleanup.
Deliver presentation through an appropriate UI boundary. Do not copy the local
diagnostic pump into every game or add server polling to compensate for paused UI.

Additional tests are needed for timer penalties, automatic phases, terminal table
status, arbitrary cover/return timing, network failures, updates and teardown.
Real-time games and background speech/audio were not tested. Normal GameScreen
still handled terminal table status after returning in these trials.

The first attempt failed due to an old EditBox constructor signature in our helper,
not the application. It recovered safely; the corrected control was rerun.
All temporary tables, workers, callbacks wrappers and extensions were cleaned up.
Installed files and production source were not changed by this experiment.

Private raw results and cleanup records are outside the repository in
`diagnostics/background-game-experiment-237/` relative to its parent workspace.
Do not commit that data. The installed/signed build 237 is unchanged.
