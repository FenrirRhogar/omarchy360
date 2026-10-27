pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// One SSL 360° channel strip: preamp keys (analogue) or DIR (playback),
// meter, fader, pan, SOLO and CUT. A linked pair is one stereo strip that
// drives both mono channels. With an aux bus selected the fader edits that
// bus's cue-mix send instead.
Rectangle {
  id: root

  required property Term term
  required property var douze
  required property var strip       // entry of Ssl.strips()
  property string bus: "mix"
  property bool following: false    // aux bus follows MIX 1-2: sends unused

  readonly property var st: douze.st
  readonly property var ids: strip.ids
  readonly property string first: ids[0]
  readonly property var c: Ssl.channel(st, first)
  readonly property bool inMix: bus === "mix"
  readonly property var level: Ssl.level(st, first, bus)
  readonly property bool dirOn: !!(st && st.dir && st.dir[first])
  readonly property bool silent: Ssl.isOff(level) || (inMix && c.mute) || following
  readonly property bool canLink: douze.has("ui") && !!strip.pair
    && (strip.linked || strip.pair[0] === first)
  // Pan on the main mix, or (douze `send_pan`) of the send to the aux bus.
  readonly property bool canSendPan: !inMix && douze.has("send_pan")
  readonly property real pan: inMix
    ? (strip.linked ? Ssl.linkedPan(st, strip.pair) : Number(c.pan) || 0)
    : (strip.linked ? Ssl.pairPan(Ssl.sendPan(st, ids[0], bus), Ssl.sendPan(st, ids[1], bus))
                    : Ssl.sendPan(st, first, bus))

  function each(fn) {
    for (var i = 0; i < ids.length; i++) fn(ids[i], i)
  }

  function setLevel(db) {
    each(id => {
      if (inMix) douze.send("fader:" + id, { cmd: "fader", ch: id, db: db })
      else douze.send("route:" + id + ":" + bus, { cmd: "route", ch: id, bus: bus, level: db })
    })
  }

  function setPan(v) {
    var p = strip.linked ? Ssl.linkedPans(v) : [v]
    each((id, i) => {
      if (inMix) douze.send("pan:" + id, { cmd: "pan", ch: id, pos: p[i] })
      else douze.send("sendpan:" + id + ":" + bus, { cmd: "route", ch: id, bus: bus, pan: p[i] })
    })
  }

  function setAll(cmd, on) {
    each(id => douze.api({ cmd: cmd, ch: id, on: on }))
  }

  // Link: copy the left channel onto the right and spread them hard L/R, as
  // SSL 360° does. Unlink: both back to centre, levels kept.
  function setLink(on) {
    var pair = strip.pair
    var links = Object.assign({}, st && st.ui && st.ui.links ? st.ui.links : {})
    links[Ssl.pairKey(pair)] = on
    douze.api({ cmd: "ui", key: "links", value: links })
    var l = Ssl.channel(st, pair[0])
    if (on) {
      douze.api({ cmd: "fader", ch: pair[1], db: l.fader })
      douze.api({ cmd: "mute", ch: pair[1], on: l.mute })
      douze.api({ cmd: "solo", ch: pair[1], on: l.solo })
      douze.api({ cmd: "pan", ch: pair[0], pos: -100 })
      douze.api({ cmd: "pan", ch: pair[1], pos: 100 })
      if (douze.has("send_pan")) Ssl.SEND_BUSES.forEach(b => {
        douze.api({ cmd: "route", ch: pair[0], bus: b, pan: -100 })
        douze.api({ cmd: "route", ch: pair[1], bus: b, pan: 100 })
      })
    } else {
      douze.api({ cmd: "pan", ch: pair[0], pos: 0 })
      douze.api({ cmd: "pan", ch: pair[1], pos: 0 })
      if (douze.has("send_pan")) Ssl.SEND_BUSES.forEach(b => {
        douze.api({ cmd: "route", ch: pair[0], bus: b, pan: 0 })
        douze.api({ cmd: "route", ch: pair[1], bus: b, pan: 0 })
      })
    }
  }

  function preampOn(name) {
    for (var i = 0; i < strip.preamps.length; i++)
      if (!Ssl.preamp(st, name, strip.preamps[i])) return false
    return strip.preamps.length > 0
  }

  color: "transparent"
  border.width: 1
  border.color: inMix && c.solo ? term.accent : strip.linked ? Qt.alpha(term.accent, 0.5) : term.dim

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 6
    spacing: 4

    Text {
      Layout.fillWidth: true
      text: root.strip.name
      elide: Text.ElideRight
      color: root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.small
      font.bold: true
    }
    Text {
      Layout.fillWidth: true
      text: root.strip.sub
      elide: Text.ElideRight
      color: root.strip.linked ? root.term.accent : root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    // Preamp keys / DIR; ADAT strips keep the space empty.
    GridLayout {
      Layout.fillWidth: true
      Layout.fillHeight: false
      Layout.minimumHeight: (root.term.small + 4) * 2 + 2
      Layout.maximumHeight: (root.term.small + 4) * 2 + 2
      columns: 2
      columnSpacing: 2
      rowSpacing: 2

      Repeater {
        model: root.strip.preamps.length ? Ssl.PREAMP_KEYS : []
        TermButton {
          required property var modelData
          readonly property bool on: root.preampOn(modelData[1])
          Layout.fillWidth: true
          term: root.term
          size: root.term.small
          text: modelData[0]
          checked: on
          checkedColor: modelData[1] === "48v" ? root.term.urgent : root.term.accent
          onClicked: {
            for (var i = 0; i < root.strip.preamps.length; i++)
              root.douze.api({ cmd: "preamp", name: modelData[1], ch: root.strip.preamps[i], on: !on })
          }
        }
      }
      TermButton {
        visible: !!root.strip.dir
        Layout.fillWidth: true
        Layout.columnSpan: 2
        term: root.term
        size: root.term.small
        text: "DIR"
        checked: root.dirOn
        onClicked: root.douze.api({ cmd: "dir", ch: root.first, on: !root.dirOn })
      }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 6

      LevelMeter {
        Layout.fillWidth: true
        Layout.fillHeight: true
        term: root.term
        values: Ssl.pick(root.douze.meters, root.strip.meters)
      }

      DbFader {
        Layout.fillHeight: true
        term: root.term
        value: root.level
        dimmed: root.silent
        onMoved: db => root.setLevel(db)
      }
    }

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: root.following ? "follows mix" : Ssl.fmtDb(root.level) + " dB"
      color: root.silent ? root.term.dim : root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.small
    }

    HSlider {
      Layout.fillWidth: true
      visible: root.inMix || root.canSendPan
      term: root.term
      valueWidth: root.term.small * 2.2
      from: -100
      to: 100
      step: 1
      reset: 0
      value: root.pan
      valueText: Ssl.fmtSendPan(root.pan, root.bus)
      onMoved: v => root.setPan(v)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 2

      TermButton {
        visible: root.inMix
        Layout.fillWidth: true
        term: root.term
        size: root.term.small
        text: "SOLO"
        checked: root.c.solo
        onClicked: root.setAll("solo", !root.c.solo)
      }
      TermButton {
        visible: root.inMix
        Layout.fillWidth: true
        term: root.term
        size: root.term.small
        text: "CUT"
        checked: root.c.mute
        checkedColor: root.term.urgent
        onClicked: root.setAll("mute", !root.c.mute)
      }
      TermButton {
        visible: !root.inMix
        Layout.fillWidth: true
        term: root.term
        size: root.term.small
        text: Ssl.isOff(root.level) ? "SEND OFF" : "SEND ON"
        checked: !Ssl.isOff(root.level)
        onClicked: root.each(id => root.douze.api({ cmd: "route", ch: id, bus: root.bus, level: Ssl.isOff(root.level) ? 0 : "off" }))
      }
    }

    // Stereo link (odd channel of a pair, or the linked strip)
    TermButton {
      Layout.fillWidth: true
      visible: root.canLink
      term: root.term
      size: root.term.small
      text: root.strip.linked ? "∞ UNLINK" : "∞ LINK " + (root.strip.pair ? root.strip.pair[1].replace("a", "") : "")
      checked: root.strip.linked
      onClicked: root.setLink(!root.strip.linked)
    }
    Item {
      Layout.fillWidth: true
      visible: !root.canLink
      implicitHeight: root.term.small + 2
    }
  }
}
