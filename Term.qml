import QtQuick
import qs.Commons
import qs.Commons as Commons

// Theme tokens every component draws with: the shell's menu palette and
// font, so the mixer follows the active Omarchy theme.
QtObject {
  readonly property color foreground: Commons.Color.menu.text
  readonly property color background: Commons.Color.menu.background
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color dim: Commons.Color.muted
  readonly property color hover: Commons.Color.menu.selectedBackground
  readonly property string font: Style.font.family
  readonly property int size: Style.font.body
  readonly property int small: Style.font.caption
}
