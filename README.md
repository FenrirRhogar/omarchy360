# Omarchy360 for SSL 12

A terminal-style mixer for the **Solid State Logic SSL 12** USB audio interface,
built as an [Omarchy](https://omarchy.org) shell plugin.

On Windows and macOS the SSL 12's internal mixer, monitor section and button
assignments are set with the vendor's control app. Linux has no such app.
Omarchy360 fills that gap. It adds a bar icon (or a keyboard shortcut, or a
button on the card itself) that opens a full mixer for the card, drawn in your
Omarchy theme's colours and font.

![Omarchy360 mixer page](preview.png)

> Omarchy360 is an independent, unofficial project. It is not affiliated with,
> endorsed by or supported by Solid State Logic. "SSL" and "SSL 12" are used
> only to identify the hardware it works with.

## Contents

- [How it works](#how-it-works)
- [Features](#features)
- [Status and compatibility](#status-and-compatibility)
- [Requirements](#requirements)
- [Installation](#installation)
- [Using the mixer](#using-the-mixer)
- [Keyboard and mouse](#keyboard-and-mouse)
- [What it runs, and permissions](#what-it-runs-and-permissions)
  - [Privileged and system steps](#privileged-and-system-steps-manual-one-time)
- [Updating and uninstalling](#updating-and-uninstalling)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Development](#development)
- [Credits and license](#credits-and-license)

## How it works

```
 SSL 12 ──USB── douze (user service) ──HTTP 127.0.0.1:1212── Omarchy360 (shell plugin)
                 owns the card:                               draws the mixer, sends
                 handshake, keepalive,                        commands, shows meters
                 state, meters, buttons
```

The SSL 12 keeps its mixer in the card, but it forgets everything at power-off
and only talks once a host has done a handshake. That job belongs to
[douze](https://github.com/xenicle/douze), an open-source, reverse-engineered
daemon for the SSL 12's USB control interface. It owns the USB connection,
keeps the mixer state on disk and pushes it back whenever the card reappears.

Omarchy360 is a front end for douze's local HTTP API. It never touches USB
itself. It can still show the page when douze is down; it just tells you so.

Audio itself does not go through any of this: PipeWire plays and records as
usual. The **apps** page talks to PipeWire directly.

## Features

### Mixer page (tab 1)

- **Input strips**: Analog 1–4, each with **48V**, **LINE** (instrument/line),
  **HPF** and **Ø** (polarity) keys.
- **Talkback strip**: the built-in talkback mic's meter and the **TALK** key.
- **Playback strips**: Playback 1-2 (the computer's main output) and Playback
  3-4, 5-6, 7-8, each with a **DIR** key that sends it straight to its own output
  (Line 3-4, HP A, HP B).
- On every strip: the card's own peak meter with a 1.5 s hold, a fader from −∞
  to +12 dB, pan, **SOLO** and **CUT**.
- **Stereo link**: join Analog 1-2 or 3-4 (or an ADAT pair) into one stereo
  strip with one fader, one pan, and shared SOLO, CUT and sends.
- **Cue mixes**: HP A, HP B and Line 3-4 each have their own mix. Pick a bus at
  the top and the faders become that bus's sends. The **AUX bar** sets the bus's
  **FOLLOW MIX 1-2**, **CUT**, **MONO** and level.
- **Monitor section**: Monitor / HP A / HP B / Line 3-4 meters, monitor level,
  **DIM**, **CUT**, **MONO**, **ØL** (invert left), **ALT**, **TALK**,
  **ALT SPK** (outputs 3-4 as alternate speakers), dim level and ALT trim.
- **USER buttons**: assign the front-panel **CUT**, **ALT** and **TALK** keys to
  dim, cut, mono-sum, alt, invert-l, talkback, or **gui** (opens this mixer).
- **Loopback**: choose which mix is recorded back into the computer.
- **Profiles**: load, save, save as and delete complete setups.
- **ADAT 1–8**: optical input strips, hidden until you press `+ ADAT 1-8`
  (experimental, see below).
- Presses on the card's own buttons show up instantly.

### Apps page (tab 2)

Every app that is playing or recording, with its volume (0–150 %), mute and live
peak meters. This works with any sound card, because it only uses PipeWire.

### Opening the mixer

- the three-fader icon in the bar (click again to close);
- a keyboard shortcut you bind (see [Installation](#3-a-keyboard-shortcut-optional));
- a front-panel button on the SSL 12 set to **gui**.

## Status and compatibility

**Only the SSL 12 is supported.** douze's protocol was decoded from the SSL 12;
other SSL interfaces use different hardware and are not supported. The SSL 2
and 2+ family have no software mixer at all.

Tested on one SSL 12 at firmware **1.41**, with Omarchy (Quickshell 0.3.2) and
PipeWire 1.6. douze itself was developed on firmware 1.44.

| Area | Status |
| --- | --- |
| Strips, preamp keys, monitor section, USER mapping, loopback, profiles, meters | tested |
| Cue-mix sends, FOLLOW / CUT / MONO, stereo link | tested |
| Talkback meter, front-panel **gui** button | tested on firmware 1.41 only |
| ADAT 1–8 | **experimental**: douze's presumed mixer slots, never tested with an optical source |
| Talkback level and routing | not adjustable: they live in the card's firmware (the vendor app's talkback trim sends nothing to the card either) |

Your firmware version is the `bcdDevice` of USB device `31e9:0005`
(`cat /sys/bus/usb/devices/*/bcdDevice` next to `idProduct` `0005`).

## Requirements

- **Omarchy** with its Quickshell-based shell (the "Quattro" shell).
- An **SSL 12** on the **Pro Audio** profile in PipeWire. Check with
  `pactl list cards short`, or switch it in the Omarchy audio panel /
  `pavucontrol` → Configuration.
- **douze** with the extensions this plugin uses (`bus_modes`, `ui`, `gui`,
  `adat`). They have been proposed upstream in
  [xenicle/douze#1](https://github.com/xenicle/douze/pull/1). Until they are merged,
  install the `omarchy360` branch of
  [FenrirRhogar/douze](https://github.com/FenrirRhogar/douze/tree/omarchy360).
  With a stock douze the plugin still works, minus stereo link, ADAT,
  FOLLOW / CUT / MONO and the **gui** button, which it hides.
- `python` and `python-pyusb` (for douze), `curl`, and the PipeWire tools
  `pw-record`, `pw-link` and `pw-dump` (Arch: `pipewire` and `pipewire-audio`,
  both present on Omarchy).

## Installation

### 1. douze

Install its only dependency and fetch it:

```bash
sudo pacman -S --needed python-pyusb curl
git clone -b omarchy360 https://github.com/FenrirRhogar/douze ~/.local/share/douze
```

**Allow your user to open the card's control interface.** douze ships a udev
rule that uses the `audio` group. The rule below instead grants access to
whoever is logged in at the seat, so no group change or re-login is needed:

```bash
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="31e9", ATTRS{idProduct}=="0024", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/70-douze.rules
sudo udevadm control --reload
sudo udevadm trigger --action=change --subsystem-match=usb
```

Unplug and replug the SSL 12 if `getfacl /dev/bus/usb/*/*` does not list your
user on its device afterwards.

**Run douze as a user service**, started with your session:

```bash
mkdir -p ~/.config/systemd/user
sed "s|%h/douze|%h/.local/share/douze|" ~/.local/share/douze/systemd/douze.service \
  > ~/.config/systemd/user/douze.service
systemctl --user daemon-reload
systemctl --user enable --now douze
journalctl --user -u douze -n 5     # expect "SSL 12 branchée" and "état restauré sur le device"
```

> **The first start sets the card's mixer.** The card boots blank, and douze
> pushes its saved state on every start. On first start that is douze's default:
> Analog 1–4 and Playback 1-2 at 0 dB in the main mix, Playback 3-8 off, monitor
> and headphone levels untouched. If you monitor an instrument through a DAW,
> pull the Analog faders down so you don't hear the dry signal too.

douze also has an optional PipeWire configuration that turns playback 3-4 /
5-6 / 7-8 into separate stereo outputs; see its README. Omarchy360 does not need
it.

### 2. The plugin

```bash
omarchy plugin add https://github.com/FenrirRhogar/omarchy360 --enable
```

The three-fader icon appears on the right of the bar. Move it with
`omarchy bar move fenrirrhogar.omarchy360 --section <left|center|right>`.

### 3. A keyboard shortcut (optional)

Add to `~/.config/hypr/bindings.lua` (pick any free key; check with
`omarchy menu keybindings --print`):

```lua
o.bind("SUPER + ALT + M", "Omarchy360 mixer", "omarchy-shell shell toggle fenrirrhogar.omarchy360")
```

### 4. Open the mixer from the card (optional)

In the mixer, set one of the USER buttons (CUT, ALT or TALK key) to **gui**.
Then tell douze what to run when that button is pressed. douze reads this from
its service environment, never from its API:

```bash
mkdir -p ~/.config/systemd/user/douze.service.d
printf '%s\n' '[Service]' \
  'Environment="DOUZE_GUI_CMD=omarchy-shell shell toggle fenrirrhogar.omarchy360"' \
  > ~/.config/systemd/user/douze.service.d/omarchy360.conf
systemctl --user daemon-reload
systemctl --user restart douze
systemctl --user show douze -p Environment    # should list DOUZE_GUI_CMD
```

The button you pick loses its original function (for example, ALT no longer
switches speakers).

## Using the mixer

### Header

`● connected 48 kHz` means douze is running and the card is present. Otherwise
the header says **douze offline** or **SSL 12 not connected**, and the footer
says what to do. If the card and the computer disagree on the sample rate, a
**clock mismatch** warning appears. Errors from douze appear at the end of the
header.

### Strips

- **Fader**: drag, scroll (±0.5 dB per notch), or double-click for 0 dB. The
  readout below shows the exact value; the bottom of the travel is −∞ (off).
- **Pan**: drag the small slider; double-click centres it.
- **SOLO / CUT**: like a console. SOLO plays only the soloed strips in the main
  mix; CUT silences a strip.
- **Preamp keys**: 48V is red when on. Never send phantom power to ribbon
  microphones.
- **DIR** (Playback 3-4 / 5-6 / 7-8): sends that playback pair straight to its
  output (Line 3-4, HP A, HP B), bypassing the mixer. Playback 1-2 has no DIR: it
  always goes through the main mix.
- **∞ LINK / ∞ UNLINK**: under Analog 1 and 3 (and odd ADAT strips). Linking
  copies the left strip's fader, CUT and SOLO to the right one and pans them
  hard left/right. The linked strip's pan then moves the stereo image. Unlinking
  centres both.

When the strips do not fit, a scroll bar appears under them; drag it or scroll
sideways.

### Cue mixes: MIX 1-2, HP A, HP B, LINE 3-4

The row `faders → [MIX 1-2] [HP A] [HP B] [LINE 3-4]` chooses what the faders
edit:

- **MIX 1-2** is the main mix to the monitor outputs. This is what you normally
  hear.
- **HP A / HP B / LINE 3-4** each have a separate cue mix. With one selected,
  each strip's fader is that input's **send** to the bus, and the button under it
  reads **SEND ON / SEND OFF**.

The **AUX bar** under the row controls the selected bus:

- **FOLLOW MIX 1-2**: the bus copies the main mix and ignores its own sends.
  Strips then read *follows mix*. Turn FOLLOW off to build a separate headphone
  mix, for example more click and less guitar for a performer.
- **CUT** and **MONO** mute or mono-sum that output only.
- **level**: the bus output level (−60 … +12 dB).

### Monitoring column

- The four meter pairs show what reaches the Monitor, HP A, HP B and Line 3-4
  outputs.
- The tall **MON** fader is the monitor output level. It shows *(not set)*
  until you first move it; until then the card keeps its own level.
- **DIM** lowers the monitors by the **dim level**. **CUT** mutes them. **MONO**
  sums them to mono. **ØL** inverts the left channel's polarity (a phase check).
  **ALT** switches to the alternate speakers on outputs 3-4, which only works
  with **ALT SPK** on, trimmed by **ALT trim**. **TALK** opens the talkback mic
  (the card dims the monitors while it is on).
- **USER BUTTONS**: `<` / `>` cycle the function of each front-panel key.
- **CONTROL → loopback**: which mix the card sends back to the computer as an
  extra stereo input (inputs 7-8 of the SSL 12 Pro capture device on the tested
  card). Useful for streaming or recording a call. *none* turns it off.
- **PROFILE**: `< >` picks a profile. **LOAD** applies it to the card (faders,
  sends, bus modes, preamp keys, button mapping, links). **SAVE** overwrites it.
  Type a name and press Enter or **SAVE AS** to create one. **DELETE** asks
  **SURE?** (or **NO**), and cancels by itself after 4 s. A `*` after *loaded:*
  means you changed something since loading. Profiles are douze's JSON files in
  `~/.config/sslctl/profiles/`.

### Apps page

One strip per app stream. The fader is the app's PipeWire volume (the mark is
100 %, max 150 %); scroll or drag, and double-click for 100 %. **mute** mutes
the app. Meters read in dBFS.

## Keyboard and mouse

| Key | Action |
| --- | --- |
| `1` / `2`, Tab / Shift+Tab | mixer / apps page |
| ← / → | previous / next fader bus (mixer page) |
| Esc | close (or leave the profile name field) |
| Enter (in the name field) | save as a new profile |

| Mouse | Fader | Slider (pan, levels) |
| --- | --- | --- |
| drag | set level | set value |
| scroll | ±0.5 dB | ± one step |
| double-click | 0 dB | reset (centre / default) |

Clicking outside the window closes it.

## What it runs, and permissions

Omarchy plugins run inside the shell process, unsandboxed, with your user's
permissions. Omarchy360 needs no root, starts no second shell, and:

- talks to douze over HTTP on `127.0.0.1:1212` only. Requests go through
  Quickshell; the live event stream runs through `curl`.
- runs `bin/omarchy360-peaks` (Python) for the meters Quickshell can't read: the
  SSL 12's pro-audio channels, and app streams with unknown channel positions,
  such as Spotify. It records with `pw-record` (nodes named `omarchy360-meter…`),
  reads ports with `pw-dump` and, for app streams, connects them to its capture
  with `pw-link`. It only listens and never changes what an app plays. These
  processes run only while the mixer is open, and they exit with it.
- Only douze touches USB. douze's API has no authentication and listens on
  localhost, so any program running as you can change the card's mixer. That is
  douze's design.

### Privileged and system steps (manual, one time)

The plugin's code never calls `sudo`, a package manager or `systemctl`.
Every such step is in this README for you to run yourself, once:

| Step | Command | Why |
| --- | --- | --- |
| Install douze's dependency | `sudo pacman -S --needed python-pyusb curl` | douze talks USB through pyusb; the plugin's event stream uses curl |
| udev rule (root-owned file) | `sudo tee /etc/udev/rules.d/70-douze.rules` | lets your own user open the card's control interface, so douze runs without root |
| Apply the rule | `sudo udevadm control --reload`, `sudo udevadm trigger …` | makes the rule take effect without a reboot |
| douze user service | `systemctl --user daemon-reload / enable --now / restart douze` | runs douze in your session, as your user, not as root |
| Optional gui button | drop-in under `~/.config/systemd/user/douze.service.d/` | tells douze which command a front-panel button runs |
| Uninstall | `sudo rm /etc/udev/rules.d/70-douze.rules`, `systemctl --user disable --now douze` | undoes the above |

Nothing runs as root at any point after setup, and only the udev rule is
system-wide. It matches the SSL 12's control interface (USB `31e9:0024`) and
nothing else.

## Updating and uninstalling

```bash
omarchy plugin update fenrirrhogar.omarchy360      # update the plugin
git -C ~/.local/share/douze pull                   # update douze
systemctl --user restart douze
```

Uninstall:

```bash
omarchy plugin remove fenrirrhogar.omarchy360
systemctl --user disable --now douze
rm -r ~/.config/systemd/user/douze.service ~/.config/systemd/user/douze.service.d
sudo rm /etc/udev/rules.d/70-douze.rules
# douze's saved state and profiles: ~/.config/sslctl/
```

Remove the keyboard binding from `~/.config/hypr/bindings.lua` if you added
one. The card keeps its current mixer until it is powered off.

## Troubleshooting

**"douze offline"**: the daemon isn't running.
`systemctl --user status douze`, then `journalctl --user -u douze -b`. A
`USBError: Access denied` means the udev rule isn't applied: replug the card.

**"SSL 12 not connected"**: douze runs but can't see the card. Check it's on
and plugged in; on a hub, try a direct port.

**No sound from the computer**: check the **PLAY 1-2** fader (it carries the
computer's main output) and the **MON** level, then **CUT** / **DIM** in the
monitor column and on the strips. They're saved in douze's state and restored
on every start.

**One output is silent**: check that bus's **CUT** and level in the AUX bar,
and whether **FOLLOW MIX 1-2** is what you expect.

**Meters don't move**: they need douze connected (mixer page) or PipeWire (apps
page). Analog meters only move with signal on that input.

**An app shows no meter**: some apps report channel positions PipeWire can't
name; Omarchy360 meters those through `pw-record` + `pw-link`. If one still
doesn't move, check `pw-link -l` for a link from the app to `omarchy360-meter-…`.

**FOLLOW / CUT / MONO, ∞ LINK, ADAT or the gui function are missing**: your
douze doesn't announce those extensions. Install the `omarchy360` branch (see
[Requirements](#requirements)).

**The gui button does nothing**: check that the button is set to **gui** in
USER BUTTONS and that `systemctl --user show douze -p Environment` lists
`DOUZE_GUI_CMD`. After editing the drop-in, run `systemctl --user daemon-reload`
before restarting.

**ALT does nothing**: ALT switches to the alternate speakers, so it needs
**ALT SPK** on (and the card doesn't report ALT presses until it is).

**Talkback is uneven or one-sided**: its routing is fixed in the card's
firmware. **MONO** on the headphone bus (AUX bar) puts it in both ears, along
with the music.

**Plugin code changes don't appear** (development): the overlay stays loaded
for speed; run `omarchy restart shell`.

To report a bug, include your firmware (`bcdDevice`), PipeWire version,
`journalctl --user -u douze -b --no-pager`, and
`qs log -p "$OMARCHY_PATH/shell" --tail 100`.

## FAQ

**Does it replace the vendor app?** For day-to-day mixing, monitoring and
button mapping on Linux, yes. Firmware updates and the vendor's own profile
files are out of scope.

**Is it safe for my card?** douze only sends sequences observed between the
vendor app and the card, with the documented exceptions (the **gui** function
value and the presumed ADAT slots). Mixer settings live in volatile memory, so a
power cycle always returns the card to its blank state.

**Does it work with the SSL 2, 2+, or SSL 18?** No. See
[Status and compatibility](#status-and-compatibility).

**Why "Omarchy360"?** It is an Omarchy take on what the vendor's control app
does: a reference, not an affiliation.

## Development

The plugin is plain QML plus one Python helper:

| File | Role |
| --- | --- |
| `manifest.json` | plugin manifest (bar widget + overlay, `keepLoaded`) |
| `Widget.qml` | bar icon; toggles the overlay |
| `MixerOverlay.qml` | full-screen overlay window, keyboard focus, close handling |
| `SslView.qml` | page layout, header, tabs, keys |
| `Douze.qml` | douze client: state, ordered command queue, event stream, `_features` |
| `Ssl.js` | the SSL 12 model: channels, buses, meter indices, fader taper |
| `SslStrip.qml`, `TalkbackStrip.qml`, `AuxBar.qml`, `MonitorSection.qml`, `ProfileBar.qml` | mixer page parts |
| `AppsPage.qml`, `NodeStrip.qml`, `PeakMeter.qml`, `Mixer.js` | apps page |
| `DbFader.qml`, `VolumeFader.qml`, `HSlider.qml`, `LevelMeter.qml`, `TermButton.qml`, `Term.qml` | controls and theme tokens |
| `bin/omarchy360-peaks` | PipeWire peak meter for nodes Quickshell can't meter |

Validate before committing:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/fenrirrhogar.omarchy360

# qmllint needs the shell's qs.* modules on an import path:
mkdir -p /tmp/qslint/qs
ln -sfn "$OMARCHY_PATH/shell/Commons" /tmp/qslint/qs/Commons
ln -sfn "$OMARCHY_PATH/shell/Ui" /tmp/qslint/qs/Ui
/usr/lib/qt6/bin/qmllint -I /tmp/qslint ~/.config/omarchy/plugins/fenrirrhogar.omarchy360/*.qml
```

The remaining qmllint warnings come from Omarchy's own loosely typed objects
(`Style`, `Color`, the bar).

Lifecycle check (the Omarchy marketplace list):

```bash
ID=fenrirrhogar.omarchy360
omarchy-shell shell summon $ID '{}'; omarchy-shell shell hide $ID
omarchy-shell shell toggle $ID; omarchy-shell shell toggle $ID
omarchy plugin disable $ID; omarchy plugin enable $ID
omarchy restart shell
```

Before sending anything new to the card, read douze's
[CONTRIBUTING.md](https://github.com/xenicle/douze/blob/main/CONTRIBUTING.md).
Its first rule is to never send invented frames.

## Credits and license

- [douze](https://github.com/xenicle/douze) by xenicle: the SSL 12 protocol
  work and daemon this plugin depends on (AGPL-3.0; protocol docs CC0).
- [Omarchy](https://omarchy.org) and [Quickshell](https://quickshell.org).

Omarchy360 is released under the MIT License, see [LICENSE](LICENSE). douze is
a separate program under its own license and is not bundled.
