# New default Audio Ball flight sounds — 23 September 2026

Only the default pack's three flight loops are replaced. High is Up/W,
middle is Left/D, low is Down/S. Asset IDs remain `audio_ball_up`,
`audio_ball_left`, `audio_ball_down`; no changes to mappings, tutorial,
local preference, pan, volume controls, physics, clocks, or network.
Preparation, stop, goal, score voices and the Audiodisc pack are unchanged.

Sources supplied by the user: `ball-high.ogg`, `ball-middle.mp3`,
`ball-down.ogg` in Documents/Freesound. Original files remain unchanged.
Prior game assets are backed up outside the repository and installer.

Current encoded SHA-256 values (not the historical recordings' checksums):

- `audio_ball_up.opus`: `737b12fd79acbe273efd6f9ef52facc82588d57722f84ab247ad4e4650f52886`.
- `audio_ball_left.opus`: `5441c530bbba9d7c976695e07b620df0e7e8ca0c5baa9e48f7052ac08c76c794`.
- `audio_ball_down.opus`: `dd061ac452a4bb7b008182ba88753a1fcdd76bba81022f19dd9c3b7b1a3691de`.

## Processing explicitly requested by the user

- Stereo folded to mono as 0.5 L + 0.5 R; low sound was already mono.
- Only contiguous leading/trailing silence below -55 dBFS was removed,
  retaining a 2 ms guard. No removal of pauses inside a recording.
  Removed: high 0/13 ms, middle 300/28 ms, low 0/44 ms (start/end).
- Offline dynamic leveling: dynaudnorm, 50 ms windows, smoothing 5,
  peak 0.8, maximum gain 20, RMS target 0.16, boundary mode, compression 5.
  Then measured loudness normalization with target -19.9 LUFS.
- Target is the mean loudness of all three Audiodisc flight sounds folded
  to mono for a comparable per-speaker level, not their louder stereo sum.
  Encoded results measure -19.91/-19.92/-19.92 LUFS; true peaks are below
  -4.8 dBTP. Short-term 100 ms level spreads (p90 minus p10) decreased from
  11.6/19.6/10.3 dB to 3.6/4.3/5.8 dB. Natural texture/transients remain;
  this is not an identical amplitude in every sample.
- Encoded once from the original lossy sources (no lossy intermediate),
  Ogg Opus 144 kb/s VBR, 48 kHz, 20 ms, libopus audio, complexity 10.
  Existing authoring arguments and metadata-copy flags retained.
  No pitch changes. Durations: 8.135/4.262/6.038 s.

Inspection and repeatable preparation scripts, full measurement records,
original/output SHA-256 and the unsuccessful intermediate diagnostic runs
are outside the repo in `../diagnostics/audio-ball-input-sounds-237/`.
Those initial errors were text-mode PCM capture/JSON extraction in the
measurement helper, not corrupt audio or application failures.

Matching perceived loudness is an objective approximation, not a listening
test. Confirm balance and timbre by listening in the game. The directory
contains three plausible Freesound license sidecars, but renamed source
files have no identifying metadata. Credits are preserved in notices;
the exact attribution mapping must be confirmed before public distribution.
