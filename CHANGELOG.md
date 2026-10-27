# Changelog

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
