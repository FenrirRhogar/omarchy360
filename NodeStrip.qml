pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Mixer.js" as Mixer
import "Ssl.js" as Ssl

// One app stream as a strip: name, id/channels, live meters, volume fader,
// mute and, for playback, its output device and which SSL 12 outputs it is
// heard on.
Rectangle {
  id: root

  required property Term term
  required property var node
  property bool active: false
  property var outputs: []           // sinks offered, see Ssl.appOutputs
  property string output: ""         // sink this app plays to now
  property var targets: ({})         // SSL outputs it is heard on, see Ssl.pairTargets
  property bool canTarget: false

  signal pickDevice(string name)     // "ssl" or a sink name
  signal toggleTarget(string key)

  readonly property bool canRoute: outputs.length > 0 && output !== ""   // playback streams only
  readonly property bool onSsl: Ssl.sinkPair(output) !== ""
  // Devices to cycle through: the SSL 12 once, then the other outputs.
  readonly property var devices: (outputs.some(o => Ssl.SINK_PAIR[o.name]) ? ["ssl"] : [])
    .concat(outputs.filter(o => !Ssl.sinkPair(o.name)).map(o => o.name))
  readonly property string device: onSsl ? "ssl" : output

  function deviceLabel(name) {
    if (name === "ssl") return "SSL 12"
    var o = outputs.find(s => s.name === name)
    return o ? o.description : name
  }

  function stepDevice(delta) {
    var i = devices.indexOf(device)
    root.pickDevice(devices[((i < 0 ? 0 : i) + delta + devices.length) % devices.length])
  }

  readonly property bool muted: !!node && !!node.audio && node.audio.muted
  readonly property real volume: node && node.audio ? node.audio.volume : 0
  readonly property int channels: Mixer.channelCount(node)
  readonly property string title: node && node.isStream ? Mixer.streamLabel(node) : Mixer.nodeLabel(node)

  function setVolume(v) {
    if (node && node.audio) node.audio.volume = v
  }

  function toggleMute() {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  visible: !!node
  implicitWidth: Math.max(150, 64 + channels * 9)
  color: "transparent"
  border.width: 1
  border.color: term.dim

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 4

    Text {
      Layout.fillWidth: true
      text: root.title
      elide: Text.ElideRight
      color: root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.size
      font.bold: true
    }

    Text {
      Layout.fillWidth: true
      text: "#" + (root.node ? root.node.id : "?")
        + "  " + root.channels + "ch"
        + (root.node && root.node.isStream ? "  " + Mixer.streamKind(root.node) : "")

      elide: Text.ElideRight
      color: root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 8

      PeakMeter {
        Layout.fillWidth: true
        Layout.fillHeight: true
        term: root.term
        node: root.node
        active: root.active
      }

      VolumeFader {
        Layout.fillHeight: true
        Layout.bottomMargin: root.term.small + 2
        term: root.term
        value: root.volume
        muted: root.muted
        onMoved: v => root.setVolume(v)
      }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    Text {
      text: root.muted ? "vol  muted" : "vol  " + Mixer.percent(root.volume)
      color: root.muted ? root.term.urgent : root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.size
    }

    RowLayout {
      visible: root.canRoute
      Layout.fillWidth: true
      spacing: 2
      TermButton {
        term: root.term
        size: root.term.small
        text: "<"
        enabled: root.devices.length > 1
        onClicked: root.stepDevice(-1)
      }
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: "→ " + root.deviceLabel(root.device)
        color: root.term.foreground
        font.family: root.term.font
        font.pixelSize: root.term.small
      }
      TermButton {
        term: root.term
        size: root.term.small
        text: ">"
        enabled: root.devices.length > 1
        onClicked: root.stepDevice(1)
      }
    }

    // Where on the SSL 12 this app is heard; any combination.
    GridLayout {
      visible: root.canRoute && root.onSsl && root.canTarget
      Layout.fillWidth: true
      columns: 2
      columnSpacing: 2
      rowSpacing: 2
      Repeater {
        model: Ssl.APP_TARGETS
        TermButton {
          required property var modelData
          Layout.fillWidth: true
          term: root.term
          size: root.term.small
          text: modelData[0]
          checked: !!root.targets[modelData[1]]
          onClicked: root.toggleTarget(modelData[1])
        }
      }
    }

    RowLayout {
      spacing: 6
      TermButton {
        term: root.term
        text: "mute"
        checked: root.muted
        checkedColor: root.term.urgent
        onClicked: root.toggleMute()
      }
    }
  }
}
