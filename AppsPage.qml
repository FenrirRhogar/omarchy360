pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Mixer.js" as Mixer
import "Ssl.js" as Ssl

// Per-app volumes straight from PipeWire, and each playing app's output:
// any sink, or one of the SSL 12's playback pairs (douze's ssl12.pbXX sinks).
// Sending an app to Line 3-4 or a headphone output turns that pair's DIR on,
// since otherwise the pair only reaches the mixer, not the jack.
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

  function moveTo(node, sinkName) {
    routeError = ""
    moveProc.command = [helper, "move", String(node.id), sinkName]
    moveProc.running = true
    var pair = Ssl.sinkPair(sinkName)
    if (Ssl.DIR_BUS[pair] && douze.has("bus_modes") && !(douze.st && douze.st.dir && douze.st.dir[pair]))
      douze.setDir(pair, true)
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
    onPickOutput: name => root.moveTo(modelData, name)
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
