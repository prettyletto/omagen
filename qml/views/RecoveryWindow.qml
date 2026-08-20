import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root
    property bool active: false
    property bool busy: false
    property string generationId: ""
    property string previewVariant: ""
    signal resumeRequested()
    signal restoreRequested()
    signal closeRequested()
    visible: active
    implicitWidth: 520
    implicitHeight: 330
    color: "transparent"
    WlrLayershell.namespace: "omagen-recovery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent; color: Color.background; radius: 16; border.width: 1; border.color: Color.muted; focus: root.visible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested()
                event.accepted = true
            }
        }
        Column {
            anchors.centerIn: parent; width: parent.width - 64; spacing: 16
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Omagen"; color: Color.foreground; font.pixelSize: 30; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Previous session found"; color: Color.foreground; font.pixelSize: 18; font.bold: true }
            Text { width: parent.width; text: "A previous Omagen preview is still active.\nYou can continue where you left off or restore the desktop to its original theme."; color: Color.foreground; opacity: .7; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Variant: " + (root.previewVariant || "Source") + "   Generation: " + (root.generationId || "unknown"); color: Color.foreground; opacity: .55; font.pixelSize: 11; elide: Text.ElideMiddle }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                Rectangle { width: 150; height: 42; radius: 8; color: Util.alpha(Color.background, .6); border.width: 1; border.color: Color.muted; opacity: root.busy ? .45 : 1
                    Text { anchors.centerIn: parent; text: root.busy ? "Restoring…" : "Restore & Close"; color: Color.foreground; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.restoreRequested() }
                }
                Rectangle { width: 110; height: 42; radius: 8; color: Color.accent; opacity: root.busy ? .55 : 1
                    Text { anchors.centerIn: parent; text: "Resume"; color: Color.background; font.pixelSize: 12; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.resumeRequested() }
                }
            }
        }
    }
}
