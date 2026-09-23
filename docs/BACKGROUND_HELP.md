# Help without pausing a game

F1 shortcuts and Ctrl+F1 rules, game shortcuts, table options and the audio
tutorial use the same background-help mechanism in every active GameScreen.
Games do not implement their own help loop. Future games using the standard
screen inherit this behaviour. This does not change global ELTEN help or
unrelated settings/input dialogs.

## One game loop

`GameRoomUI::Form` owns a small stack of native help forms. Its native wait
continues; each update sends input only to the top help form, then updates
the existing parent timers. It does not run the parent game controls. There is
no second gameplay loop, extra polling, or direct repository access in help.

A refresh leaves the current wait normally. GameScreen consumes the update,
replays events, handles normal automatic actions and bot decisions, and binds
the same layout again. Help forms survive with their current caret/selection.
Refocusing the parent during maintenance does not reread or close the help.
Network tasks use the parent form while help is open, so reading can continue
during ordinary asynchronous work as well.

The existing clock remains authoritative. Help does not stop turn deadlines,
received warnings, transport heartbeats, or sound/result presentation. Durable
scores still pass through `automatic_action`, `action_for`, GameRepository and
replay; ticking only a realtime client's connection would not be sufficient.

## Input and lifetime

Enter/Escape close shortcut help without submitting the underlying move.
Ctrl+F1 keeps its normal document navigation. The tutorial has its own Enter/
Space playback and Escape returns to its selected rules-menu item. Game
updates must not reopen the tutorial, restart previews or repeat its welcome.
Closing the game closes all overlays and releases tutorial audio.

New realtime surfaces must respect active focus and the parent form's
`game_room_background_help?` flag, including the opening frame (when the
host's active-control list may still contain the game field). Help keys and
mouse movement must not generate new game actions. Already accepted game
choices continue according to the game's rules; help does not revoke them.

Pong also keeps its last observed keyboard press counter across neutral
network/chat-only frames. Absence of the counter is not a reset to zero.
`playable_input` consumes counters during inactive frames but only accepts
new gameplay input when its own playfield is active. This fixes the reproduced
spontaneous serve after chat work without changing physics or transport.

## Offline regressions

- `background_help_test.rb`: timer lifecycle, maintenance, retained caret/chat,
  nested F1/rules/tutorial and preview cleanup.
- `background_help_native_test.rb`: actual host Form/EditBox/ListBox/input loop,
  arrows, maintenance without repeated speech and isolated closing Enter.
- `background_help_game_screen_test.rb`: incoming moves and bot responses
  through the real GameScreen/repository, two automatic realtime points behind
  F1 and tutorial, plus a 40-second two-client warning/heartbeat scenario.
- `rules_help_lifecycle_test.rb`: existing documents, phases, shortcut bindings,
  hand/chat state and timer cleanup.
- `axel_pong_chat_input_test.rb`: stale/empty counters with no network task,
  progress task and chat-only task; a deliberate fresh tap still serves.

The tests use in-memory transport and sound/input peripherals. They are not
an Internet multiplayer test, physical keyboard test or audible NVDA trial.
