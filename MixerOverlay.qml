import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Overlay entry point. The shell calls open(payload) on summon and close() on
// hide; the mixer itself lives in SslView.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property int windowWidth: 1200
  readonly property int windowHeight: 800

  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "fenrirrhogar.omarchy360")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "fenrirrhogar-omarchy360"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: surface
      anchors.centerIn: parent
      width: Math.min(root.windowWidth, panel.width - Style.gapsOut * 2)
      height: Math.min(root.windowHeight, panel.height - Style.gapsOut * 2)
      radius: Style.cornerRadius
      color: Commons.Color.menu.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => { event.accepted = view.handleKey(event) }
      }

      SslView {
        id: view
        anchors.fill: parent
        anchors.topMargin: surface.contentTopInset
        anchors.rightMargin: surface.contentRightInset
        anchors.bottomMargin: surface.contentBottomInset
        anchors.leftMargin: surface.contentLeftInset
        active: root.opened
        onCloseRequested: root.dismiss()
        onFocusRequested: keyCatcher.forceActiveFocus()
      }
    }
  }
}
