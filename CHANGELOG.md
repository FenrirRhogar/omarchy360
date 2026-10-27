# Changelog

## Unreleased

- README: douze's API now answers only the desktop user (douze `9af049d`,
  after a marketplace review pointed out that other local users and web pages
  could reach it). Use that douze or later.

## 0.4.0 — 2026-10-27

- Apps page: send an app to **any combination** of SSL outputs with four
  toggles: SPK, HP A, HP B, L 3-4. An app heard anywhere but the speakers alone
  gets a spare playback pair (3-4, 5-6, 7-8) to itself, and the card's mixer
  copies it to the chosen outputs (no DIR, no extra latency). An output that
  follows the speaker mix but should differ gets its own mix, copied from the
  speaker mix first, so mics and other sources stay as they were.
- The device row picks between the SSL 12 and the computer's other outputs.

## 0.3.2 — 2026-10-27

- With DIR on, a playback pair's strip is locked on its own bus's view
  (PLAY 5-6 on HP A, PLAY 7-8 on HP B, PLAY 3-4 on LINE 3-4) and reads
  "DIR → …": DIR already sets that level to 0 dB.

## 0.3.1 — 2026-10-27

- While an aux output follows MIX 1-2, its strips' faders, pans and on/off
  buttons are locked and greyed out (they had no effect anyway) and read
  "follows MIX 1-2".
- The per-strip button on aux buses reads **ON HP A / OFF HP A** (etc.)
  instead of SEND ON / SEND OFF.

## 0.3.0 — 2026-10-27

- Apps page: pick each app's output. The choices are speakers, line 3-4,
  HP A or HP B on the SSL 12 (douze's stereo outputs), or any other sound
  device. Picking line 3-4, HP A or HP B turns that playback pair's DIR on, so
  the sound reaches the jack.
- DIR fix: an output with FOLLOW MIX 1-2 on copies the main mix and ignores
  everything else, DIR included (measured on the card), so DIR did nothing on a
  following output. DIR now switches that output's FOLLOW off, and gives it back
  when DIR is switched off.

## 0.2.0 — 2026-10-27

- Send pan: with HP A, HP B or LINE 3-4 selected, each strip's pan slider pans
  its send to that bus. On LINE 3-4 the ends read 3 and 4 and choose the
  output, so every one of the card's 8 output channels can get its own mix.
  Linking a pair also spreads its sends hard left/right. Needs douze with the
  `send_pan` extension.

## 0.1.1 — 2026-10-27

- Line 3-4 are two mono outputs on the SSL 12. The AUX bar now has a separate
  FOLLOW MIX 1-2 and level for OUT 3 and OUT 4. Before, FOLLOW only reached
  output 3, so output 4 stayed silent. Needs douze with the `line4` extension;
  otherwise the bar keeps the single control.

## 0.1.0 — 2026-10-26

First public release.

- Mixer page for the SSL 12 via douze: Analog 1–4 (48V / LINE / HPF / Ø),
  talkback, Playback 1-2 … 7-8 (DIR), meters, faders, pan, SOLO, CUT.
- Stereo link for Analog 1-2 / 3-4 and ADAT pairs.
- Cue mixes for HP A, HP B and Line 3-4, with FOLLOW MIX 1-2, CUT, MONO and level.
- Monitor section: DIM, CUT, MONO, ØL, ALT, TALK, ALT SPK, dim level, ALT trim.
- Front-panel USER button mapping, including **gui** to open the mixer.
- Loopback source and profiles (load / save / save as / delete).
- ADAT 1–8 strips (experimental).
- Apps page: per-app volume, mute and meters from PipeWire.
- Hides features the running douze doesn't announce in `_features`.
