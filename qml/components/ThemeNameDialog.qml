import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
    id: root
    property bool opened: false
    property bool busy: false
    property string suggestedName: ""
    property string errorMessage: ""
    signal cancelled()
    signal confirmed(string name)
    visible: opened

    function openWith(name) {
        errorMessage = ""
        nameInput.text = name
        opened = true
        Qt.callLater(function() { nameInput.forceActiveFocus(); nameInput.selectAll() })
    }
    function close() { if (!busy) { opened = false; errorMessage = "" } }
    function submit() {
        if (busy) return
        const value = nameInput.text.trim()
        if (value.length === 0) { errorMessage = "Theme name cannot be empty"; return }
        if (value.length > 64) { errorMessage = "Theme name must be 64 characters or fewer"; return }
        errorMessage = ""
        confirmed(value)
    }

    Rectangle { anchors.fill: parent; color: Util.alpha(Color.background, 0.72); MouseArea { anchors.fill: parent; onClicked: { root.close(); root.cancelled() } } }
    Rectangle {
        id: dialog; width: 430; height: 230; anchors.centerIn: parent; radius: 14
        color: Color.popups.background; border.width: 1; border.color: Color.popups.border
        Keys.onEscapePressed: { if (!root.busy) { root.close(); root.cancelled() } }
        Column {
            anchors.fill: parent; anchors.margins: 24; spacing: 16
            Column { width: parent.width; spacing: 5
                Text { text: "Save theme"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "Choose a name for the permanent Omarchy theme."; color: Color.popups.text; opacity: .58; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            }
            Rectangle { width: parent.width; height: 44; radius: 8; color: Util.alpha(Color.background, 0.5); border.width: 1; border.color: nameInput.activeFocus ? Color.accent : Color.muted
                TextInput { id: nameInput; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; verticalAlignment: TextInput.AlignVCenter; color: Color.popups.text; selectionColor: Color.accent; selectedTextColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; maximumLength: 64; enabled: !root.busy; Keys.onReturnPressed: root.submit(); Keys.onEnterPressed: root.submit() }
            }
            Text { visible: root.errorMessage !== ""; width: parent.width; text: root.errorMessage; color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
            Item { width: 1; height: root.errorMessage !== "" ? 0 : 14 }
            Row { anchors.right: parent.right; spacing: 10
                Rectangle { width: 95; height: 38; radius: 8; color: Util.alpha(Color.background, 0.5); border.width: 1; border.color: Color.popups.border; opacity: root.busy ? .4 : 1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: { root.close(); root.cancelled() } }
                }
                Rectangle { width: 130; height: 38; radius: 8; color: Color.accent; opacity: root.busy ? .55 : 1
                    Text { anchors.centerIn: parent; text: root.busy ? "Applying…" : "Save & Apply"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.submit() }
                }
            }
        }
    }
}
