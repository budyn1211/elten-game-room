# Event delivery when Game Room is opened above another ELTEN scene

ELTEN 3.0.3's main UI thread runs LiveSessions protocol work even while a
parallel scene is active, but uses `tick(dispatch: false)` during that time.
The normal full dispatch is main-thread-only. Thus a Game Room opened over
Conference can receive stack data without receiving the callbacks that wake
its synchronizer. Sending chat happens to trigger a normal repository read;
it does not restore delivery of subsequent moves.

## Application-side fix

`GameRoomUI::Form#update` now delivers pending callbacks before the existing
form timers, only when the form is waiting on the active, non-main UI thread.
It calls the program, transport and LiveSessions store; no game class needs
an individual workaround.

- Only the store's **already opened** endpoint is used. No lazy connection,
  global dispatch, protocol tick, snapshot polling, worker or host patch.
- A call processes at most 32 callbacks, additionally subject to the host's
  existing 10 ms limit. Remaining callbacks wait for the next UI frame.
- A nonblocking store guard prevents recursive/concurrent application calls.
  The host endpoint's native dispatch guard remains in force, including a
  main-thread callback suspended while another scene opens.
- Main-thread forms keep ELTEN's normal delivery. A nonwaiting form, inactive
  scene thread or closed endpoint does nothing. A background-help child does
  not drain again after its parent already did so in the same update.
- Callbacks only wake the existing replay/recovery path. Keyboard input,
  selection, chat draft, history, game rules and network packets are unchanged.

This is **not** background execution of an entire game while another ELTEN
window covers it. Delivery resumes when that Game Room scene is active again.
It also does not claim to fix every historical network/recovery incident or
the separate Communications dispatch contract.

## Regression coverage

`test/parallel_scene_events_test.rb` uses the real host callback queue and
dispatcher with network work forbidden. It covers scope/lifecycle, main versus
parallel thread, ordering, reentrancy, a suspended native dispatch, bursts,
start/move/room/recovery/closure notifications, help and draft preservation.
Its first assertion fails on the old application code.

`test/parallel_scene_native_test.rb` additionally uses actual host forms,
EditBox and KeyboardState: a Unicode character and a received callback in
each frame, without Enter. Neither characters nor callbacks are lost or
duplicated. Input peripherals are simulated, not a physical-keyboard test.

Set `ELTEN_HOST_SOURCE` to the source matching the running host. Targeted
transport, multiplayer, recovery, synchronization, help and focus regressions
are also required; a full unrelated suite is unnecessary for this change.

Live verification and private traces are kept outside the repository in
`../diagnostics/live-sessions-threading-fix-237/`. They distinguish actual
server delivery from test-generated input and record cleanup and limitations.

## Live result (24 September 2026)

Five private-table trials on two ELTEN 3.0.3 clients passed: parallel guest,
main-thread game covered by another scene, doubly nested guest with a chat
draft, parallel host with a bot and observer, and a rematch with both clients
in parallel scenes. All 44 moves were presented exactly once on each client;
event order and final boards matched. All eight moves of the original failing
parallel scenario arrived before the first chat message. Draft, selection and
focus survived a remote move, and delivery resumed after returning from an
overlay without sending chat.

This used the native parallel-scene mechanism over neutral diagnostic windows,
not a joined voice conference. A separate helper bug during the first extended
trial required restarting only the test client, with the user's permission;
the failed trial was retained and excluded from successful results. After
fixing the helper, the extended trials passed. Both clients ended on Scene_Main
with test tables closed, no managed resources or pending callbacks, and all
temporary instrumentation/injected methods removed. The source fix remains
unreleased; no installer or installed application files were changed.
