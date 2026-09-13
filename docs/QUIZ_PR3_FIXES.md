# Quiz Party — local integration and fixes after review

13 September 2026. PR #3 revision:
`efa6e640a57901e7b01e5ac2158e84f1c3375435`.
Integrated locally on top of the existing build-215 changes. Selected for
the 1.1.7 / build-216 test package on 13 September 2026. No GitHub merge/push,
installation or public release. The existing signed build 215 remains
unchanged and does **not** contain Quiz Party or these fixes.

## Review checklist

1. **Stale answers:** all commitment and reveal fragments now carry round
   and question coordinates. Stale UI submissions are rejected as well.
   Full SHA-256 commitments/nonces use Base64 to stay within the existing
   64-character value limit, without extra events. Concurrent answers remain
   valid; transport sequence semantics and request pacing are unchanged.
2. **Deadline:** new local submissions stop at the deadline. Replay accepts
   in-flight commitments only before the deadline plus the existing three
   seconds of transport grace, using the event timestamp. A host that is
   late to close the question no longer leaves answering open indefinitely.
3. **Lost envelope:** only an actually recoverable, verified local answer
   schedules a reveal. Missing/corrupt local data cannot starve the reveal
   timeout, including for the owner or bots. Partial/duplicate fragments
   and stale fragments have regression coverage.
4. **Observing owner:** deadline checks and execution resolve the same
   automatic actor. Integration testing also exposed a build-215 omission:
   replay lost the actor of a controlled human action. The native store now
   preserves the controller flag; the repository verifies the real author
   is the session owner and the claimed actor is in the match. Guest
   impersonation and actors outside the match remain rejected. No new
   transport, polling or membership recovery was added.
5. **Question data:** 54 records excluded (2 English, 52 Witcher), 31 cleaned.
   Remaining: 28,575 English, 15,498 Polish general, 6,571 Witcher, totaling
   50,644. Known missing-name/wiki-fragment questions, two context-dependent
   English questions and known duplicate templates no longer occur in play.
   Cleanup has positive tests and valid counterexamples. Full factual
   verification and missing original-source attribution remain limitations;
   see `content/QUIZ_DATA_NOTICE.md`.
6. **Polish:** added messages, rules, options, shared category prompts and
   Polish question-count plural forms. Existing shared translations from
   build 215 were preserved. Question language remains independent of UI.
7. **Startup:** lightweight pack metadata includes the count and checksum.
   Only a used question pack loads its data; options/rules do not load all
   three databases. Lazy loading also works through binary Ruby evaluation,
   as used at the program-package boundary.
8. **Results:** own result comes first within each question at small tables;
   larger-table observers receive counts once per question. Event history
   and viewer-specific formatting still use the existing framework.
9. **Rules wording:** removed the misleading suggestion that answering
   faster earns more points. The bot's deliberately probabilistic knowledge
   model was retained; no new difficulty system was added.

## Verification

Run `ruby tools/run-quiz-tests.rb` for the targeted suite: Quiz rules/bot,
stale/concurrent native writes across four readers, missing envelopes,
observer deadlines and controlled actions, data/builders, languages,
binary loading, shared UI and existing LiveSessions regression suites.
This is offline testing with the real game/repository/transport code and
a simulated server, not real ELTEN clients or a full project-wide test run.
All 24 targeted files passed; the local detailed run is recorded in
`diagnostics/quiz-pr3-tests.json` in the surrounding workspace.

Local startup probe on Ruby 4.0.6 measured about 0.159 s and 1.88 MiB of
additional retained Ruby objects, compared with the reviewed eager PR's
1.145 s and 34.47 MiB. These are individual source-loading measurements,
not total process RAM or a promise about actual ELTEN startup time.
