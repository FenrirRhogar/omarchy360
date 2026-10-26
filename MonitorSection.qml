pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// SSL 360°'s right-hand column: bus meters, monitor level, monitoring keys,
// DIM / ALT settings, the front-panel USER button mapping, loopback source
// and profiles. Aux bus levels live in AuxBar.
ColumnLayout {
  id: root

  required property Term term
  required property var douze

  readonly property var st: douze.st

  signal typingDone()

  spacing: 6

  component Heading: Text {
    Layout.fillWidth: true
    color: root.term.accent
    font.family: root.term.font
    font.pixelSize: root.term.small
    font.bold: true
  }

  // "label  [< value >]" row; clicking cycles through `options`.
  component Choice: RowLayout {
    id: choice
    property string label: ""
    property var options: []
    property string current: ""
    signal picked(string value)
    spacing: 6
    Text {
      Layout.fillWidth: true
      text: choice.label
      color: root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
    TermButton {
      term: root.term
      size: root.term.small
      text: "<"
      onClicked: choice.picked(Ssl.cycle(choice.options, choice.current, -1))
    }
    Text {
      Layout.preferredWidth: root.term.small * 6
      horizontalAlignment: Text.AlignHCenter
      text: choice.current
      color: root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
    TermButton {
      term: root.term
      size: root.term.small
      text: ">"
      onClicked: choice.picked(Ssl.cycle(choice.options, choice.current, 1))
    }
  }

  Heading { text: "── MONITORING" }

  // Bus meters and the monitor level fader
  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 140
    spacing: 8

    Repeater {
      model: Ssl.BUS_METERS
      ColumnLayout {
        id: busMeter
        required property var modelData
        Layout.fillHeight: true
        spacing: 2
        LevelMeter {
          Layout.fillHeight: true
          Layout.preferredWidth: 14
          Layout.alignment: Qt.AlignHCenter
          term: root.term
          values: Ssl.pick(root.douze.meters, busMeter.modelData.meters)
        }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: busMeter.modelData.name
          color: root.term.dim
          font.family: root.term.font
          font.pixelSize: root.term.small - 1
        }
      }
    }

    Item { Layout.fillWidth: true }

    ColumnLayout {
      Layout.fillHeight: true
      spacing: 2
      DbFader {
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 28
        term: root.term
        value: Ssl.master(root.st, "monitor") === undefined ? "off" : Ssl.master(root.st, "monitor")
        dimmed: Ssl.master(root.st, "monitor") === undefined || Ssl.monitoring(root.st, "cut")
        onMoved: db => root.douze.send("master:monitor", { cmd: "master", bus: "monitor", db: db })
      }
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "MON"
        color: root.term.dim
        font.family: root.term.font
        font.pixelSize: root.term.small - 1
      }
    }
  }

  Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignRight
    readonly property var m: Ssl.master(root.st, "monitor")
    text: "monitor " + (m === undefined ? "-- (not set)" : Ssl.fmtDb(m) + " dB")
    color: root.term.foreground
    font.family: root.term.font
    font.pixelSize: root.term.small
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 3
    columnSpacing: 3
    rowSpacing: 3
    Repeater {
      model: Ssl.MON_KEYS
      TermButton {
        required property var modelData
        readonly property bool on: Ssl.monitoring(root.st, modelData[1])
        Layout.fillWidth: true
        term: root.term
        text: modelData[0]
        checked: on
        checkedColor: modelData[1] === "cut" ? root.term.urgent : root.term.accent
        onClicked: root.douze.api({ cmd: "mon", name: modelData[1], on: !on })
      }
    }
  }

  TermButton {
    Layout.fillWidth: true
    term: root.term
    size: root.term.small
    text: "ALT SPK (out 3-4) " + (root.st && root.st.alt_spk ? "on" : "off")
    checked: !!(root.st && root.st.alt_spk)
    onClicked: root.douze.api({ cmd: "altspk", on: !(root.st && root.st.alt_spk) })
  }

  HSlider {
    Layout.fillWidth: true
    term: root.term
    label: "dim level"
    from: -40
    to: 0
    reset: -12
    value: root.st && root.st.monitoring_levels ? root.st.monitoring_levels.dimlevel : undefined
    onMoved: v => root.douze.send("dimlevel", { cmd: "dimlevel", db: v })
  }
  HSlider {
    Layout.fillWidth: true
    term: root.term
    label: "alt trim"
    from: -12
    to: 12
    reset: 0
    value: root.st && root.st.monitoring_levels ? root.st.monitoring_levels.alttrim : undefined
    onMoved: v => root.douze.send("alttrim", { cmd: "alttrim", db: v })
  }
  Heading { text: "── USER BUTTONS" }

  Repeater {
    model: Ssl.USER_BUTTONS
    Choice {
      required property var modelData
      Layout.fillWidth: true
      label: modelData[0] + " key"
      options: root.douze.has("gui") ? Ssl.USER_FNS : Ssl.USER_FNS.filter(f => f !== "gui")
      current: Ssl.userFn(root.st, modelData[1])
      onPicked: value => root.douze.api({ cmd: "user", button: modelData[1], fn: value })
    }
  }

  Heading { text: "── CONTROL" }

  Choice {
    Layout.fillWidth: true
    label: "loopback"
    options: Ssl.LOOPBACK
    current: (root.st && root.st.loopback) || "none"
    onPicked: value => root.douze.api({ cmd: "loopback", source: value })
  }

  Heading { text: "── PROFILE" }

  ProfileBar {
    Layout.fillWidth: true
    term: root.term
    douze: root.douze
    onTypingDone: root.typingDone()
  }
}
