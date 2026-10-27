pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Mixer.js" as Mixer
import "Ssl.js" as Ssl

// Per-app volumes straight from PipeWire, and where each playing app is
// heard. On the SSL 12 an app plays into one playback pair (douze's
// ssl12.pbXX sinks) and the card's mixer copies that pair to any outputs:
// speakers (main mix), HP A, HP B, Line 3-4. Apps heard anywhere but the
// speakers alone get a spare pair (3-4, 5-6, 7-8) to themselves.
ListView {
  id: root

  required property Term term
  required property var douze
  property bool active: false

  // Output routing, read through bin/omarchy360-route (pactl).
  property var sinks: []
  property var routes: ({})          // node id -> sink name
  property string routeError: ""
  readonly property var outputs: Ssl.appOutputs(sinks)
  readonly property string helper: Qt.resolvedUrl("bin/omarchy360-route").toString().replace(/^file:\/\//, "")

  function refreshRoutes() {
    if (!listProc.running) listProc.running = true
  }

  function move(node, sinkName) {
    moveProc.command = [helper, "move", String(node.id), sinkName]
    moveProc.running = true
  }

  // Output device: "ssl" or another sink's name.
  function pickDevice(node, name) {
    routeError = ""
    move(node, name === "ssl" ? "ssl12.pb12" : name)
  }

  // A spare pair no other app plays into, preferring ones the mixer doesn't
  // use (DIR off, out of the main mix): those may carry a DAW's tracks.
  function sparePair(nodeId) {
    var taken = {}
    for (var id in routes) if (id !== String(nodeId)) taken[Ssl.sinkPair(routes[id])] = true
    var free = Ssl.SPARE_PAIRS.filter(p => !taken[p])
    var quiet = free.filter(p => !Ssl.dirOn(douze.st, p) && !Ssl.inMainMix(douze.st, p))
    return quiet[0] || free[0] || ""
  }

  // Give an aux bus its own mix: stop it following and copy the main mix
  // into its sends (levels, pans, cuts), except for `skip`.
  function unfollow(bus, skip) {
    var st = douze.st
    var split = douze.has("line4")
    Ssl.busOutputs(Ssl.busById(bus), split).forEach(o => {
      if (Ssl.busMode(st, o.master, "follow") === true)
        douze.api({ cmd: "bus", bus: o.master, mode: "follow", on: false })
    })
    Ssl.CHANNELS.forEach(c => {
      if (c.id === skip || (c.adat && !douze.has("adat"))) return
      if (Ssl.dirOn(st, c.id) && Ssl.DIR_BUS[c.id] === bus) return   // keep a DIR into this bus
      var ch = Ssl.channel(st, c.id)
      var cmd = { cmd: "route", ch: c.id, bus: bus, level: ch.mute || Ssl.isOff(ch.fader) ? "off" : ch.fader }
      if (douze.has("send_pan")) cmd.pan = Number(ch.pan) || 0
      douze.api(cmd)
    })
  }

  // Tick or untick one output (spk / hpa / hpb / line34) for an app.
  function toggleTarget(node, key) {
    routeError = ""
    var st = douze.st
    var split = douze.has("line4")
    var pair = Ssl.sinkPair(routes[String(node.id)] || "") || "pb12"
    var want = Ssl.pairTargets(st, pair, split)
    want[key] = !want[key]
    var spkOnly = want.spk && !want.hpa && !want.hpb && !want.line34

    if (pair === "pb12") {
      if (spkOnly) return
      pair = sparePair(node.id)
      if (!pair) {
        routeError = "all 3 spare playback pairs are in use by other apps"
        return
      }
      move(node, "ssl12." + pair)
    } else if (spkOnly) {
      // back to the main mix; leave the spare pair silent for the next app
      move(node, "ssl12.pb12")
      want = { spk: false, hpa: false, hpb: false, line34: false }
    }

    // The pair is now this app's: route it by the mixer, not DIR.
    if (Ssl.dirOn(st, pair)) {
      douze.api({ cmd: "dir", ch: pair, on: false })
      var taken = Object.assign({}, st.ui && st.ui.dirFollow ? st.ui.dirFollow : {})
      delete taken[pair]
      if (douze.has("ui")) douze.api({ cmd: "ui", key: "dirFollow", value: taken })
    }
    douze.api({ cmd: "mute", ch: pair, on: false })
    douze.api({ cmd: "fader", ch: pair, db: want.spk ? 0 : "off" })
    Ssl.AUX_BUSES.forEach(b => {
      // A following bus hears the app exactly when the speakers do. If it
      // should differ, it needs a mix of its own.
      if (Ssl.busFollows(st, b, split)) {
        if (want[b] === want.spk) return
        unfollow(b, pair)
      }
      var cmd = { cmd: "route", ch: pair, bus: b, level: want[b] ? 0 : "off" }
      if (douze.has("send_pan")) cmd.pan = 0
      douze.api(cmd)
    })
  }

  Process {
    id: listProc
    command: [root.helper, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let r = null
        try { r = JSON.parse(text) } catch (e) { return }
        root.sinks = r.sinks
        root.routes = r.streams
      }
    }
  }

  Process {
    id: moveProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.routeError = text.trim()
    }
    onExited: root.refreshRoutes()
  }

  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: root.active
    onTriggered: root.refreshRoutes()
  }

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var liveStreams: nodes.filter(n => n && n.isStream && n.audio)

  // Snapshots refreshed after PipeWire settles: rebuilding straight from a
  // node-removal signal has crashed Quickshell's PipeWire service.
  property var streams: []

  function snapshot() {
    if (!active) return
    var s = liveStreams.filter(Mixer.isAppStream)
    if (!Mixer.sameNodes(s, streams)) streams = s
  }

  onLiveStreamsChanged: snapshotTimer.restart()
  onActiveChanged: active ? snapshot() : streams = []

  Timer {
    id: snapshotTimer
    interval: 75
    onTriggered: root.snapshot()
  }

  // Streams turn ready after they appear, which doesn't change the list.
  Timer {
    interval: 1000
    repeat: true
    running: root.active
    onTriggered: root.snapshot()
  }

  PwObjectTracker { objects: root.active ? root.liveStreams : [] }

  orientation: ListView.Horizontal
  spacing: 8
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  model: streams

  delegate: NodeStrip {
    required property var modelData
    height: root.height
    term: root.term
    node: modelData
    active: root.active
    outputs: root.outputs
    output: root.routes[String(modelData.id)] || ""
    targets: Ssl.pairTargets(root.douze.st, Ssl.sinkPair(output) || "pb12", root.douze.has("line4"))
    canTarget: root.douze.device && root.douze.has("send_pan") && root.outputs.some(o => Ssl.SINK_PAIR[o.name])
    onPickDevice: name => root.pickDevice(modelData, name)
    onToggleTarget: key => root.toggleTarget(modelData, key)
  }

  Text {
    visible: root.routeError !== ""
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    text: "! " + root.routeError
    color: root.term.urgent
    font.family: root.term.font
    font.pixelSize: root.term.small
  }

  Text {
    visible: root.count === 0
    anchors.centerIn: parent
    text: "-- no apps playing or recording --"
    color: root.term.dim
    font.family: root.term.font
    font.pixelSize: root.term.size
  }
}
