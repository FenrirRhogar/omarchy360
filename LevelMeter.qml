pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// Segmented peak meter for the SSL 12's own meter words (-60..0 dBFS), one
// bar per value, with a 1.5 s peak hold.
Item {
  id: root

  required property Term term
  property var values: []
  readonly property int cell: 4

  implicitWidth: values.length * 6 + (values.length - 1) * 2

  RowLayout {
    id: bars
    anchors.fill: parent
    spacing: 2

    Repeater {
      model: root.values.length

      Rectangle {
        id: bar
        required property int index
        readonly property real level: Ssl.meterPos(root.values[index])
        property real hold: 0
        property double holdAt: 0
        onLevelChanged: {
          var now = Date.now()
          if (level >= hold || now - holdAt > 1500) {
            hold = level
            holdAt = now
          }
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.alpha(root.term.foreground, 0.07)

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: bar.level * parent.height
          color: bar.level > 0.95 ? root.term.urgent : bar.level > 0.8 ? root.term.accent : root.term.foreground
        }
        Rectangle {
          visible: bar.hold > 0
          y: (1 - bar.hold) * parent.height
          width: parent.width
          height: 1
          color: bar.hold > 0.95 ? root.term.urgent : root.term.accent
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
}
