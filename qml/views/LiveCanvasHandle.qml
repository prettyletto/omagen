import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components

// A small, monitor-bound affordance for reopening the Live Canvas controls.
// It intentionally has no keyboard focus and only occupies its visible handle
// rectangle, so hiding the side panel never traps application input.
Item {
    id: root

    property bool active: false
    property string monitorName: ""
    property bool glitchEnabled: false
    property int glitchEpoch: 0
    property bool demoActive: false
    property bool actionBusy: false

    signal reopenRequested()
    signal saveApplyRequested()

    Variants {
        model: root.active ? Quickshell.screens : []

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                visible: root.active && (root.monitorName === "" || modelData.name === root.monitorName)
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.namespace: "omagen-live-canvas-handle"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors {
                    top: true
                    right: true
                }
                implicitWidth: root.demoActive ? Style.space(154) : Style.space(42)
                implicitHeight: root.demoActive ? Style.space(138) : Style.space(116)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    radius: Style.cornerRadius
                    color: Util.alpha(Color.popups.background, 0.94)
                    border.width: 1
                    border.color: Color.popups.border

                    Components.SignalGlitch {
                        anchors.fill: parent
                        z: 10
                        enabled: root.glitchEnabled
                        triggerEpoch: root.glitchEpoch
                        accentColor: Color.accent
                        secondaryColor: Color.foreground
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(6)
                        visible: root.demoActive

                        Text {
                            Layout.fillWidth: true
                            text: "DEMO LIVE"
                            color: Color.popups.text
                            opacity: 0.66
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 0.8
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(34)
                            text: root.actionBusy ? "Working…" : "Save & Apply"
                            foreground: Color.popups.background
                            accent: Color.accent
                            background: Color.accent
                            bordered: true
                            enabled: !root.actionBusy
                            tooltipText: "Open final save options; Omagen will close this owned Demo before applying"
                            onClicked: root.saveApplyRequested()
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(30)
                            text: "Controls"
                            foreground: Color.popups.text
                            accent: Color.accent
                            background: Util.alpha(Color.popups.text, 0.06)
                            bordered: true
                            enabled: !root.actionBusy
                            tooltipText: "Reopen Live Canvas controls"
                            onClicked: root.reopenRequested()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.demoActive
                        text: "‹"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: !root.demoActive
                        onClicked: root.reopenRequested()
                    }
                }
            }
        }
    }
}
