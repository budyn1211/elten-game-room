# Notification presentation without repeated settings/storage access

## Confirmed blocking work

On 24 September 2026, profiling in two running ELTEN instances found two
avoidable synchronous operations in `EltenGameRoom.map_game_room_notification`:

1. `normalized_settings` reopened `settings.json` for every mapping. Contact
   filtering on receipt and the managed sound callback reopened it again;
   list rendering and widget visibility could add further reads.
2. `sound_asset_path` materialized/looked up a filesystem path even though the
   managed player subsequently played the embedded asset directly from memory.
   The path was not used by that player.

The existing receipt writer was already asynchronous. This change does not add
another writer, modify the wire format, or change the host's notification API.

Corrected before-probes measured one mapping at 400.425 ms and 367.424 ms.
Within those totals, settings normalization/read took 258.233/244.394 ms and
sound-path lookup/materialization took 121.014/114.663 ms. TracePoint wrapper
durations are inclusive: do not sum nested `read_json`/`materialize_asset` entries.
These probes confirm blocking work, not the precise entire 1–2 second incident
reported by the user.

## Implementation and invalidation

- Localization already reads preferences at application startup. Share that
  one read with the notification/settings snapshot instead of reading again
  on the first notice. No timer or settings-file polling is added.
- The class publishes a detached, recursively frozen normalized snapshot. A
  notification, contact check, list mapping or volume lookup reads it in RAM.
- All five explicit settings writes go through `update_game_room_settings`:
  the general settings dialog, Pong settings, Audio Ball settings, widget table
  presets and volume shortcuts. Publish only after a successful host write.
  Failed writes cannot silently change effective filters or volume.
- An explicit `game_room_settings(reload: true)` publishes fresh file values.
  Changes from outside this running application require an explicit settings
  reload or application reload/restart. Normal UI edits take effect immediately.
- Keep lazy initialization for environments without a startup runtime, such as
  older test fixtures. Normal ELTEN startup initializes the snapshot eagerly.
- With managed playback, supply the logical sound name and create its sound
  only through the existing presentation getter. Retain the filesystem-path
  fallback for a host without managed playback. DND/suppression and one-shot
  playback behavior remain unchanged.

The initial receipt-file read at account/receiver initialization is unchanged;
this fix does not claim that all cold application startup is free of disk I/O.
No speech or audio is moved to a worker, and no UI is called from a worker.
No change to subscriptions, expiration, joining cleanup, server schemas or
ELTEN sources is required.

## Verification

32 existing/new targeted scripts plus `notification_startup_test.rb` cover
mapping, delivery, duplicate suppression, list cleanup, sounds, contact filters,
failed/successful saves, explicit reload, widget preferences and binary loading.
The fast-path regression denies settings and asset-path storage access after
startup. It also checks 100 duplicate receives without repeated sound. The
startup regression checks the single shared read and detached preferences.

An isolated probe ran the exact new four class-method bodies inside each live
client, using its actual notification presentation, receiver and localization.
No production method was hotloaded or replaced; `_` in the probe delegates to
the same translator. No notification was sent/received, sound played or table
created by this probe. For 100 mappings per client:

| Client | First mapping | Median | Maximum | Storage calls |
| --- | ---: | ---: | ---: | ---: |
| Main | 0.195 ms | 0.018 ms | 0.195 ms | 0 |
| Test | 0.357 ms | 0.054 ms | 0.357 ms | 0 |

The one startup settings read remains separate (270/218 ms in those probes).
Results concern the mapping stage, not end-to-end delivery, an auditory test or
all possible causes of UI stalls. Both accounts run on one PC/connection.

Private artifacts: `diagnostics/table-notice-ui-237/` in the parent workspace.
Earlier helper errors and corrected readings remain documented separately.
No full suite rerun, new package, installation, version/changelog edit or
publication was performed for this change. Previously hotloaded background
gameplay fixes remain in both clients; this new fix is in sources only.
