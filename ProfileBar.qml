pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "Ssl.js" as Ssl

// SSL 360°'s PROFILE box over douze's profiles (~/.config/sslctl/profiles):
// pick one, LOAD it onto the card, SAVE over it, SAVE AS a new name, DELETE
// (asks SURE? / NO, and gives up after 4 s).
ColumnLayout {
  id: root

  required property Term term
  required property var douze

  signal typingDone()

  readonly property var st: douze.st
  readonly property var profiles: st && st._profiles ? st._profiles : []
  readonly property string loaded: st && st.profile ? st.profile : ""
  readonly property bool dirty: !!(st && st.profile_dirty)
  property string picked: ""
  readonly property string current: picked && profiles.indexOf(picked) !== -1 ? picked
    : profiles.indexOf(loaded) !== -1 ? loaded : (profiles[0] || "")
  property bool confirmDelete: false

  onCurrentChanged: confirmDelete = false

  function saveAs() {
    var name = nameInput.text.trim()
    if (!name) return
    douze.api({ cmd: "profile-save", name: name })
    picked = name
    nameInput.text = ""
    nameInput.focus = false
    root.typingDone()
  }

  spacing: 4

  RowLayout {
    Layout.fillWidth: true
    spacing: 6
    Text {
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: root.loaded ? "loaded: " + root.loaded + (root.dirty ? " *" : "") : "no profile loaded"
      color: root.dirty ? root.term.accent : root.term.dim
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
    TermButton {
      term: root.term
      size: root.term.small
      text: "<"
      enabled: root.profiles.length > 1
      onClicked: root.picked = Ssl.cycle(root.profiles, root.current, -1)
    }
    Text {
      Layout.preferredWidth: root.term.small * 7
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.current || "--"
      color: root.term.foreground
      font.family: root.term.font
      font.pixelSize: root.term.small
    }
    TermButton {
      term: root.term
      size: root.term.small
      text: ">"
      enabled: root.profiles.length > 1
      onClicked: root.picked = Ssl.cycle(root.profiles, root.current, 1)
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 3
    TermButton {
      Layout.fillWidth: true
      term: root.term
      size: root.term.small
      text: "LOAD"
      enabled: !!root.current
      onClicked: root.douze.api({ cmd: "profile-load", name: root.current })
    }
    TermButton {
      Layout.fillWidth: true
      term: root.term
      size: root.term.small
      text: "SAVE"
      enabled: !!root.current
      onClicked: root.douze.api({ cmd: "profile-save", name: root.current })
    }
    TermButton {
      Layout.fillWidth: true
      term: root.term
      size: root.term.small
      text: root.confirmDelete ? "SURE?" : "DELETE"
      enabled: !!root.current
      checked: root.confirmDelete
      checkedColor: root.term.urgent
      onClicked: {
        if (!root.confirmDelete) {
          root.confirmDelete = true
          return
        }
        root.douze.api({ cmd: "profile-delete", name: root.current })
        root.picked = ""
        root.confirmDelete = false
      }
    }
    TermButton {
      visible: root.confirmDelete
      term: root.term
      size: root.term.small
      text: "NO"
      onClicked: root.confirmDelete = false
    }
  }

  // An unanswered "SURE?" cancels itself.
  Timer {
    interval: 4000
    running: root.confirmDelete
    onTriggered: root.confirmDelete = false
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 6
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: root.term.small + 8
      color: "transparent"
      border.width: 1
      border.color: nameInput.activeFocus ? root.term.accent : root.term.dim

      TextInput {
        id: nameInput
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: root.term.foreground
        selectionColor: root.term.accent
        font.family: root.term.font
        font.pixelSize: root.term.small
        maximumLength: 40
        // douze keeps letters, digits, space, - and _ in profile file names
        validator: RegularExpressionValidator { regularExpression: /[\w \-]*/ }
        onAccepted: root.saveAs()
        Keys.onEscapePressed: {
          text = ""
          focus = false
          root.typingDone()
        }

        Text {
          visible: !nameInput.text && !nameInput.activeFocus
          anchors.verticalCenter: parent.verticalCenter
          text: "new profile name"
          color: root.term.dim
          font: nameInput.font
        }
      }
    }
    TermButton {
      term: root.term
      size: root.term.small
      text: "SAVE AS"
      enabled: nameInput.text.trim() !== ""
      onClicked: root.saveAs()
    }
  }
}
