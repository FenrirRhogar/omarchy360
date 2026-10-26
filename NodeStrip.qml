import QtQuick
import QtQuick.Layouts
import "Mixer.js" as Mixer

// One app stream as a strip: name, id/channels, live meters, volume fader
// and mute.
Rectangle {
  id: root

  required property Term term
  required property var node
  property bool active: false

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
