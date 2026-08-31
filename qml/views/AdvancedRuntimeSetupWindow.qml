import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components/Contrast.js" as Contrast
import "../components" as Components

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property bool installed: false
    property string themeName: ""
    property string message: ""
    property bool glitchEnabled: false
    property int glitchEpoch: 0

    signal installRequested()
    signal keepNativeRequested()
    signal hideRequested()

    visible: active
    color: "transparent"
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.hideRequested()
    }
    WlrLayershell.namespace: "omagen-advanced-runtime-setup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hideRequested()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(560), parent.width - Style.space(48))
        height: Math.min(Style.space(360), parent.height - Style.space(48))
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: Math.max(1, Style.space(1))
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(28)
            spacing: Style.space(14)

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)
                    Text {
                        text: "Enable Omagen Advanced Runtime"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    Text {
                        text: root.themeName !== "" ? root.themeName : "Advanced Omagen theme"
                        color: Color.popups.text
                        opacity: 0.58
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideMiddle
                    }
                }

                Button {
                    width: Style.space(36)
                    height: Style.space(36)
                    text: "×"
                    fontSize: Style.font.title
                    foreground: Color.popups.text
                    tooltipText: "Keep native theme"
                    enabled: !root.busy
                    onClicked: root.keepNativeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.installed
                    ? "The Omagen Advanced Runtime is installed. Reapply this theme to activate its advanced shell behavior."
                    : "Only the native part of this theme was applied. Omagen can install a user-level theme-set bridge so advanced Omagen themes can activate through the normal Omarchy theme command."
                color: Color.popups.text
                opacity: 0.72
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(82)
                radius: Style.cornerRadius
                color: Util.alpha(Color.accent, 0.10)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.58)

                Text {
                    anchors.fill: parent
                    anchors.margins: Style.space(14)
                    text: "Installs only user-owned files:\n• ~/.config/omarchy/hooks/theme-set.d/omagen-theme-set\n• ~/.local/state/omagen/advanced-runtime.json"
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.message !== ""
                text: root.message
                color: root.installed ? Color.accent : Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)

                Button {
                    Layout.fillWidth: true
                    text: root.busy ? "Installing…" : (root.installed ? "Close" : "Enable advanced themes")
                    foreground: Contrast.textFor(Color.accent, Color.background, Color.foreground)
                    accent: Color.accent
                    background: Color.accent
                    enabled: !root.busy
                    onClicked: root.installed ? root.keepNativeRequested() : root.installRequested()
                }
                Button {
                    Layout.fillWidth: true
                    text: "Keep native"
                    foreground: Color.popups.text
                    bordered: true
                    enabled: !root.busy
                    onClicked: root.keepNativeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Native colors and shell tokens remain available without this runtime."
                color: Color.popups.text
                opacity: 0.46
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
