# Invitation history correction — 1.1.10/build 226

Sending an invitation and declining it are room activities (`invited` and
`invitation_rejected`), displayed and announced through the existing merged
room/game history. These kinds are explicitly excluded from global lobby
activity, for both public and private tables. Failed or duplicate delivery
does not create a sent event. Successful delivery retains the duplicate lock
even if its history write has a temporary failure.

An invited outsider cannot write to a private room stack. The existing durable
`game_room.invitation_resolved` reply is retained as a technical receipt; the
inviter's original authenticated room connection records the decline. Matching
requires the locally sent invitation ID, table ID, native session UUID when
provided, recipient, actual notification sender and current account. Declining
does not join or reopen a room. Closed rooms consume the reply without writing
new activity. The ordinary private authorization/rejection API is unchanged.

Receipt processing is a bounded, event-driven background job, carrying the
application runtime. It records a missing sent event before a decline, clears
the duplicate lock, then revokes the receipt and its local cached row. A failed
history write leaves the receipt for retry. Stable native message IDs plus a
per-invitation writer mutex prevent duplicate history after lost HTTP replies
or concurrent deliveries. Temporary failures have three bounded attempts;
there is no timer, new polling loop, new Signals channel or form rebuild.

`suppress_default!` only prevents automatic presentation in ELTEN; it does not
remove rows from its notification lists. A Game Room-owned `NotificationGroups`
bridge therefore filters only this application's technical resolved/rejected
types, including legacy duplicate rejection notices. It also schedules unread
receipts found on list catch-up. All normal invitations and other applications'
notifications remain intact. Mapping has no invitation-state side effects.
No ELTEN source or saved QuickActions is changed.

Expiration behavior is deliberately unchanged, as requested. There is no
promise that the separate host expiration issue has been resolved.

The existing build 226 changelog is preserved with one additional English
point and its Polish translation, under the same version/build heading.
Targeted offline regressions include real host notification classes, grouping
and callback methods, native multiplayer transport, private/fresh endpoints,
lost replies, retry idempotence, account/authentication checks, closed rooms,
translations and binary loading of the signed package. No full runner or live
client modification is needed to build the test package.
