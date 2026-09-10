# Audit and synchronization fixes — version 1.1.5, build 203

These changes are assigned to test build 203, version 1.1.5. Installation and
publication remain the user's decision. The first section records the original
audit fixes 1–7. The subsequent synchronization section records four additional
approved fixes, including packet validation from the original audit.

## Implemented

1. **Categories commit/reveal retries.** Identical submissions reuse their
   envelope. Edited retries retain earlier envelopes, and reveal selects the
   version matching the commitment actually accepted in the game. This also
   works after reloading the locally persisted vault.
2. **Native error boundaries.** Both network task wrappers recognize native
   `EltenAPI::LiveSessions::Error` as well as `EltenLink::Error`. Cancellation and
   silent operations retain their behavior; programming errors still propagate.
   A failed stack read is no longer reported as a successful partial snapshot.
   A native gap wakes the normal synchronizer rather than performing a blocking
   read inside the callback.
3. **Last available Categories letter.** A single remaining letter is selected
   directly, without an invalid one-sided random roll. An exhausted alphabet
   retains the existing reset behavior.
4. **Stack cleanup at the next game.** The owner appends a complete `room_state`
   checkpoint and `game_started`, then trims only the prefix before the
   checkpoint. No session migration or per-game state serialization is needed.
   Failure before start acknowledgement never trims the old log. Failure of
   the subsequent trim does not turn an already-committed start into failure.
   Concurrent entries after the checkpoint are preserved. Previously received
   chat/room history stays in the current client's memory, while a fresh client
   receives only the retained server log. All packets still use protocol 2.
   A local acknowledgement cannot advance the read cursor over an unread
   remote entry; reads and late notifications deduplicate normally.
5. **Invitation delivery.** The old local owner-only guard is removed from the
   native invitation path. The API validates the inviting participant. False
   or exceptional delivery does not produce a success message, send a fallback
   notification, or retain a ten-minute duplicate reservation. Both recipient
   selectors use the same path.
6. **Invitation capacity.** Public discovery and invitation acceptance share
   the post-join check counting humans plus computers. An over-capacity join is
   left immediately. A consumed invitation is not restored as pending when
   subsequent initialization fails.
7. **Remote closure.** Game screens return `room_closed`, distinct from voluntary
   `back`. The room shell exits and forgets local membership without asking
   whether to leave a room that is already closed.

## Four additional synchronization fixes

1. **Automatic transitions recover after failure.** A failed or cancelled
   automatic action schedules the existing synchronizer's recovery. Until a
   successful reconciliation, the screen does not start another automatic
   action or bot calculation from that stale replay. Recovery performs an
   actual read, then recomputes the required action. Categories therefore
   retries a missing reveal but does not duplicate one committed before a lost
   acknowledgement. No periodic polling or session invitation loop was added.
2. **Forced verification reaches the native stack.** `force_events` is forwarded
   through repository, transport and store. It bypasses stale local `last_seq`
   metadata and actually calls `stack_read`. Normal notification processing and
   confirmation identifiers still use the persisted local cache; they do not
   introduce an extra read for every move or repeat the verification read.
3. **A failed new-game opening retains its target.** The requested game ID is
   cleared only after successful loading. A failed opening schedules recovery
   and pauses old-game automatic actions. Successful chat or users-only
   refreshes cannot cancel outstanding game recovery. The last displayed
   snapshot is retained during a failed recovery read instead of abandoning
   the pending target by discarding the screen.
4. **Malformed packets cannot block later valid entries.** Record validation
   checks protocol, sender authority and data types before replay/conversion:
   room fields, player lists, options, game IDs, logical sequence numbers and
   event commands. Bad entries are ignored and diagnosed without printing
   private packet contents. Logical action sequence zero remains valid.

The original five reproductions failed before these changes. The regression
file now covers six scenarios, including cancellation before the operation
block. The malformed-packet test submits 82 invalid packets followed by a valid
move and verifies convergence of four native clients.

Additional passing targeted scripts:

- `test/synchronization_regressions_test.rb`
- `test/native_packet_validation_test.rb`
- `test/bot_turn_controller_test.rb`
- `test/bot_submission_test.rb`
- `test/room_lifecycle_test.rb`

The affected network, sync, room UI, native store, stack cleanup, transport,
Categories, framework, multiplayer and resilience scripts were rerun after
these changes. The verification test also asserts one actual read for uncertain
write recovery and no extra read for ordinary cached confirmation.

## Updated test coverage

`transport_test.rb`, `live_sessions_multiplayer_test.rb` and
`live_sessions_resilience_test.rb` now instantiate the production default
transport and native stack store. They no longer instantiate `HybridBackend`,
`LiveSessionBackend` or a Signals bootstrap. Their shared test broker is in
`test/support/native_live_sessions.rb`; the original native store test also
uses this broker instead of keeping a separate implementation.

The broker separates delivery from storage and acknowledgements, preserves
monotonic sequence numbers after trimming, enforces requested stack limits,
supports ordered pagination and gaps, and can fail before/after a push or trim.
No legacy app table can serve as game storage in these scenarios.

Passing targeted tests:

- `test/framework_models_test.rb`
- `test/categories_test.rb`
- `test/game_screen_network_test.rb`
- `test/network_errors_test.rb`
- `test/room_interface_test.rb`
- `test/native_live_sessions_store_test.rb`
- `test/native_stack_cleanup_test.rb`
- `test/transport_test.rb`
- `test/live_sessions_multiplayer_test.rb`
- `test/live_sessions_resilience_test.rb`
- `test/game_sync_test.rb`
- `test/invitation_repository_test.rb`
- `test/invitation_shortcuts_test.rb`
- `test/invitation_notifications_test.rb`

The resilience test passed 400 batches each with seeds 20260910, 42 and 20260911.
Each run included 10 new-game cleanups. Multiplayer coverage includes actual
Ninety-Nine play/draw, Farkle roll/keep/bank, and full Categories rounds with
4 and 8 clients, 9 categories, concurrent commitments and 48-character answers.
Capacity coverage reaches the configured 4096-entry boundary, rather than
testing against an unbounded fake stack.

## Remaining limitations

- Cleanup between games does not solve a *single* game/chat filling the stack.
  Starting the next game requires two free entries for checkpoint and start.
  An already full session is not destructively cleared to bypass that condition.
- Old history is intentionally unavailable to a fresh client after cleanup.
- These are local deterministic tests, not a live ELTEN multiplayer test. In
  particular, guest invitation permission is still subject to the actual server.
- The old suite's unrelated prior test adjustments are preserved. No full-suite
  run was needed for this change set. The version was subsequently changed to
  1.1.5 and build 203 at the user's request for a signed test package.

## Follow-up review

Three additional defects were reproduced after completing the approved fixes.
They have **not** been changed. See
[the follow-up findings](SYNC_FOLLOWUP_AUDIT_2026-09-10.md) for conditions,
evidence and suggested fixes. Local reproduction scripts live outside the
public repository in `diagnostics/audit-2026-09-10/followup_sync_probes.rb`.
