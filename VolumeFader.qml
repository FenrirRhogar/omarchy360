import QtQuick

// Thin vertical fader: drag or scroll. Emits moved(v) with v in 0..max, the
// same 0..1(+boost) scale PwNodeAudio.volume uses (1.0 = 100%).
Item {
  id: root

  required property Term term
  property real value: 0
  property real max: 1.5
  property bool muted: false

  signal moved(real value)

  implicitWidth: 18

  readonly property real handleH: 6
  readonly property real travel: height - handleH
  function yFor(v) { return (1 - Math.max(0, Math.min(max, v)) / max) * travel }
  function set(v) { root.moved(Math.max(0, Math.min(max, v))) }

  // Track and fill
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
    height: root.travel - root.yFor(root.value)
    color: root.muted ? root.term.dim : root.term.accent
  }

  // 100% mark
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.yFor(1.0) + root.handleH / 2
    width: parent.width
    height: 1
    color: root.term.dim
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.yFor(root.value)
    width: parent.width
    height: root.handleH
    color: drag.pressed ? root.term.accent : root.term.foreground
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    cursorShape: Qt.SizeVerCursor
    preventStealing: true
    function apply(y) { root.set((1 - (y - root.handleH / 2) / root.travel) * root.max) }
    onPressed: mouse => apply(mouse.y)
    onPositionChanged: mouse => { if (pressed) apply(mouse.y) }
    onDoubleClicked: root.set(1.0)
    onWheel: wheel => root.set(root.value + (wheel.angleDelta.y > 0 ? 0.02 : -0.02))
  }
}
