pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// SSL 360°'s AUX MASTER for the bus the faders are on: FOLLOW MIX 1-2, CUT,
// MONO and the bus level. On MIX 1-2 it just says where that mix goes.
// Line 3-4 are two mono outputs on the card, so with douze's `line4` each
// output gets its own FOLLOW and level (CUT and MONO stay on the pair).
Rectangle {
  id: root

  required property Term term
  required property var douze
  required property var bus          // entry of Ssl.BUSES

  readonly property var st: douze.st
  readonly property bool isMix: bus.id === "mix"
  readonly property bool canModes: douze.has("bus_modes")
  readonly property var outputs: Ssl.busOutputs(bus, douze.has("line4"))
  readonly property var follows: outputs.map(o => Ssl.busMode(st, o.master, "follow"))
  readonly property int following: follows.filter(f => f === true).length

  implicitHeight: column.implicitHeight + 8
  color: "transparent"
  border.width: 1
  border.color: term.dim

  component ModeKey: TermButton {
    id: key
    property string mode: ""
    property string master: root.bus.master
    readonly property var on: Ssl.busMode(root.st, master, mode)
    visible: !root.isMix && root.canModes
    term: root.term
    size: root.term.small
    checked: on === true
    checkedColor: mode === "cut" ? root.term.urgent : root.term.accent
    onClicked: root.douze.api({ cmd: "bus", bus: key.master, mode: key.mode, on: key.on !== true })
  }

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: 4
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: root.isMix ? "MIX 1-2" : "AUX " + root.bus.name
        color: root.term.accent
        font.family: root.term.font
        font.pixelSize: root.term.small
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.isMix
          ? "main mix → monitor outs (level and keys on the right) · HP A, HP B and LINE 3-4 copy it while FOLLOW is on"
          : !root.canModes ? "FOLLOW / CUT / MONO need a newer douze"
          : root.following === root.outputs.length ? "copies MIX 1-2 · faders below unused"
          : root.following > 0 ? "out " + root.outputs.filter((o, i) => root.follows[i] === true).map(o => o.label.split(" ")[1]).join(", ")
              + " copies MIX 1-2 · faders below feed the other"
          : root.follows.some(f => f === false) ? "own cue mix · faders below = sends"
          : "follow not set yet (card default)"
        color: root.following > 0 ? root.term.accent : root.term.dim
        font.family: root.term.font
        font.pixelSize: root.term.small
      }

      ModeKey { mode: "cut"; text: "CUT" }
      ModeKey { mode: "mono"; text: "MONO" }
    }

    // One row per output: its FOLLOW and level.
    Repeater {
      model: root.isMix ? [] : root.outputs

      RowLayout {
        id: out
        required property var modelData
        Layout.fillWidth: true
        spacing: 8

        Text {
          visible: !!out.modelData.label
          Layout.preferredWidth: root.term.small * 4
          text: out.modelData.label
          color: root.term.foreground
          font.family: root.term.font
          font.pixelSize: root.term.small
        }
        ModeKey {
          master: out.modelData.master
          mode: "follow"
          text: "FOLLOW MIX 1-2"
        }
        HSlider {
          Layout.fillWidth: true
          term: root.term
          label: "level"
          labelWidth: root.term.small * 3
          from: -60
          to: 12
          reset: 0
          value: Ssl.master(root.st, out.modelData.master)
          onMoved: v => root.douze.send("master:" + out.modelData.master,
                                        { cmd: "master", bus: out.modelData.master, db: v })
        }
      }
    }
  }
}
