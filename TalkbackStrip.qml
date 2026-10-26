import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// The SSL 12's built-in talkback mic. Its level and routing live in the
// firmware (SSL 360°'s TALKBACK TRIM sends nothing to the card), so the
// strip has a meter and the TALK key but no fader.
Rectangle {
  id: root

  required property Term term
  required property var douze

  readonly property bool talking: Ssl.monitoring(douze.st, "talk")

  color: "transparent"
  border.width: 1
  border.color: talking ? term.accent : term.dim

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 6
    spacing: 4

    Text {
      Layout.fillWidth: true
      text: "TALKBACK"
      elide: Text.ElideRight
      color: root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.small
      font.bold: true
    }
    Text {
      Layout.fillWidth: true
      text: "built-in mic"
      elide: Text.ElideRight
      color: root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    TermButton {
      Layout.fillWidth: true
      term: root.term
      size: root.term.small
      text: "TALK"
      checked: root.talking
      onClicked: root.douze.api({ cmd: "mon", name: "talk", on: !root.talking })
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    LevelMeter {
      Layout.fillWidth: true
      Layout.fillHeight: true
      term: root.term
      values: Ssl.pick(root.douze.meters, Ssl.TALKBACK_METERS)
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "level and routing are fixed in the card"
      color: root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small - 1
    }
  }
}
