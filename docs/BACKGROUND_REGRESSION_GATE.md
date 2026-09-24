# Regression gate for foreground/background execution

The September 24 review tests the same ordinary-game executor both in the
visible form and behind native Messages/forum windows. It is not a change to
game rules, bot strength, networking protocol, or realtime physics.

## Evidence required

- Compare the committed pre-runner GameScreen and the new SessionRunner in
  isolated processes with identical seeds, clocks, player actions and options.
  Compare accepted event order, complete replay state and legal actions, not
  only a final score or a successful return code.
- Exercise human input, bot planning, automatic phases, simultaneous input,
  deadlines, failed/uncertain writes, reconnect/backoff and executor handover.
- Test the actual host controls and actual two-account transport, including
  drafts, focus, history cursors, speech/audio and no duplicate presentation.
- Include lobby join/leave/start as well as an already running game. A working
  GameScreen alone does not prove that the waiting room updates in the background.
- Pong and Audio Ball intentionally do not run their physics behind a native
  parallel window. Verify resumption and the absence of an ordinary runner.
- Retain initial failures and interrupted probes. Timeouts, incomplete helpers,
  and tests without a remote move are not passing end-to-end matches.

## Bounds and interpretation

A finite suite cannot prove every possible game state. Handler-generated input
does not test a physical keyboard, and an active sound handle does not prove a
human listening result. Two accounts on one PC share the computer and network.
Resource-intensive random traces can be bounded without implying that a legal
game should terminate within that bound. Report the actual trace length.

The full test catalogue has older failing expectations; establish their result
on the committed baseline before attributing them to the runner. Do not remove
assertions simply to obtain a green suite. Detailed private reports and retained
logs are outside the repository in `../diagnostics/regression-237/`.

## Makao regression found during this gate

An ordinary jack combined with a joker can internally test an empty joker
identity when rank requests are disabled. The empty string's split result has
no first element; the old validator called `length` on nil while enumerating
legal packets and navigation shortcuts. Reject an empty identity before splitting.
Do not remove the packet or change the rules to avoid the exception.

The exact captured 14-event live replay fails on the committed baseline and
succeeds after the guard, with 180 legal actions. The regression test covers
nil/empty/invalid identities, valid identities, every rank with a joker, action
acceptance and non-mutating hand navigation. The user explicitly approved this
older fix separately from the foreground/background work.

## Older tests repaired on user request

The initial full catalogue had 15 failures also reproducible on the exact
committed baseline. Three needed the existing GetText/Bundler environment.
The remaining scripts were repaired separately, with original logs retained:

- Match current settings, last-roll wording, independent team acceptance/start
  and preservation of chat focus at game boundaries. Keep checks for starting
  from the primary button and navigating to the final board separately.
- Select English for both the host dictionary and app translations when an
  English behaviour suite follows a binary PL/EN/fallback UI suite.
- Use the common control fixture for access checks, and let the form driver
  handle GameRoomUI::Form subclasses. Keep real button handlers under test.
- A Farkle "certain win" fixture must use the final seat under the current
  final-circuit rule. Completing two Monopoly groups is not sufficient to call
  a trade mutually beneficial: check gains and compensate the valuable blocker.
  These are fixture corrections, not changes to either bot's strategy.
- Two missing Polish translations were real omissions. Fill PL.po and compile
  PL.mo rather than suppressing the completeness check.

The full rerun has separate ALL-TESTS-FINAL.json and suite-logs-final reports.
Do not overwrite initial failures or count an unfinished process as a pass.
The completed September 24 rerun passed all 394 scripts without timeouts.
