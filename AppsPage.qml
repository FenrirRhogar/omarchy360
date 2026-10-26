pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire
import "Mixer.js" as Mixer

// Per-app playback/record volumes, straight from PipeWire.
ListView {
  id: root

  required property Term term
  property bool active: false

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
