pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// SSL 360°-style control for the SSL 12, independent of the window hosting
// it. Tab 1 is the SSL 12 mixer + monitor section (via the douze daemon),
// tab 2 the per-app volumes (PipeWire).
Item {
  id: root

  property bool active: false
  property int tab: 0
  property int busIndex: 0
  readonly property var busInfo: Ssl.BUSES[busIndex]
  readonly property string bus: busInfo.id
  readonly property bool canAdat: client.has("adat") && client.has("ui")
  readonly property bool showAdat: canAdat && !!(client.st && client.st.ui && client.st.ui.showAdat)
  readonly property var strips: Ssl.strips(client.st, showAdat)
  // SSL 360° order: inputs, talkback, playback returns
  readonly property var inputStrips: strips.filter(s => s.ids[0].indexOf("pb") !== 0)
  readonly property var playStrips: strips.filter(s => s.ids[0].indexOf("pb") === 0)
  // An aux bus with FOLLOW MIX 1-2 on copies the main mix: its sends are unused.
  readonly property bool following: bus !== "mix"
    && Ssl.busOutputs(busInfo, client.has("line4")).every(o => Ssl.busMode(client.st, o.master, "follow") === true)
  readonly property var tabNames: ["mixer", "apps"]

  signal closeRequested()
  signal focusRequested()     // a text field is done; give keys back to the view

  readonly property Term term: Term {}

  Douze {
    id: client
    active: root.active
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) { root.closeRequested(); return true }
    if (event.key === Qt.Key_1 || event.key === Qt.Key_2) { root.tab = event.key - Qt.Key_1; return true }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { root.tab = 1 - root.tab; return true }
    if (root.tab === 0 && event.key === Qt.Key_Left) { root.busIndex = (root.busIndex + 3) % 4; return true }
    if (root.tab === 0 && event.key === Qt.Key_Right) { root.busIndex = (root.busIndex + 1) % 4; return true }
    return false
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      Text {
        text: "Omarchy360 ── SSL 12"
        color: root.term.accent
        font.family: root.term.font
        font.pixelSize: root.term.size
        font.bold: true
      }
      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: !client.active ? ""
          : !client.online ? "○ douze offline"
          : !client.device ? "○ SSL 12 not connected"
          : "● connected   " + (client.clock / 1000) + " kHz"
            + (client.st && client.st._clock_mismatch ? "  ⚠ clock mismatch" : "")
            + (client.error ? "   ! " + client.error : "")
        color: client.device ? root.term.dim : root.term.urgent
        font.family: root.term.font
        font.pixelSize: root.term.size
      }
      Repeater {
        model: root.tabNames
        TermButton {
          required property int index
          required property string modelData
          term: root.term
          text: (index + 1) + " " + modelData
          checked: root.tab === index
          onClicked: root.tab = index
        }
      }
      TermButton {
        term: root.term
        text: "esc"
        onClicked: root.closeRequested()
      }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.term.dim }

    // ── Mixer ───────────────────────────────────────────────────────────
    RowLayout {
      visible: root.tab === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Fader target: the main mix or one aux bus's own cue mix.
        RowLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: "faders →"
            color: root.term.dim
            font.family: root.term.font
            font.pixelSize: root.term.size
          }
          Repeater {
            model: Ssl.BUSES
            TermButton {
              required property int index
              required property var modelData
              term: root.term
              text: modelData.name
              checked: root.busIndex === index
              onClicked: root.busIndex = index
            }
          }
          Item { Layout.fillWidth: true }
          TermButton {
            visible: root.canAdat
            term: root.term
            size: root.term.small
            text: (root.showAdat ? "− " : "+ ") + "ADAT 1-8"
            checked: root.showAdat
            onClicked: client.api({ cmd: "ui", key: "showAdat", value: !root.showAdat })
          }
        }

        AuxBar {
          Layout.fillWidth: true
          term: root.term
          douze: client
          bus: root.busInfo
        }

        Flickable {
          id: stripView
          Layout.fillWidth: true
          Layout.fillHeight: true
          enabled: client.device
          opacity: client.device ? 1 : 0.4
          clip: true
          contentWidth: stripRow.width
          contentHeight: height
          flickableDirection: Flickable.HorizontalFlick
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentWidth > width

          readonly property int count: root.strips.length + 1
          readonly property real stripWidth: Math.max(96, (width - 6 * (count - 1)) / Math.max(1, count))

          Row {
            id: stripRow
            height: stripView.height
            spacing: 6
            Repeater {
              model: root.inputStrips
              SslStrip {
                required property var modelData
                width: stripView.stripWidth
                height: stripRow.height
                term: root.term
                douze: client
                strip: modelData
                bus: root.bus
                following: root.following
              }
            }
            TalkbackStrip {
              width: stripView.stripWidth
              height: stripRow.height
              term: root.term
              douze: client
            }
            Repeater {
              model: root.playStrips
              SslStrip {
                required property var modelData
                width: stripView.stripWidth
                height: stripRow.height
                term: root.term
                douze: client
                strip: modelData
                bus: root.bus
                following: root.following
              }
            }
          }
        }

        // Scroll position when the strips don't fit (drag, wheel or this bar)
        Item {
          Layout.fillWidth: true
          implicitHeight: 6
          visible: stripView.interactive
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.term.dim }
          Rectangle {
            x: stripView.visibleArea.xPosition * parent.width
            width: stripView.visibleArea.widthRatio * parent.width
            height: parent.height
            color: barDrag.pressed ? root.term.accent : root.term.foreground
          }
          MouseArea {
            id: barDrag
            anchors.fill: parent
            function seek(x) {
              var ratio = stripView.visibleArea.widthRatio
              var pos = Math.max(0, Math.min(1 - ratio, x / width - ratio / 2))
              stripView.contentX = pos * stripView.contentWidth
            }
            onPressed: mouse => seek(mouse.x)
            onPositionChanged: mouse => { if (pressed) seek(mouse.x) }
          }
        }
      }

      Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: root.term.dim }

      MonitorSection {
        Layout.preferredWidth: 270
        Layout.maximumWidth: 270
        Layout.fillHeight: true
        term: root.term
        douze: client
        onTypingDone: root.focusRequested()
        enabled: client.device
        opacity: client.device ? 1 : 0.4
      }
    }

    AppsPage {
      visible: root.tab === 1
      Layout.fillWidth: true
      Layout.fillHeight: true
      term: root.term
      douze: client
      active: root.active && root.tab === 1
    }

    Text {
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: root.tab === 0 && client.active && !client.online
        ? "douze is not running: systemctl --user start douze (setup: see the plugin README)"
        : "1-2/tab page · ←/→ fader bus · drag/scroll faders · dbl-click = 0 dB · super+alt+m toggle · esc close"
      color: root.tab === 0 && client.active && !client.online ? root.term.urgent : root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
  }
}
