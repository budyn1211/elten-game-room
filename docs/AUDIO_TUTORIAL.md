# Audio tutorials

Ctrl+F1 opens the rules menu in the waiting room and during a game. Audio tutorial
is its last item when the game supplies sounds; it is also available from the
rules library. Games without entries keep their existing menu.

The tutorial is one native list. Arrow keys browse without autoplay. Enter or
Space plays the selected recording from the beginning, replacing the previous
sound. Changing selection or pressing Escape stops playback. Escape returns to
the same rules-menu item. The welcome is spoken before the first item as one
initial focus announcement, without a separate dialog or text field. Later
navigation and refocusing do not repeat it. Playback uses ELTEN's asset player
and Game Room sound settings.

## Adding another game

Override `audio_tutorial_entries` in the game class. Return an ordered array of
`GameRoomAudioTutorial::Entry.new(label: _("Description and controls"), asset: "asset_name")`.
The default implementation in `GameRoomGames::Base` returns an empty array.

Use the existing asset name without `Audio/` or an extension. Declare any new
assets in both release manifests as usual. Add UI messages with
`ruby tools/translations.rb update`, edit only `locale/PL.po`, then run
`ruby tools/translations.rb compile PL`. See `locale/README.md`.
No extra condition in the rules screen or game-specific UI class is needed.

Audio Ball supplies its three shot sounds and the preparation sound. They are
single, centered previews of the recordings, not a simulated flight or a change
to the match. The tutorial never submits game actions or changes table options.

## Verification

Run `test/audio_tutorial_test.rb`, `test/audio_tutorial_integration_test.rb`,
`test/audio_tutorial_localization_test.rb` and `test/audio_tutorial_native_test.rb`.
The native test needs `ELTEN_HOST_SOURCE` (or the sibling `elten3` checkout).
Localization also accepts an actual installer argument and supports the existing
`ELTEN_DICTIONARY_SOURCE` setting for the host dictionary implementation.
These offline tests do not replace an audible test in ELTEN with NVDA.
