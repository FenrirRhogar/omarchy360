.pragma library

// SSL 12 model as SSL 360° shows it, mapped onto the douze daemon's API
// (~/.local/share/douze, http://127.0.0.1:1212). Meter indices are douze's
// calibration of the sub 09 meter frame.

var CHANNELS = [
  { id: "1", name: "ANALOG 1", sub: "mic", preamp: 0, meters: [0] },
  { id: "2", name: "ANALOG 2", sub: "mic", preamp: 1, meters: [1] },
  { id: "3", name: "ANALOG 3", sub: "line/inst", preamp: 2, meters: [2] },
  { id: "4", name: "ANALOG 4", sub: "line/inst", preamp: 3, meters: [3] },
  // ADAT 1-8: douze's presumed matrix slots 14-21 and meter words 4-11 (both
  // silent until something feeds the optical input).
  { id: "a1", name: "ADAT 1", sub: "optical", adat: true, meters: [4] },
  { id: "a2", name: "ADAT 2", sub: "optical", adat: true, meters: [5] },
  { id: "a3", name: "ADAT 3", sub: "optical", adat: true, meters: [6] },
  { id: "a4", name: "ADAT 4", sub: "optical", adat: true, meters: [7] },
  { id: "a5", name: "ADAT 5", sub: "optical", adat: true, meters: [8] },
  { id: "a6", name: "ADAT 6", sub: "optical", adat: true, meters: [9] },
  { id: "a7", name: "ADAT 7", sub: "optical", adat: true, meters: [10] },
  { id: "a8", name: "ADAT 8", sub: "optical", adat: true, meters: [11] },
  // Playback 1-2 is a full strip in SSL 360° (no DIR: douze maps its DIR
  // to the fader, so DIR off silenced the computer).
  { id: "pb12", name: "PLAY 1-2", sub: "daw 1-2 → mix", meters: [12, 13] },
  { id: "pb34", name: "PLAY 3-4", sub: "daw 3-4", dir: "LINE 3-4", meters: [22, 23] },
  { id: "pb56", name: "PLAY 5-6", sub: "daw 5-6", dir: "HP A", meters: [24, 25] },
  { id: "pb78", name: "PLAY 7-8", sub: "daw 7-8", dir: "HP B", meters: [26, 27] }
]

// Mono inputs that SSL 360° can link into one stereo strip (odd = left).
var LINK_PAIRS = [["1", "2"], ["3", "4"], ["a1", "a2"], ["a3", "a4"], ["a5", "a6"], ["a7", "a8"]]

function pairKey(pair) {
  return pair[0] + "-" + pair[1]
}

function isLinked(st, pair) {
  return !!(st && st.ui && st.ui.links && st.ui.links[pairKey(pair)])
}

function chanById(id) {
  for (var i = 0; i < CHANNELS.length; i++) if (CHANNELS[i].id === id) return CHANNELS[i]
  return null
}

function pairOf(id) {
  for (var i = 0; i < LINK_PAIRS.length; i++)
    if (LINK_PAIRS[i].indexOf(id) !== -1) return LINK_PAIRS[i]
  return null
}

// The strips to draw: linked pairs collapse into one stereo strip.
//   { key, ids, name, sub, preamps, dir, meters, pair, linked }
function strips(st, showAdat) {
  var out = []
  for (var i = 0; i < CHANNELS.length; i++) {
    var c = CHANNELS[i]
    if (c.adat && !showAdat) continue
    var pair = pairOf(c.id)
    if (pair && isLinked(st, pair)) {
      if (pair[0] !== c.id) continue
      var r = chanById(pair[1])
      out.push({
        key: pairKey(pair), ids: pair.slice(), pair: pair, linked: true,
        name: c.name + "-" + r.name.split(" ").pop(), sub: "stereo link",
        preamps: c.preamp === undefined ? [] : [c.preamp, r.preamp],
        meters: c.meters.concat(r.meters), adat: !!c.adat
      })
    } else {
      out.push({
        key: c.id, ids: [c.id], pair: pair, linked: false, name: c.name,
        sub: c.dir ? "dir → " + c.dir : c.sub, dir: c.dir,
        preamps: c.preamp === undefined ? [] : [c.preamp],
        meters: c.meters, adat: !!c.adat
      })
    }
  }
  return out
}

// Stereo position of a linked pair as one -100..100 value: the left channel
// starts hard left and the right hard right; moving it slides the pair.
function pairPan(l, r) {
  l = Number(l) || 0
  r = Number(r) || 0
  if (l > -100) return (l + 100) / 2
  if (r < 100) return (r - 100) / 2
  return 0
}

function linkedPan(st, pair) {
  return pairPan(channel(st, pair[0]).pan, channel(st, pair[1]).pan)
}

// Pan of a channel's send to an aux bus (douze `send_pan`; 0 = centre).
function sendPan(st, id, bus) {
  var p = st && st.send_pans && st.send_pans[id] ? st.send_pans[id][bus] : undefined
  return p === undefined ? 0 : Number(p)
}

var SEND_BUSES = ["hpa", "hpb", "line34"]

// Pan readout; on Line 3-4 (two mono outputs) the ends are the outputs.
function fmtSendPan(pos, bus) {
  if (bus === "line34" && pos <= -100) return "3"
  if (bus === "line34" && pos >= 100) return "4"
  return fmtPan(pos)
}

function linkedPans(pos) {
  return pos >= 0 ? [-100 + 2 * pos, 100] : [-100, 100 + 2 * pos]
}

// Which mix the strip faders edit: the main mix (Monitor) or an aux bus's
// own cue mix. `master` is the douze name of that bus's master/modes.
var BUSES = [
  { id: "mix", name: "MIX 1-2", master: "monitor" },
  { id: "hpa", name: "HP A", master: "hp-a" },
  { id: "hpb", name: "HP B", master: "hp-b" },
  { id: "line34", name: "LINE 3-4", master: "line34" }
]

// The physical outputs behind a bus, each with its own master instance.
// HP A / HP B are stereo on one instance; Line 3-4 are two mono outputs, and
// with douze's `line4` the second one (instance 3) is set on its own.
function busOutputs(bus, splitLine) {
  if (bus.id === "line34" && splitLine)
    return [{ master: "line34", label: "OUT 3" }, { master: "line4", label: "OUT 4" }]
  return [{ master: bus.master, label: "" }]
}

// DIR sends a playback pair 1:1 to its output, i.e. to this bus.
var DIR_BUS = { pb34: "line34", pb56: "hpa", pb78: "hpb" }

function busById(id) {
  for (var i = 0; i < BUSES.length; i++) if (BUSES[i].id === id) return BUSES[i]
  return null
}

// App outputs: douze's stereo sinks, one per playback pair. The 8-channel
// "SSL 12 Pro" sink plays on pair 1-2 too.
var SINK_PAIR = { "ssl12.pb12": "pb12", "ssl12.pb34": "pb34", "ssl12.pb56": "pb56", "ssl12.pb78": "pb78" }

function sinkPair(name) {
  if (SINK_PAIR[name]) return SINK_PAIR[name]
  return /^alsa_output\.usb-Solid_State_Logic_SSL_12.*pro-output/.test(name) ? "pb12" : ""
}

// Sinks offered per app: the SSL pairs first, the raw 8-channel SSL sink
// left out (it is the same as pair 1-2), then the computer's other outputs.
function appOutputs(sinks) {
  var ssl = sinks.filter(s => SINK_PAIR[s.name])
  ssl.sort((a, b) => a.name < b.name ? -1 : 1)
  return ssl.concat(sinks.filter(s => !sinkPair(s.name)))
}

// ── Per-app outputs ────────────────────────────────────────────────────
// An app plays into one playback pair; the card's mixer then copies that
// pair to any outputs. Playback 1-2 is the main mix (speakers). Apps that go
// anywhere else get one of the spare pairs to themselves.
var APP_TARGETS = [["SPK", "spk"], ["HP A", "hpa"], ["HP B", "hpb"], ["L 3-4", "line34"]]
var AUX_BUSES = ["hpa", "hpb", "line34"]
var SPARE_PAIRS = ["pb34", "pb56", "pb78"]

function dirOn(st, pair) {
  return !!(st && st.dir && st.dir[pair])
}

// Does any output of this aux bus copy the main mix?
function busFollows(st, busId, splitLine) {
  return busOutputs(busById(busId), splitLine).some(o => busMode(st, o.master, "follow") === true)
}

function inMainMix(st, id) {
  var c = channel(st, id)
  return !c.mute && !isOff(c.fader)
}

// Where a playback pair is heard right now: { spk, hpa, hpb, line34 }.
// A following bus hears whatever the main mix has; DIR sends the pair to its
// own bus only.
function pairTargets(st, pair, splitLine) {
  var t = { spk: inMainMix(st, pair) }
  AUX_BUSES.forEach(b => {
    if (dirOn(st, pair)) t[b] = DIR_BUS[pair] === b
    else if (busFollows(st, b, splitLine)) t[b] = t.spk
    else t[b] = !isOff(level(st, pair, b))
  })
  return t
}

function busMode(st, master, mode) {
  var m = st && st.bus_modes && st.bus_modes[master] ? st.bus_modes[master][mode] : undefined
  return m === undefined ? undefined : !!m
}

var BUS_METERS = [
  { name: "MON", meters: [20, 21] },
  { name: "HP A", meters: [16, 17] },
  { name: "HP B", meters: [18, 19] },
  { name: "L 3-4", meters: [14, 15] }
]

// Talkback mic level: meter word 28 (found on the user's card, firmware 1.41).
var TALKBACK_METERS = [28]

var PREAMP_KEYS = [["48V", "48v"], ["LINE", "inst"], ["HPF", "hpf"], ["Ø", "phase"]]

var MON_KEYS = [["DIM", "dim"], ["CUT", "cut"], ["MONO", "mono"],
                ["ØL", "invert-l"], ["ALT", "alt"], ["TALK", "talk"]]

// Front-panel buttons and the functions SSL 360°'s USER menu offers them.
var USER_BUTTONS = [["CUT", "cut"], ["ALT", "alt"], ["TALK", "talk"]]
var USER_DEFAULT = { cut: "cut", alt: "alt", talk: "talkback" }
var USER_FNS = ["dim", "cut", "mono-sum", "alt", "invert-l", "talkback", "gui"]

var LOOPBACK = ["none", "pb12", "pb34", "pb56", "pb78", "monitor", "line34", "hpa", "hpb"]

// Fader taper: -inf below MIN_DB, 0 dB at UNITY_POS, +12 dB at the top.
var MIN_DB = -60
var MAX_DB = 12
var UNITY_POS = 0.75
var OFF_POS = 0.02

function isOff(db) {
  return db === undefined || db === null || db === "off"
}

function dbToPos(db) {
  if (isOff(db)) return 0
  db = Math.max(MIN_DB, Math.min(MAX_DB, Number(db)))
  if (db >= 0) return UNITY_POS + (1 - UNITY_POS) * db / MAX_DB
  return OFF_POS + (UNITY_POS - OFF_POS) * (1 - Math.pow(db / MIN_DB, 1 / 1.6))
}

function posToDb(p) {
  if (p < OFF_POS) return "off"
  var db
  if (p >= UNITY_POS) db = (p - UNITY_POS) / (1 - UNITY_POS) * MAX_DB
  else db = MIN_DB * Math.pow(1 - (p - OFF_POS) / (UNITY_POS - OFF_POS), 1.6)
  return Math.round(Math.min(MAX_DB, db) * 2) / 2
}

// Wheel / keyboard step from a level, in dB.
function stepDb(db, delta) {
  if (isOff(db)) return delta > 0 ? MIN_DB : "off"
  var v = Number(db) + delta
  if (v < MIN_DB) return "off"
  return Math.min(MAX_DB, Math.round(v * 2) / 2)
}

function fmtDb(db) {
  if (isOff(db)) return "-inf"
  var v = Number(db)
  return (v > 0 ? "+" : "") + v.toFixed(1)
}

// Meter word (peak s16, 32767 = 0 dBFS) to 0..1 over -60..0 dBFS.
function meterPos(raw) {
  if (!raw) return 0
  var db = 20 * Math.log(raw / 32768) / Math.LN10
  return Math.max(0, Math.min(1, (db + 60) / 60))
}

function pick(values, indices) {
  var out = []
  for (var i = 0; i < indices.length; i++) out.push((values && values[indices[i]]) || 0)
  return out
}

function channel(st, id) {
  var c = st && st.channels ? st.channels[id] : null
  if (c) return c
  var off = (id.indexOf("pb") === 0 && id !== "pb12") || id.charAt(0) === "a"
  return { fader: off ? "off" : 0.0, pan: 0, mute: false, solo: false }
}

// Level of a channel on the selected bus: its fader on the main mix, or its
// send otherwise (douze stores unset sends as missing).
function level(st, id, bus) {
  if (bus === "mix") return channel(st, id).fader
  var s = st && st.sends && st.sends[id] ? st.sends[id][bus] : undefined
  return isOff(s) ? "off" : s
}

function preamp(st, name, index) {
  return !!(st && st.preamp && st.preamp[name] && st.preamp[name][String(index)])
}

function monitoring(st, name) {
  return !!(st && st.monitoring && st.monitoring[name])
}

function master(st, bus) {
  return st && st.masters ? st.masters[bus] : undefined
}

function userFn(st, button) {
  return (st && st.user_buttons && st.user_buttons[button]) || USER_DEFAULT[button]
}

function cycle(list, current, delta) {
  var i = list.indexOf(current)
  return list[((i < 0 ? 0 : i) + delta + list.length) % list.length]
}

function fmtPan(pos) {
  var v = Math.round(Number(pos) || 0)
  return v === 0 ? "C" : v < 0 ? "L" + (-v) : "R" + v
}
