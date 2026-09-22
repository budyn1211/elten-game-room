# Doubles: fixed serve preparation, build 235

The doubles pairing announcement is now ordinary speech, like the Single
announcement. It does not request a SpeechSequence completion index, change
the preparation deadline or contribute a speech-dependent readiness flag.
It still names the server and receiver once per service block, not on the
second serve or when reconnecting within that block.

After a goal, both serves use the existing score + 2.7 second deadline.
The goal/score recording schedule and initial connection preparation are
unchanged. A late announcement does not restart the timer. Network/rally
readiness remains mandatory: fixed preparation is not permission to play
against absent players or an old state. Guests do not echo the owner's
readiness wait back into their own local countdown.

The previous implementation could wait indefinitely for an index that the
ELTEN NVDA addon omits when a SpeechSequence ends in an empty text fragment.
One player's wait then held the other participants. The fix is in Pong,
not a modification of NVDA, ELTEN or the Communications transport. Physics,
input tolerances, reliable actions, goal agreement and LiveSessions remain
unchanged. All players should update; an old client can still report its
speech-dependent wait.

## Regression coverage

- Before the fix, an output that never completes indexed speech reproduces
  the stuck match. The same fixture must unlock without supplying any index.
- Pairing text is ordinary speech for indexed and fallback outputs alike.
- Both post-score serves match Single timing, with and without goal preview.
- A delayed frame/announcement adds no second countdown.
- Early taps and held keys are not replayed as a serve after the pause.
- Four simulated humans, an observing owner, observers, late participants,
  reconnect and bot matches preserve their normal state synchronization.

The source checks are offline and do not claim a new live four-computer test
or a real-device speech test. Previously observed OwnerChanged and
PeerStatusTimeout events are separate and not declared fixed by this change.
