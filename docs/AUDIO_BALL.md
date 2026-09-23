# Audio Ball

## Scope

Audio Ball is a new Game Room game, ID `audio_ball`. It supports exactly two
players: two humans, a human and a bot, or bots controlled by the table owner.
The owner may spectate. Existing Pong code and shared transport behavior are
unchanged. No installation, release number change, signature or publication is
part of this implementation.

## Controls and rules

- Up arrow / W: select lane one, or make the first shot after preparation.
- Left arrow / D: select lane two, or make the second shot after preparation.
- Down arrow / S: select lane three, or make the third shot after preparation.
- Right arrow / A: prepare to serve or hit after a defense.
- Shift+S: read both players' points and won sets.
- T: read the server and connection status.
- Ctrl+W: warn the opponent who is holding the ball.
- Ctrl+P: choose the local listening side before or during a match.

The A/D mapping is deliberately nonstandard: Left/D and preparation Right/A.
Game keys operate only in the playfield, not chat, help or another application.
Held keys are not queued across pauses, focus changes or modal settings.

The court is 25 steps wide and has three shot lanes. Every new opponent hit
requires a NEW fresh defensive press for that incoming flight, even when the
opponent repeats the previous shot type. An early tap after the hit persists
after release until contact within the final two steps; no second timed press
or held key is required. Without a fresh choice for that flight, the ball is
missed. A previous defense, a pre-hit choice, a still-held key or the player's
own attack cannot arm the next defense. Only the latest accepted choice for
the current flight decides contact. Wrong choices can be corrected before the
ball passes. Arming is scoped to the flight, including bot hits inside a frame
and remote events, not merely to a durable point or visual surface instance.
An already armed defense survives chat/settings for the SAME flight; UI keys
cannot arm another one. Real network pause freezes physics. Preparation and
each attack still require separate fresh presses. Bots obey the same rule.

Holding the ball has no time limit until the opponent requests a warning.
The holder then has ten active seconds to hit. Preparing does not cancel or
restart the countdown. A repeated warning does not extend it. Expiry awards
the opponent a point. Only the holder's controller resolves that timeout;
other computers do not compare wall clocks to invent penalties.

Easy starts at 4.0 seconds per full flight, Normal at 1.3, Hard at 0.9 and
Impossible at 0.6. Later shots increase speed by 5%, 10%, 8% and 4% respectively.
The Impossible bot keeps the Hard reaction/error strategy; its flight timing
is different. Existing bot tuning is otherwise unchanged. Flight duration is
divided by the speed multiplier, rather than reduced by that percentage.
Each new rally resets the speed; there is no arbitrary gameplay speed floor.

The first server is randomly drawn once through a durable event. Service
changes after every two completed points, including deuce and across sets.
Every set requires at least 7 points and a two-point lead. The table selects
one, two or three won sets. Between sets there is a five-second pause, followed
by the next ordinal set announcement. Ordinary points use the Pong-style
5.7-second restart pause for recorded score presentation. Speech never acts
as a network-readiness barrier.

Creation uses the existing privacy control, followed by mode (Classic only),
difficulty and sets to win. There is no 7/11 choice and no generic bot-delay
option for this real-time game. Unfinished matches cannot be saved.

## Audio and speech

By default the listener is on the right and the opponent on the left. Incoming
flights move left to right, outgoing flights right to left. Ctrl+P opens local
settings, storing `audio_ball.listening_side` as `right` or `left` in the existing
settings JSON. Choosing left mirrors both flight and preparation, including
an already playing sound, without restarting the stream or changing physics,
player indexes or scores. Each shot has a distinct mono loop; preparation is
a one-shot cue. Sound position and game volume update without restarting.

The personal dialog continues realtime ticks and networking while it is open.
Gameplay commands and warnings are blocked during the dialog; queued and held
navigation keys are cleared on exit, including exceptions, until released.

Goal effects, goal voices, the score introduction and numbers reuse Axel Pong
assets and its announcement sequencing. Recorded numbers cover 0 through 21;
if either score is outside that range or a required recording is missing,
Elten speech reads the complete own-first score. Observers use table order.
Set, warning and server information remains synthesized; queued announcements
are not cut by rally reset, view detach or the final replay. Ticking continues
on the finished screen; close cancels and releases resources. No speech
completion barrier controls gameplay. English and Polish strings are included,
with `stop: false` and `break_sequence: false` for synthesized messages.
Accepted-point announcements are deduplicated across frames and reconnections.
Pong assets retain their existing shipped attribution. The four Audio Ball
flight/preparation cues are documented in `AUDIO_BALL_SOUND_LICENSES.md`, with
attribution in `THIRD_PARTY_NOTICES.md`.

## Runtime ownership and event route

1. After an opponent hit, a fresh playfield direction arms a local lane for
   that incoming flight only. Frame contact passes the current-flight choice
   to the existing Engine defense path. Prepare and attack presses still use
   the ordinary Engine transitions.
2. Only accepted prepare, hit, defend or miss transitions enter EventChannel.
3. The authenticated actor sends directly through the shared Communications
   relay to the other participants (`audio-ball-peer-1`, peer routing).
4. Receivers check match, generation, rally, side and transition order before
   applying the event and updating audio. Only the recipient of a flight
   decides its timely defense or miss. The table owner controls bot sides,
   never remote human input merely because a bot is present.
5. Replaceable status/snapshots retain the existing owner-star route. The
   owner waits for all human participants to agree on the goal and turn.
6. The agreed value enters `context_data`, then the normal GameScreen
   automatic-action path, `action_for`, GameRepository and durable replay.
   The client never writes scores directly.

The durable start and point records are owner-authored and reject duplicates,
wrong sequence and foreign authors. This is not an independent anti-cheat
proof against a malicious owner. Reliable buffers are bounded. Missing or
stale participants pause clocks; recovery discards unconfirmed play but keeps
an already agreed pending point. A participant rejoining the same session after
transport failure requests an owner-authorized new generation and stays paused
until it is agreed; it cannot silently keep a lost warning only on its own copy.
A spectator instead resumes after validating and restoring a fresh owner
snapshot, without resetting the players' match. Late spectators restore the
current snapshot rather than waiting for unavailable historical transitions.

## Native test prerequisites

Native input regressions require an Elten source checkout. Set `ELTEN_HOST_SOURCE`
to its directory before running `ruby tools/run-tests.rb` or the native Audio Ball
tests. CI checks out public `dawidpieper/elten3` at
`389153fa29d750c3aee90d2a789984490cb97825` into `.ci/elten3` and sets this variable.
The host's keyboard and UI sources are loaded without launching Elten. A missing
configured host is an error, not a silently skipped native regression. The binary
wrapper without an installer argument verifies packaged-style source loading and
does not require the installer-decoding gems.

## Verification boundaries

The `test/audio_ball_*_test.rb` scripts cover engine, bot, audio, game replay,
startup, keyboard focus, table creation, binary PL/EN/fallback loading,
announcements, client recovery, real GameScreen/GameRepository scheduling,
and complete matches through real fields and EventChannel.

The relay fixture substitutes external Communications sessions and finite
network work, not the production EventChannel. Audio tests use fake host sound
handles. Local host Tasks and Dictionary classes have also been exercised.
These checks are not a live Internet match or an audible device test.

The default complete runner currently stops at an existing Farkle strategy
assertion, reproduced on clean base b255f1d. A separate verification run executes
all scripts and compares failing old scripts with the clean base; its final
results are stored outside the source tree with the user's project notes.

Before distribution, perform a live match in compatible Game Room clients and
listen to the four cues on headphones. The left-shot recording has a lower
measured RMS than the other flight cues; no arbitrary gain boost was applied.
