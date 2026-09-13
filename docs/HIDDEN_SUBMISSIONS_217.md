# Local answer storage — build 217

This fixes Game Room's handling of a reported Windows `EACCES` during ELTEN's
temporary-file replacement. One stack occurred in cleanup after a confirmed
Quiz Party reveal; the other in preparation of a bot's answer. Cleanup refers
to the private local envelope, not deleting the answer or score from the game.

## Changes

- `ProgramStorage` skips writes for unchanged state, particularly repeated
  `discard` calls after the entry is gone.
- Read/modify/write is coordinated between screens of the same Program.
- The usual file remains `hidden_submissions.json`. If an I/O error prevents
  writing it, storage attempts `hidden_submissions.json.recovery.json` in the
  same private app-data directory, using the same host storage API.
- Snapshots carry an increasing `storage_revision`. Reading chooses the newest
  complete snapshot, so the recovery file survives screen/application restarts
  and an old main file cannot undo a successful deletion. The next successful
  main-file update supersedes the older recovery snapshot. Existing files
  without a revision are read as revision zero.
- No original file is explicitly deleted or truncated to force replacement.
  A new answer is returned to the game only after a successful durable write.
  Previous versions/nonces remain available for an already-accepted commitment.
- If both paths fail, preparation returns a controlled error and no event plan.
  The human gets a short retry message. The bot follows the existing rejected
  action path; this is not logged as a bad strategic choice on every check.
- Cleanup failure returns false instead of interrupting automatic progression.
  The stale private envelope may remain until a later successful cleanup.
- After both writes fail, disk-write attempts are suppressed for one second
  when existing code checks again. There is no sleep, new polling loop, network
  request, or delay for normal play. A single warning is logged until recovery.

Quiz Party and Categories catch this shared storage error when preparing their
answers. No Categories failure was reported by the user; its changes are shared
storage protection and regression coverage, not a claim it previously failed.
There are no changes to game rules, scoring, bot strategy, commit/reveal wire
format, LiveSessions, focus, or installed ELTEN code.

## Verification and limits

Targeted tests reproduce a real Windows file-replacement denial using a native
read handle without delete sharing, on disposable test files. They verify
fallback, reopening storage, retaining accepted older commitments, cleanup,
both-path failure, retry, no-op writes, and concurrent local transactions.

Quiz tests exercise four offline native-transport readers, cleanup during
scoring, the next question, failed human and bot preparation, the actual screen
bot-error branch, and successful recovery. Categories tests retain its existing
rules tests and cover nine categories across the file boundary and cleanup.
This is not a test of four running ELTEN clients or a formal proof of all I/O
failure modes. Separate ELTEN processes sharing one profile are not a supported
multi-writer storage setup; the transaction lock is in-process.

The user later reported that normal mode worked after restarting ELTEN.
Inspection found no developer-mode branch in the host JSON write path. That
observation does not distinguish a developer-mode interaction from a transient
lock released by restart. The process responsible for the original denial was
not identified; do not attribute it to antivirus, MCP, or developer mode as a
confirmed cause. This build hardens the reproduced failure at Game Room's
boundary; it does not claim to fix Windows or ELTEN's file writer.

For manual testing use the new package, preferably a new quiz. Both file formats
are local implementation details; older builds do not read a recovery snapshot.
No profile answer files are distributed in the package. Quiz content provenance
limitations from `QUIZ_PR3_FIXES.md` and `content/QUIZ_DATA_NOTICE.md` remain.
