pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Mixer.js" as Mixer

// One segmented column per channel over a -60..0 dBFS window. The gap lines
// drawn across the bars give the block-character look without per-cell items.
// Pro-audio nodes (AUX0..n layouts) and streams with unknown channel
// positions (e.g. Spotify) are metered by bin/omarchy360-peaks, because
// PwNodePeakMonitor only captures standard channel positions. Its peaks are
// on the cubic volume scale, so they're cubed back to linear here.
Item {
  id: root

  required property Term term
  property var node: null
  property bool active: false
  readonly property bool auxLayout: Mixer.usesAuxChannels(node)
  readonly property bool unknownLayout: !auxLayout && !!node && node.isStream && !!node.audio
    && node.audio.channels.some(c => c === PwAudioChannel.Unknown)
  readonly property bool external: auxLayout || unknownLayout
  property var externalPeaks: []
  readonly property var peaks: external ? externalPeaks : (monitor.peaks || []).map(p => p * p * p)
  // Fall back to the node's channel count so idle streams show empty bars.
  readonly property int count: external ? Mixer.channelCount(node) : Math.max(peaks.length, Mixer.channelCount(node))
  readonly property int cell: 4
  readonly property var marks: [0, -6, -12, -24, -48]
  readonly property string helper: Qt.resolvedUrl("bin/omarchy360-peaks").toString().replace(/^file:\/\//, "")

  PwNodePeakMonitor {
    id: monitor
    node: root.external ? null : root.node
    enabled: root.active && !root.external && !!root.node
  }

  Process {
    running: root.active && root.external && root.count > 0
    command: root.unknownLayout
      ? [root.helper, "omarchy360-meter-" + root.node.id, String(root.count), "stream", String(root.node.id)]
      : [root.helper, root.node ? root.node.name : "", String(root.count), root.node && root.node.isSink ? "sink" : "source"]
    stdout: SplitParser {
      onRead: line => root.externalPeaks = line.trim().split(" ").map(Number)
    }
    onRunningChanged: if (!running) root.externalPeaks = []
  }

  // dB legend
  Item {
    id: legend
    width: 20
    anchors.top: parent.top
    anchors.bottom: labels.top
    anchors.left: parent.left

    Repeater {
      model: root.marks
      Text {
        required property int modelData
        x: legend.width - width
        y: (-modelData / 60) * legend.height - height / 2
        text: modelData
        color: root.term.dim
        font.family: root.term.font
        font.pixelSize: root.term.small
      }
    }
  }

  RowLayout {
    id: bars
    anchors.top: parent.top
    anchors.bottom: labels.top
    anchors.left: legend.right
    anchors.right: parent.right
    anchors.leftMargin: 4
    spacing: root.count > 8 ? 1 : 3

    Repeater {
      model: root.count

      Rectangle {
        id: bar
        required property int index
        readonly property real level: Mixer.peakPosition(root.peaks[index] || 0)
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(root.term.foreground, 0.07)

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: bar.level * parent.height
          color: bar.level > 0.95 ? root.term.urgent : bar.level > 0.8 ? root.term.accent : root.term.foreground
          Behavior on height { NumberAnimation { duration: 60 } }
        }
      }
    }
  }

  // Segment gaps
  Column {
    anchors.fill: bars
    spacing: root.cell - 1
    Repeater {
      model: Math.max(0, Math.floor(bars.height / root.cell))
      Rectangle { width: bars.width; height: 1; color: root.term.background }
    }
  }

  Text {
    visible: root.count === 0
    anchors.centerIn: bars
    text: root.active ? "no meter" : ""
    horizontalAlignment: Text.AlignHCenter
    color: root.term.dim
    font.family: root.term.font
    font.pixelSize: root.term.small
  }

  RowLayout {
    id: labels
    anchors.left: bars.left
    anchors.right: bars.right
    anchors.bottom: parent.bottom
    spacing: bars.spacing
    height: root.term.small + 2

    Repeater {
      model: root.count
      Text {
        required property int index
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: Mixer.channelLabel(index, root.count)
        color: root.term.dim
        font.family: root.term.font
        font.pixelSize: root.count > 8 ? root.term.small - 2 : root.term.small
      }
    }
  }
}
