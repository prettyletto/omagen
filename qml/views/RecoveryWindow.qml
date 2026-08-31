import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property string generationId: ""
    property string previewVariant: ""
    property bool workspaceResumable: false
    property int cursorIndex: 0
    property bool glitchEnabled: false
    property int glitchEpoch: 0

    signal resumeRequested()
    signal restoreRequested()
    signal closeRequested()

    visible: active
    color: "transparent"
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.closeRequested()
    }
    WlrLayershell.namespace: "omagen-recovery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    function activateCursor() {
        if (busy) return;
        if (cursorIndex === 0) restoreRequested();
        else resumeRequested();
    }

    onActiveChanged: if (active) Qt.callLater(function() { root.cursorIndex = root.workspaceResumable ? 1 : 0; keyCatcher.forceActiveFocus(); });
    onWorkspaceResumableChanged: if (!workspaceResumable) root.cursorIndex = 0;

    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(560), parent.width - Style.space(48))
        height: Style.space(360)
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: 1
        border.color: Color.popups.border
        z: 1

        Components.SignalGlitch {
            anchors.fill: parent
            z: 10
            enabled: root.glitchEnabled
            triggerEpoch: root.glitchEpoch
            accentColor: Color.accent
            secondaryColor: Color.foreground
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.closeRequested()
            onMoveRequested: function(dx, dy) {
                if (dy !== 0) root.cursorIndex = (root.cursorIndex + (dy > 0 ? 1 : -1) + 2) % 2;
            }
            onActivateRequested: root.activateCursor()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(30)
                spacing: Style.space(14)

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(38)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Recover Omagen"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(36)
                        height: Style.space(36)
                        text: "×"
                        fontSize: Style.font.title
                        foreground: Color.popups.text
                        onClicked: root.closeRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "A previous preview session is still active."
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: root.workspaceResumable ? "Resume where you left off, or restore the original desktop theme and close Omagen." : "The generated workspace is unavailable. Restore the original desktop theme and close Omagen."
                    color: Color.popups.text
                    opacity: 0.7
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    text: "Variant: " + (root.previewVariant || "Source") + "   ·   Generation: " + (root.generationId || "unknown")
                    textFormat: Text.PlainText
                    color: Color.popups.text
                    opacity: 0.52
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)
                    Button {
                        Layout.fillWidth: true
                        text: root.busy ? "Restoring…" : "Restore & close"
                        iconText: "󰁪"
                        leftAlign: true
                        foreground: Color.popups.text
                        hasCursor: root.cursorIndex === 0
                        enabled: !root.busy
                        onClicked: root.restoreRequested()
                    }
                    Button {
                        Layout.fillWidth: true
                        text: root.workspaceResumable ? "Resume" : "Resume unavailable"
                        iconText: "󰐕"
                        leftAlign: true
                        foreground: Color.popups.text
                        hasCursor: root.cursorIndex === 1
                        enabled: !root.busy && root.workspaceResumable
                        onClicked: root.resumeRequested()
                    }
                }

                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: "↑/↓ or j/k to move   ·   Enter to select   ·   Esc to close"
                    color: Color.popups.text
                    opacity: 0.48
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
