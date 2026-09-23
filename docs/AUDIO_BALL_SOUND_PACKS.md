# Local Audio Ball sound packs

Source-only addition after the re-signed 2.0.3/build 237, 23 September 2026.
No installer, version, changelog, server schema or live profile was changed.

Ctrl+P, **Audio Ball settings**, now has listening side and a sound-pack list:
Default (the existing pack) or Sounds from Audiodisc. Save writes
`audio_ball.sound_pack` (`default` / `audiodisc`) through the existing local
settings transaction. Cancel leaves the current sounds untouched. Old or
malformed preferences select the default. It is not a shared table option.

| Cue | Default | Audiodisc source / runtime asset |
| --- | --- | --- |
| Up / W flight | audio_ball_up | discUp.ogg / audio_ball_audiodisc_up |
| Left / D flight | audio_ball_left | discCenter.ogg / audio_ball_audiodisc_center |
| Down / S flight | audio_ball_down | discDown.ogg / audio_ball_audiodisc_down |
| Prepare | audio_ball_prepare | rocketReady.ogg / audio_ball_audiodisc_ready |
| Successful defence | ball-stopped.ogg / audio_ball_stopped | rocketStop.ogg / audio_ball_audiodisc_stop |
| Agreed goal effect | existing Pong effect variants | rocketGoal.ogg / audio_ball_audiodisc_goal |

The goal voice and recorded score sequence remain the existing implementation.
Sound-pack changes do not restart or clear pending score announcements, alter
serve pauses or send network/game events. Only accepted, deduplicated `defend`
transitions play the stop cue, on both players and observers. Arming or missing
a defence, snapshots and replay do not invent catches. Current game volume,
mute and local listening side apply to the new cues as to the old ones.

Flight loops and one-shot cues are cached as managed host streams. Preference
changes load a new pack only on closing Ctrl+P, not in the flight frame loop.
Switching back reuses handles. Close releases all loaded packs and announcements.
The default retains its original recordings except for the requested new stop cue.

The audio tutorial under Ctrl+F1 previews the selected pack: the three flights,
preparation and successful defence. Its optional per-entry asset resolver is
shared infrastructure, so static tutorials in other games are unchanged.
Polish and English rules explain that path and the Audiodisc nostalgia option.

## Audio files and provenance

Seven source Vorbis files supplied by the user were converted using
`tools/encode_audio.rb`: Opus 144 kb/s VBR, 48 kHz, 20 ms, libopus audio,
complexity 10. Stereo and metadata were retained. No gain change, downmix,
trimming or loudness normalization. Original source hashes stayed unchanged.
Full decoding and duration comparison succeeded for all seven outputs.
Both manifests declare the new IDs; the normal release allowlist includes
them and the new Ruby module without diagnostic/development files.

The supplied folder names identify provenance, not licensing. Author/source
IDs and public redistribution rights for these seven files are unconfirmed;
see `THIRD_PARTY_NOTICES.md`. Existing recordings keep their existing notices.

### Follow-up: trim the default successful-defence cue (23 September 2026)

At the user's request, only `audio_ball_stopped.opus` was shortened: removed
196.458 ms from the beginning and 39.438 ms from the end of `ball-stopped.ogg`.
The measured PCM duration is now 364.104 ms, previously 600 ms. The trim uses
a -55 dBFS boundary threshold in either stereo channel and a 2 ms guard;
only contiguous boundary samples below that threshold were removed. Stereo, level and pitch
are preserved, with no normalization or dynamics filter. Re-encoded from the
untouched original using the existing Opus 144 kb/s VBR, 48 kHz, 20 ms defaults.
The Audiodisc cue and all other assets/timing remain unchanged. Local source
backup and detailed measurements are outside the repo under
`../artifacts/game-room/source-audio/before-audio-ball-stop-trim-237/` and
`../diagnostics/audio-ball-stop-trim-237/`. Same 2.0.3/build 237 and changelog.
Current `audio_ball_stopped.opus` SHA-256:
`1399149ffa3c70d327a2a1ae941f7171f4f104984e6c93a5a4469c09b1ced27d`.

## Verification

Targeted offline coverage: audio streams/pack changes/muting/score queues,
accepted local/remote/observer catches and duplicates, Ctrl+P persistence,
binary source loading with PL/EN/fallback, native dialog/help controls,
tutorial playback and static entries. No actual device playback, active
ELTEN installation or live network match was performed for this change.

## Widget Ctrl+J

The main-screen widget binds Ctrl+J only while active, using native exact
modifier/first-press detection and consuming the key before character search.
The same action is in its local menu/help. A shared dialog guard prevents
reentry or discovery refresh during the invitation picker.

`accept_invitation_from_widget` prepares the application, calls the existing
`switch_to_invited_table`, catches its ordinary table-switch result, and opens
the normal interface. It does not duplicate invitation discovery, admission,
join or notification-cleanup code. Multiple invitations, cancelled selection,
expiry, public/private access and cleanup retain the existing common behavior.
