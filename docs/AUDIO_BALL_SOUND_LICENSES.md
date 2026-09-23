# Audio Ball sound sources and changes

## Attribution for distribution

The supplied Freesound `preview-hq-ogg` downloads are the source recordings.
Attribution and license details below were read from their adjacent `.license.txt`
files. The source files were not changed. All shipped derivatives are Ogg Opus.
This document is a development record; `docs/` is not included by the release
allowlist. Include the attribution and changes in `THIRD_PARTY_NOTICES.md` before
shipping a package. No manifest or shared notice file is changed by this audio work.

- **`Audio/audio_ball_up.opus`**: “BallHit.wav” by **minerjr**.
  Source: https://freesound.org/s/89977/
  License: **Creative Commons Attribution 3.0 Unported (CC BY 3.0)**,
  https://creativecommons.org/licenses/by/3.0/
  Changes: converted the supplied lossy Ogg Vorbis preview to Ogg Opus,
  resampled from **44,100 Hz to 48,000 Hz**, and renamed the asset. Mono retained.
  No trimming, normalization, gain change, or pitch change was applied.
- **`Audio/audio_ball_left.opus`**: “PlasticBall_In_Cooler_11” by **loganzsound**.
  Source: https://freesound.org/s/774205/
  License: **CC0 1.0 Universal**,
  https://creativecommons.org/publicdomain/zero/1.0/
  Changes: converted the supplied lossy Ogg Vorbis preview to Ogg Opus,
  downmixed stereo to mono using **0.5 * L + 0.5 * R**, and renamed the asset.
  The 48,000 Hz sample rate was retained. No trimming or normalization was applied.
- **`Audio/audio_ball_down.opus`**: “Boulder Roll” by **sound368**.
  Source: https://freesound.org/s/807186/
  License: **CC0 1.0 Universal**,
  https://creativecommons.org/publicdomain/zero/1.0/
  Changes: converted the supplied lossy Ogg Vorbis preview to Ogg Opus,
  downmixed stereo to mono using **0.5 * L + 0.5 * R**, and renamed the asset.
  The 48,000 Hz sample rate was retained. No trimming or normalization was applied.
- **`Audio/audio_ball_prepare.opus`**: “auto real older car door close rattly.wav”
  by **kyles**.
  Source: https://freesound.org/s/452549/
  License: **CC0 1.0 Universal**,
  https://creativecommons.org/publicdomain/zero/1.0/
  Changes: converted the supplied lossy Ogg Vorbis preview to Ogg Opus and
  renamed the asset. Mono and 48,000 Hz retained. No trimming, normalization,
  gain change, or pitch change was applied.

The fourth recording, marked “prepare attack”, was present when the source folder
was inspected. It is used for preparation, not a fabricated or unrelated fallback.
Missing flight/preparation assets still degrade gracefully to silence. Goal
effects and score voices now reuse the existing Axel Pong assets, unchanged,
with their existing shipped attribution. Recorded score numbers cover 0..21;
higher scores or missing required recordings use Elten speech. Ordinal set
announcements and ten-second warnings remain synthesized.

## Original filenames and checksums

These names are preserved verbatim, including the unusual spelling of the left cue.
Checksums are SHA-256 of the supplied files before and after conversion; both matched.

### Up

- File: `89977_BallHit_preview-hq-ogg up arrow.ogg`
- Sidecar: `89977_BallHit_preview-hq-ogg.ogg.license.txt`
- Source SHA-256: `105db171a9cfcebd2b4f196fbfc0917c4f0760f1717ae7d4a45df135eabf0e67`
- Output SHA-256: `e5418387b86a9dde0103fe1f80af90f74a1ca2646a65017be5a1df3ad7ed9575`

### Left

- File: `774205_PlasticBall_In_Cooler_11_preview-hq-og left arrowg.ogg`
- Sidecar: `774205_PlasticBall_In_Cooler_11_preview-hq-ogg.ogg.license.txt`
- Source SHA-256: `90ba387954a4d8dbbebc64e62bf11facc660a7b7b08f682c15894401c87f0334`
- Output SHA-256: `79aba0c2c956c66353fcdf8d8b9e02c0a748f11ce9de82d4071d3c20be553860`

### Down

- File: `807186_Boulder Roll_preview-hq-ogg down.ogg`
- Sidecar: `807186_Boulder Roll_preview-hq-ogg.ogg.license.txt`
- Source SHA-256: `34618afa8349d5bf90abbd3bfc7003eee7c941b5d24f7053cedc9a2fc631bcf0`
- Output SHA-256: `2625deda7e634fb80062be0c434ee38499041464cafec2be4c6575ef0fd26181`

### Prepare

- File: `452549_auto real older car door close rattly_preview-hq-ogg prepare attack.ogg`
- Sidecar: `452549_auto real older car door close rattly_preview-hq-ogg.ogg.license.txt`
- Source SHA-256: `0c9b791107e16290a36600ecb372ce8505919060f7f56aa401926b85fb10bf40`
- Output SHA-256: `44ebfba733bad10c6e6f785cf1f868fa5f59764ee2105453a0d45f20bcb498f7`

## Encoding and technical inspection

Encoder: FFmpeg `8.1.2-full_build-www.gyan.dev`, libavcodec `62.28.102` / libopus.
The `tools/encode_audio.rb` authoring arguments were used:

```text
-map 0:a:0 -vn -map_metadata 0 -map_metadata:s:a:0 0:s:a:0
-c:a libopus -b:a 144k -vbr on -application audio -compression_level 10
-frame_duration 20 -ar 48000 -f opus
```

Mono source files used `GameRoomAudioEncoding.encode` directly. The two stereo
sources used `GameRoomAudioEncoding.arguments` with the additional filter
`-af pan=mono|c0=0.5*c0+0.5*c1` and no-overwrite protection. Each target was encoded
once from its original preview. No intermediate lossy conversion was made.
Metadata copy flags were retained; ffprobe found no source stream tags, and the
outputs have the generated encoder tag. Existing source licenses remain in the
sidecars and the attribution above.

Mono makes the pan parameter apply to a single source, rather than relying on
balance of a stereo field. No seam repair, fading, gain balancing, or normalization
was added. The clips loop only for a flying ball; preparation is a one-shot.

| Cue | Source codec / rate / channels | Source duration (s) | Output bytes | Opus container duration (s) | Decoded mono samples at 48 kHz | Decoded duration (s) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Up | Vorbis / 44,100 Hz / 1 | 0.829206 | 18656 | 0.835708 | 39802 | 0.8292083333333333 |
| Left | Vorbis / 48,000 Hz / 2 | 1.562500 | 32223 | 1.569000 | 75000 | 1.5625 |
| Down | Vorbis / 48,000 Hz / 2 | 0.806500 | 14883 | 0.813000 | 38712 | 0.8065 |
| Prepare | Vorbis / 48,000 Hz / 1 | 0.417083 | 8538 | 0.423583 | 20020 | 0.4170833333333333 |

All outputs are **Opus, mono, 48,000 Hz**, authored at **144 kb/s VBR**, 20 ms
frames, audio application, complexity 10. Container bit rates vary with VBR and
Ogg overhead; they are not fixed 144 kb/s measurements. Regular packet durations
were 20 ms; final packet durations reflect the end of each short recording.
The reported container durations include the 312-sample Opus pre-skip. Full PCM
decoding removes that delay. Decoded sample counts match those of the corresponding
source decoded/resampled/downmixed at 48 kHz; no recording tail was truncated.

Full decoding with `ffmpeg -v error -xerror` succeeded for all four source files
and all four outputs, with no reported decode errors. Decoded output peak absolute
amplitudes / RMS dBFS were:

- Up: `0.4256035387516022` / `-23.694477110662568`.
- Left: `0.20237493515014648` / `-37.39163008164297`.
- Down: `0.30629149079322815` / `-21.101593614910964`.
- Prepare: `0.5421910285949707` / `-26.7748037183941`.

The left recording has a lower measured RMS level; it was not boosted. These are
technical checks and sample measurements, **not a live audible playback test** or
a claim that the loop seams are perceptually seamless.

## Audio integration contract

`GameRoomAudioBall::Audio.new(program, speaker: nil)` loads and manages the four
streams once; `load` is an idempotent public compatibility method. `ASSETS`, `SHOTS`,
and `PREPARE` expose extension-free names. The host supplies
`create_sound_from_asset(name, sample: false, loop:)` and the normal Sound
`pan`, `volume`, `position`, `play`, `pause`, `playing?`, and `close` API.
Optional `manage`/`release` and private Game Room volume/enable hooks are supported.

- `update(snapshot, viewer:, paused: false)` tracks string-keyed engine snapshots.
  The current shot is the only loop; both attack directions are audible. Side 0
  position 25 is pan +1, position 0 is pan -1; viewer 1 mirrors it. Unchanged frames
  update pan/volume without restarting. New shot/turn identities restart once.
- `prepare(side, viewer:)` explicitly plays one positioned cue. Prepared frames
  allow its tail to finish; they do not retrigger it. Starting a shot stops it.
- `point(scores, sets:, set_finished:, winner:, viewer:, finished:)` silences effects
  and speaks scores in listener order, followed by set totals/results when needed.
  `viewer: nil` uses canonical order and neutral player-number results.
- `announce_set(number)` speaks “First set.” through “Fifth set.”; `hurry(player)`
  speaks “%{player}, you have 10 seconds left.”. Callers deduplicate these explicit
  event methods. No polling speech, extra recorded announcer, or speech timer exists.
- The default speaker calls `speak(text, stop: false, break_sequence: false)`.
  All spoken source text is English through `_()` and converted to UTF-8; names
  and translated templates are normalized before formatting the warning.
- `silence` pauses effects and forgets flight identity. `reset` also rewinds all
  handles. `close` is final and idempotent, releases/closes each handle once, and
  ignores late speech/cue calls. Create a new Audio instance for a new closed client.

Automated coverage is in `test/audio_ball_audio_test.rb` and uses the real Audio
class with fake host sound handles. Device playback, network matches, installation,
packaging, publishing, and shared manifest changes are outside this audio task.
