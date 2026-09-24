# Waiting room behind a native scene

`show_table_screen` used to rely on its form timer for membership, activity and
game-start delivery. A native parallel Messages/forum scene suspends that wait.
The ordinary SessionRunner could not help: no GameScreen existed yet.

`GameRoomTableBackground` covers that interval. Its independent SessionFeed
receives the existing transport notifications without consuming the visible
screen's wake-ups. While covered, a managed worker dispatches already received
callbacks and reads the normal room/session/activity projection only when dirty
or recovering. It uses the normal error/rate-limit backoff, not periodic server
polling. It remains alive through room commands until the next room projection.

The existing BackgroundPresentation bridge presents copied packets on the
active UI thread. It uses the normal membership tracker and activity presenter.
No waiting-room controls, focus, keyboard or network operations are driven by
that bridge. Speech is additive and uses the existing translated messages.

A new ordinary game gets a layout-less GameScreen and its usual SessionRunner.
The runner uses the original waiting-room UI thread as its coverage boundary,
not the thread currently displaying Messages. On return, the same screen adopts
the shared layout, event cursor, activity cursor and audio queue. It does not
start a second executor or repeat old events. The last activity announced by
the foreground room refresh is also acknowledged during adoption. Archived
events of a restored game are skipped. Covered aborts still allow room/chat
activity to be presented.

Pong and Audio Ball receive the room-level start announcement, but their
UI-driven clients/physics/Communications are not created in another native
scene. This change does not make realtime gameplay run behind Messages.

Closure is announced once. Closing the table/parent runtime releases the
subscription, presentation registration and owned game executor. Only a
deliberate foreground handover retains that executor.

Regression: `test/game_table_background_test.rb`, existing room/interface and
client lifecycle tests, background presentation/native input/reload tests and
SessionRunner recovery/instances/simultaneous-input tests. Live diagnostics
outside the repository use normal private tables on two accounts, actual native
Messages/forum lists, input handlers and real speech/audio adapters. They are
not physical keyboard/ear tests or different computers/networks.
