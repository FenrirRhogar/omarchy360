import QtQuick
import QtQuick.Layouts

// "label ────●──── value" row for linear controls (dB levels, pan). Drag or
// scroll; double-click resets. Emits moved(v) rounded to `step`.
RowLayout {
  id: root

  required property Term term
  property string label: ""
  property real from: -60
  property real to: 0
  property real step: 0.5
  property real reset: 0
  property var value: undefined        // undefined = not set on the card yet
  property string valueText: value === undefined ? "--" : Number(value).toFixed(1)
  property int labelWidth: 64
  property real valueWidth: term.small * 3.2

  signal moved(real v)

  readonly property real shown: drag.pressed ? dragValue : (value === undefined ? reset : Number(value))
  property real dragValue: 0

  function clampStep(v) {
    v = Math.max(from, Math.min(to, v))
    return Math.round(v / step) * step
  }

  spacing: 6

  Text {
    visible: root.label !== ""
    Layout.preferredWidth: root.labelWidth
    text: root.label
    color: root.term.dim
    font.family: root.term.font
    font.pixelSize: root.term.small
  }

  Item {
    id: track
    Layout.fillWidth: true
    implicitHeight: 14

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 1
      color: root.term.dim
    }
    Rectangle {
      readonly property real x0: (Math.max(root.from, Math.min(root.to, 0)) - root.from) / (root.to - root.from) * track.width
      readonly property real x1: (root.shown - root.from) / (root.to - root.from) * track.width
      anchors.verticalCenter: parent.verticalCenter
      x: Math.min(x0, x1)
      width: Math.abs(x1 - x0)
      height: 3
      color: root.value === undefined ? root.term.dim : root.term.accent
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x: (root.shown - root.from) / (root.to - root.from) * (track.width - width)
      width: 6
      height: 12
      color: drag.pressed ? root.term.accent : root.value === undefined ? root.term.dim : root.term.foreground
    }

    MouseArea {
      id: drag
      anchors.fill: parent
      cursorShape: Qt.SizeHorCursor
      preventStealing: true
      function apply(x) {
        root.dragValue = root.clampStep(root.from + Math.max(0, Math.min(1, x / track.width)) * (root.to - root.from))
        root.moved(root.dragValue)
      }
      onPressed: mouse => apply(mouse.x)
      onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
      onDoubleClicked: root.moved(root.reset)
      onWheel: wheel => root.moved(root.clampStep(root.shown + (wheel.angleDelta.y > 0 ? root.step : -root.step)))
    }
  }

  Text {
    Layout.preferredWidth: root.valueWidth
    horizontalAlignment: Text.AlignRight
    text: root.valueText
    color: root.term.foreground
    font.family: root.term.font
    font.pixelSize: root.term.small
  }
}
