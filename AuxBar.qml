pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// SSL 360°'s AUX MASTER for the bus the faders are on: FOLLOW MIX 1-2, CUT,
// MONO and the bus level. On MIX 1-2 it just says where that mix goes.
Rectangle {
  id: root

  required property Term term
  required property var douze
  required property var bus          // entry of Ssl.BUSES

  readonly property var st: douze.st
  readonly property bool isMix: bus.id === "mix"
  readonly property var follow: Ssl.busMode(st, bus.master, "follow")
  readonly property bool canModes: douze.has("bus_modes")

  implicitHeight: row.implicitHeight + 8
  color: "transparent"
  border.width: 1
  border.color: term.dim

  component ModeKey: TermButton {
    id: key
    property string mode: ""
    readonly property var on: Ssl.busMode(root.st, root.bus.master, mode)
    term: root.term
    size: root.term.small
    checked: on === true
    checkedColor: mode === "cut" ? root.term.urgent : root.term.accent
    onClicked: root.douze.api({ cmd: "bus", bus: root.bus.master, mode: key.mode, on: key.on !== true })
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.margins: 4
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 8

    Text {
      text: root.isMix ? "MIX 1-2" : "AUX " + root.bus.name
      color: root.term.accent
      font.family: root.term.font
      font.pixelSize: root.term.small
      font.bold: true
    }

    Text {
      visible: root.isMix
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: "main mix → monitor outs (level and keys on the right) · HP A, HP B and LINE 3-4 copy it while FOLLOW is on"
      color: root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }

    ModeKey { visible: !root.isMix && root.canModes; mode: "follow"; text: "FOLLOW MIX 1-2" }
    ModeKey { visible: !root.isMix && root.canModes; mode: "cut"; text: "CUT" }
    ModeKey { visible: !root.isMix && root.canModes; mode: "mono"; text: "MONO" }

    HSlider {
      visible: !root.isMix
      Layout.fillWidth: true
      term: root.term
      label: "level"
      labelWidth: root.term.small * 3
      from: -60
      to: 12
      reset: 0
      value: Ssl.master(root.st, root.bus.master)
      onMoved: v => root.douze.send("master:" + root.bus.master, { cmd: "master", bus: root.bus.master, db: v })
    }

    Text {
      visible: !root.isMix
      Layout.preferredWidth: root.term.small * 22
      elide: Text.ElideRight
      text: !root.canModes ? "FOLLOW / CUT / MONO need a newer douze"
        : root.follow === true ? "copies MIX 1-2 · faders below unused"
        : root.follow === false ? "own cue mix · faders below = sends"
        : "follow not set yet (card default)"
      color: root.follow === true ? root.term.accent : root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
  }
}
