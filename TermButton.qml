import QtQuick

// `[label]` text button. checked inverts it, like a selected terminal cell.
Rectangle {
  id: root

  required property Term term
  property string text: ""
  property bool checked: false
  property color checkedColor: term.accent
  property int size: term.size

  signal clicked()

  implicitWidth: label.implicitWidth + 8
  implicitHeight: label.implicitHeight + 2
  color: checked ? checkedColor : (mouse.containsMouse && enabled ? term.hover : "transparent")

  Text {
    id: label
    anchors.centerIn: parent
    text: "[" + root.text + "]"
    color: root.checked ? root.term.background : (root.enabled ? root.term.foreground : root.term.dim)
    font.family: root.term.font
    font.pixelSize: root.size
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
