pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar trigger: three tiny faders drawn with Rectangles so the icon doesn't
// depend on a Nerd Font glyph. Click summons the mixer overlay.
BarWidget {
  id: root
  moduleName: "fenrirrhogar.omarchy360"

  readonly property color iconColor: bar ? bar.barForeground : Commons.Color.foreground
  readonly property var capPositions: [0.3, 0.65, 0.45]

  implicitWidth: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  implicitHeight: vertical ? Style.bar.sizeHorizontal : Style.bar.sizeVertical

  function run(command) {
    if (root.bar) root.bar.run(command)
    else Quickshell.execDetached(["sh", "-c", command])
  }

  Row {
    id: icon
    anchors.centerIn: parent
    spacing: Math.max(2, Math.round(root.barSize * 0.12))
    opacity: mouseArea.containsMouse ? 1.0 : 0.85

    Repeater {
      model: root.capPositions

      Item {
        id: cap
        required property real modelData
        width: Math.max(3, Math.round(root.barSize * 0.14))
        height: Math.round(root.barSize * 0.55)

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 1
          height: parent.height
          color: root.iconColor
          opacity: 0.6
        }

        Rectangle {
          width: parent.width
          height: Math.max(2, Math.round(parent.height * 0.22))
          radius: 1
          y: (parent.height - height) * cap.modelData
          color: root.iconColor
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.run("omarchy-shell shell toggle fenrirrhogar.omarchy360")
  }

  readonly property bool tooltipHovered: visible && mouseArea.containsMouse
  readonly property string tooltipText: "Omarchy360 · SSL 12 mixer"
}
