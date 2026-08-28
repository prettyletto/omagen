import QtQuick
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

    signal reopenRequested()

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
                implicitWidth: Style.space(42)
                implicitHeight: Style.space(116)

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

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.reopenRequested()
                    }
                }
            }
        }
    }
}
