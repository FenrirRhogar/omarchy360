pragma ComponentBehavior: Bound
import QtQuick
import "Ssl.js" as Ssl

// Vertical console fader in dB (-inf … +12, 0 dB at 3/4 travel). Drag,
// scroll ±0.5 dB, double-click for 0 dB. Emits moved(db) where db is a
// number or "off".
Item {
  id: root

  required property Term term
  property var value: "off"
  property bool dimmed: false

  signal moved(var db)

  implicitWidth: 22

  // While dragging, show where the hand is rather than the last echo.
  property real dragPos: 0
  readonly property real pos: drag.pressed ? dragPos : Ssl.dbToPos(value)
  readonly property real handleH: 8
  readonly property real travel: height - handleH
  function yFor(p) { return (1 - p) * travel }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    width: 1
    height: parent.height
    color: root.term.dim
  }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: 3
    height: root.travel - root.yFor(root.pos)
    color: root.dimmed ? root.term.dim : root.term.accent
  }

  // Scale ticks: +12, 0, -10, -20, -40
  Repeater {
    model: [12, 0, -10, -20, -40]
    Rectangle {
      required property var modelData
      x: (root.width - width) / 2
      y: root.yFor(Ssl.dbToPos(modelData)) + root.handleH / 2
      width: modelData === 0 ? root.width : root.width / 2
      height: 1
      color: root.term.dim
    }
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.yFor(root.pos)
    width: parent.width
    height: root.handleH
    color: drag.pressed ? root.term.accent : root.term.foreground
    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: 1
      color: root.term.background
    }
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    cursorShape: Qt.SizeVerCursor
    preventStealing: true
    function apply(y) {
      root.dragPos = Math.max(0, Math.min(1, 1 - (y - root.handleH / 2) / root.travel))
      root.moved(Ssl.posToDb(root.dragPos))
    }
    onPressed: mouse => apply(mouse.y)
    onPositionChanged: mouse => { if (pressed) apply(mouse.y) }
    onDoubleClicked: root.moved(0)
    onWheel: wheel => root.moved(Ssl.stepDb(root.value, wheel.angleDelta.y > 0 ? 0.5 : -0.5))
  }
}
