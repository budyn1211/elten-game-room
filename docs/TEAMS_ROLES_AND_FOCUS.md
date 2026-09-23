# Teams, participant roles and stable room focus

Team selection is a room setting, not an implicit game start. The owner opens
Choose teams from the room menu, or reaches it on the first start with an
unconfirmed roster. Tab visits the player list, Choose teams randomly and Accept.
Enter on a player changes their team; Shift+Up/Down reorders people without
wrapping. Escape cancels. Accept validates and saves the choice, then returns to
the room. A separate Start game starts the match.

`team_players` ties `team_seats` to identities. A reordered roster is remapped;
a different participant or incompatible team size requires a new confirmation.
Changing an unrelated table setting preserves the line-up. The single confirmed
options record supplies the shared, localized announcement naming every team.
There is no additional announcement write or server-table migration.

The owner may change another connected human's next-game role through the Users
context menu. A targeted `room_role` includes `subject`; both the repository and
the received-record validator require the actual owner. Ordinary self-role
records keep their existing shape. Bots cannot become observers. An active
match's stored roster is never modified. A user may still choose their own role.
Games that disallow role selection keep that restriction. Legacy clients reject
targeted records rather than applying the role to the owner: participants should
update together to use this feature.

The common layout preserves chat/history/users focus across phase changes and
new sessions. Existing controls are reused; drafts, selections and history
anchors are not replaced. Board/status transitions keep their original focus
behaviour. Waiting-room history and game history use the same room shell.

Pong stores a spectator's listening seat separately from its playable seat.
Position announcements use the listening seat but it never authorizes input.
The final audio result uses that seat's team, just like the spoken score.

Tests cover these boundaries with production repositories and an in-memory
LiveSessions broker, malicious records, late readers, actual room workflows,
and native ELTEN text controls offline. They are not a live network/UI test.
