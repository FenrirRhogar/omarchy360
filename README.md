# Omarchy360 for SSL 12

A terminal-style mixer for the **Solid State Logic SSL 12** audio interface,
as an [Omarchy](https://omarchy.org) shell plugin. It covers on Linux what the
vendor's control app does on Windows and macOS: input and playback strips, cue
mixes for the headphone and line outputs, the monitor section, front-panel
button mapping and profiles. A second page holds per-app volumes.

![Omarchy360 mixer page](preview.png)

The card itself is driven by [douze](https://github.com/xenicle/douze), a
reverse-engineered daemon for the SSL 12's USB control interface. This plugin
is a front end for it: it never talks to the card directly.

> Omarchy360 is an independent project. It is not affiliated with or endorsed
> by Solid State Logic. "SSL" and "SSL 12" are used only to name the hardware it
> works with.

## Features

**Mixer page** (tab 1)

- Strips for Analog 1–4 (48V, LINE/INST, HPF, Ø), the talkback mic, and
  Playback 1-2 … 7-8 (DIR to its fixed output on 3-4, 5-6, 7-8). Each strip has
  the card's own meter, a fader (−∞ … +12 dB), pan, SOLO and CUT.
- **Stereo link**: join Analog 1-2, 3-4 (or ADAT pairs) into one stereo strip.
- **Cue mixes**: pick MIX 1-2, HP A, HP B or LINE 3-4 at the top. On an aux bus
  the faders set that bus's sends, and the AUX bar has its FOLLOW MIX 1-2, CUT,
  MONO and level. With FOLLOW on, the bus copies the main mix.
- **Monitoring**: bus meters, monitor level, DIM, CUT, MONO, ØL, ALT, TALK,
  ALT SPK, dim level, ALT trim.
- **USER buttons**: assign the front-panel CUT / ALT / TALK keys to dim, cut,
  mono-sum, alt, invert-l, talkback or **gui** (opens this mixer, see below).
- **Loopback** source and **profiles** (load, save, save as, delete).
- ADAT 1–8 strips (hidden by default, `+ ADAT 1-8`).
- Presses on the card's buttons show up live.

**Apps page** (tab 2): volume, mute and peak meters for every app playing or
recording, straight from PipeWire.

**Keys**: `1`/`2` or Tab switch pages, ←/→ switch the fader bus, Esc closes.
Faders: drag, scroll (±0.5 dB), double-click for 0 dB.

## Status

Tested on one SSL 12 (firmware 1.41) with Omarchy's Quickshell 0.3.2 and
PipeWire 1.6. douze itself was developed on firmware 1.44.

| Area | Status |
| --- | --- |
| Strips, preamp keys, monitor section, USER mapping, loopback, profiles, meters | tested |
| Cue-mix sends, FOLLOW / CUT / MONO, stereo link | tested |
| Talkback meter, front-panel **gui** button | tested on firmware 1.41 only |
| ADAT 1–8 | **experimental** — douze's presumed mixer slots, never tested with an optical source |
| The card's talkback level and routing | not controllable: they live in the firmware |

## Requirements

- An SSL 12 on its **Pro Audio** profile in PipeWire.
- **douze** with the `bus_modes`, `ui`, `gui` and `adat` extensions. These are
  proposed upstream to [xenicle/douze](https://github.com/xenicle/douze);
  until they are merged, use the `omarchy360` branch of
  [FenrirRhogar/douze](https://github.com/FenrirRhogar/douze/tree/omarchy360).
  With a stock douze the plugin still works, minus stereo link, ADAT,
  FOLLOW / CUT / MONO and the gui button, which it hides.
- `python-pyusb`, `curl`, and PipeWire's `pw-record`, `pw-link` and `pw-dump`
  (Arch: `pipewire` and `pipewire-audio`).

## Install

### 1. douze

```bash
sudo pacman -S python-pyusb
git clone -b omarchy360 https://github.com/FenrirRhogar/douze ~/.local/share/douze
```

Let your user open the card's control interface. douze ships a rule using the
`audio` group; this one grants access to whoever is logged in at the seat, with
no group membership:

```bash
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="31e9", ATTRS{idProduct}=="0024", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/70-douze.rules
sudo udevadm control --reload && sudo udevadm trigger
```

Run the daemon as a user service:

```bash
sed "s|%h/douze|%h/.local/share/douze|" ~/.local/share/douze/systemd/douze.service \
  > ~/.config/systemd/user/douze.service
systemctl --user daemon-reload
systemctl --user enable --now douze
```

When it starts, douze pushes its saved mixer state to the card (the card forgets
everything at power-off). The first time, that is douze's default: Analog 1–4
and Playback 1-2 at 0 dB in the main mix, Playback 3-8 off.

### 2. The plugin

```bash
omarchy plugin add https://github.com/FenrirRhogar/omarchy360 --enable
```

Click the three-fader icon on the bar, or bind a key in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + M", "Omarchy360 mixer", "omarchy-shell shell toggle fenrirrhogar.omarchy360")
```

### 3. Optional: open the mixer from the card

Set a USER button to **gui** in the mixer, then tell douze what to run when it
is pressed:

```bash
mkdir -p ~/.config/systemd/user/douze.service.d
cat > ~/.config/systemd/user/douze.service.d/omarchy360.conf <<'EOF'
[Service]
Environment="DOUZE_GUI_CMD=omarchy-shell shell toggle fenrirrhogar.omarchy360"
EOF
systemctl --user daemon-reload && systemctl --user restart douze
```

## What it runs

The plugin runs inside the Omarchy shell with your user's permissions. It needs
no root and starts no second shell. It:

- talks HTTP to douze on `127.0.0.1:1212` only (`curl` for the event stream);
- runs `bin/omarchy360-peaks` (Python) for meters Quickshell can't read:
  the SSL 12's pro-audio channels and app streams with unknown channel
  positions. It records with `pw-record` and, for app streams, links ports with
  `pw-link` and reads ports with `pw-dump`. Its capture nodes are named
  `omarchy360-meter*` and stop with the mixer window.

douze is the only part that touches USB.

## Troubleshooting

- **"douze offline"**: `systemctl --user status douze`, then
  `journalctl --user -u douze -b`.
- **"SSL 12 not connected"**: the card is off, unplugged, or the udev rule is
  missing (`getfacl /dev/bus/usb/*/*` should list your user for the SSL device).
- **No sound from the computer**: check the PLAY 1-2 fader and the monitor
  level; both are saved in douze's state and restored on start.
- **FOLLOW / CUT / MONO, link or ADAT missing**: your douze lacks the
  extensions; see Requirements.
- **Code changes don't show up**: the overlay stays loaded; run
  `omarchy restart shell`.

## License

MIT, see [LICENSE](LICENSE). douze is AGPL-3.0 and is installed separately.
