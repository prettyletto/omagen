import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property string harmony: "auto"
    property string primaryText: "4.5"
    property string brightText: "7.0"
    property string secondaryText: "3.0"
    property string uiElement: "3.0"
    property string selectionText: "4.5"
    property string errorMessage: ""

    signal saveRequested(string harmony, string primaryText, string brightText, string secondaryText, string uiElement, string selectionText)
    signal resetRequested()
    signal hideRequested()

    function loadValues(loadedHarmony, loadedPrimaryText, loadedBrightText, loadedSecondaryText, loadedUiElement, loadedSelectionText) {
        harmony = loadedHarmony;
        primaryText = Number(loadedPrimaryText).toFixed(1);
        brightText = Number(loadedBrightText).toFixed(1);
        secondaryText = Number(loadedSecondaryText).toFixed(1);
        uiElement = Number(loadedUiElement).toFixed(1);
        selectionText = Number(loadedSelectionText).toFixed(1);
    }

    visible: active
    implicitWidth: 560
    implicitHeight: 720
    color: "transparent"
    WlrLayershell.namespace: "omagen-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: 16
        border.width: 1
        border.color: Color.muted
        focus: root.visible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape && !root.busy) {
                root.hideRequested();
                event.accepted = true;
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 14

            Text {
                text: "Settings"
                color: Color.foreground
                font.pixelSize: 30
            }

            Text {
                text: "Color theory"
                color: Color.foreground
                font.pixelSize: 18
            }

            Text {
                text: "Harmony"
                color: Color.foreground
                opacity: 0.7
                font.pixelSize: 14
            }

            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: [
                        { label: "Closest to source", value: "auto", enabled: true },
                        { label: "Monochromatic", value: "monochromatic", enabled: false },
                        { label: "Analogous", value: "analogous", enabled: false },
                        { label: "Complementary", value: "complementary", enabled: false },
                        { label: "Split complementary", value: "split_complementary", enabled: false },
                        { label: "Triadic", value: "triadic", enabled: false }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: parent ? parent.width : 0
                        height: 30
                        radius: 6
                        color: root.harmony === modelData.value ? Util.alpha(Color.accent, 0.25) : "transparent"
                        opacity: modelData.enabled ? 1 : 0.4

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label + (modelData.enabled ? "" : "  (coming soon)")
                            color: Color.foreground
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.harmony === modelData.value ? "✓" : ""
                            color: Color.accent
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.enabled && !root.busy
                            onClicked: root.harmony = modelData.value
                        }
                    }
                }
            }

            Text {
                text: "Contrast"
                color: Color.foreground
                font.pixelSize: 18
            }

            Column {
                width: parent.width
                spacing: 7

                Repeater {
                    model: [
                        { label: "Primary text", key: "primaryText" },
                        { label: "Bright text", key: "brightText" },
                        { label: "Secondary text", key: "secondaryText" },
                        { label: "UI elements", key: "uiElement" },
                        { label: "Selection text", key: "selectionText" }
                    ]

                    delegate: Row {
                        required property var modelData
                        width: parent ? parent.width : 0
                        height: 30
                        spacing: 12

                        Text {
                            width: 180
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Color.foreground
                            font.pixelSize: 14
                        }

                        Rectangle {
                            width: 100
                            height: 28
                            radius: 5
                            color: Util.alpha(Color.background, 0.5)
                            border.width: 1
                            border.color: Color.muted

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                text: root[modelData.key]
                                color: Color.foreground
                                font.pixelSize: 14
                                selectByMouse: true
                                enabled: !root.busy
                                onEditingFinished: root[modelData.key] = text
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 1 }

            Row {
                spacing: 12

                Rectangle {
                    width: 150
                    height: 44
                    radius: 8
                    color: Util.alpha(Color.background, 0.5)
                    border.width: 1
                    border.color: Color.muted
                    opacity: root.busy ? 0.5 : 1

                    Text { anchors.centerIn: parent; text: "Reset defaults"; color: Color.foreground; font.pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: root.resetRequested()
                    }
                }

                Rectangle {
                    width: 150
                    height: 44
                    radius: 8
                    color: Color.accent
                    opacity: root.busy ? 0.5 : 1

                    Text { anchors.centerIn: parent; text: root.busy ? "Saving..." : "Save"; color: Color.background; font.pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: root.saveRequested(root.harmony, root.primaryText, root.brightText, root.secondaryText, root.uiElement, root.selectionText)
                    }
                }
            }

            Text {
                visible: root.errorMessage !== ""
                width: parent.width
                text: root.errorMessage
                color: Color.urgent
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
    }
}
