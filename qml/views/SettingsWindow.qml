import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

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
    property string ansi: "3.0"
    property string brightAnsi: "4.5"
    property string errorMessage: ""
    property int cursorIndex: 0
    property bool inputFocused: false
    property var harmonyOptions: [
        { label: "Closest to source", value: "auto", description: "Preserve the wallpaper's natural color relationships" },
        { label: "Monochromatic", value: "monochromatic", description: "Use one primary hue across the palette" },
        { label: "Analogous", value: "analogous", description: "Use neighboring hues around the source accent" },
        { label: "Complementary", value: "complementary", description: "Use the source accent and its opposite hue" },
        { label: "Split complementary", value: "split_complementary", description: "Use the source accent with two neighboring opposite hues" },
        { label: "Triadic", value: "triadic", description: "Use three evenly spaced hue families" }
    ]

    signal saveRequested(string harmony, string primaryText, string brightText, string secondaryText, string uiElement, string selectionText, string ansi, string brightAnsi)
    signal resetRequested()
    signal closeRequested()

    function loadValues(loadedHarmony, loadedPrimaryText, loadedBrightText, loadedSecondaryText, loadedUiElement, loadedSelectionText, loadedAnsi, loadedBrightAnsi) {
        harmony = loadedHarmony;
        primaryText = Number(loadedPrimaryText).toFixed(1);
        brightText = Number(loadedBrightText).toFixed(1);
        secondaryText = Number(loadedSecondaryText).toFixed(1);
        uiElement = Number(loadedUiElement).toFixed(1);
        selectionText = Number(loadedSelectionText).toFixed(1);
        ansi = Number(loadedAnsi).toFixed(1);
        brightAnsi = Number(loadedBrightAnsi).toFixed(1);
    }

    function activateCursor() {
        if (busy) return;
        if (cursorIndex < harmonyOptions.length) {
            harmony = harmonyOptions[cursorIndex].value;
        } else if (cursorIndex === harmonyOptions.length) {
            resetRequested();
        } else {
            saveRequested(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
        }
    }

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onActiveChanged: if (active) Qt.callLater(function() { keyCatcher.forceActiveFocus(); });

    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

    Rectangle {
        z: 1
        anchors.centerIn: parent
        width: Math.min(Style.space(620), parent.width - Style.space(48))
        height: Math.min(Style.space(820), parent.height - Style.space(48))
        color: Color.popups.background
        radius: Style.cornerRadius
        border.width: 1
        border.color: Color.popups.border

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: root.inputFocused
            onCloseRequested: root.closeRequested()
            onMoveRequested: function(dx, dy) {
                if (dy === 0) return;
                var count = root.harmonyOptions.length + 2;
                root.cursorIndex = (root.cursorIndex + (dy > 0 ? 1 : -1) + count) % count;
            }
            onActivateRequested: root.activateCursor()

        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 14

            Text {
                text: "Settings"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
            }

            Text {
                text: "Color theory"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
            }

            Text {
                text: "Harmony"
                color: Color.popups.text
                opacity: 0.7
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }

            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.harmonyOptions

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent ? parent.width : 0
                        height: 30
                        radius: 6
                        color: root.harmony === modelData.value || root.cursorIndex === index ? Util.alpha(Color.accent, 0.25) : "transparent"
                        opacity: 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.harmony === modelData.value ? "✓" : ""
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: { root.cursorIndex = index; root.harmony = modelData.value }
                        }
                    }
                }
            }

            Text {
                text: "Contrast"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
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
                        { label: "Selection text", key: "selectionText" },
                        { label: "ANSI colors", key: "ansi" },
                        { label: "Bright ANSI", key: "brightAnsi" }
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
                            color: Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
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
                                validator: DoubleValidator { bottom: 1.0; top: 21.0; decimals: 2 }
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                color: Color.popups.text
                                font.family: Style.font.family
                                font.pixelSize: Style.font.body
                                selectByMouse: true
                                enabled: !root.busy
                                onActiveFocusChanged: root.inputFocused = activeFocus
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
                    color: root.cursorIndex === root.harmonyOptions.length ? Util.alpha(Color.accent, 0.18) : Util.alpha(Color.background, 0.5)
                    border.width: 1
                    border.color: Color.muted
                    opacity: root.busy ? 0.5 : 1

                    Text { anchors.centerIn: parent; text: "Reset defaults"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
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

                    Text { anchors.centerIn: parent; text: root.busy ? "Saving…" : "Save"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: root.saveRequested(root.harmony, root.primaryText, root.brightText, root.secondaryText, root.uiElement, root.selectionText, root.ansi, root.brightAnsi)
                    }
                }
            }

            Text {
                visible: root.errorMessage !== ""
                width: parent.width
                text: root.errorMessage
                textFormat: Text.PlainText
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }
        }

        Button {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Style.space(24)
            anchors.topMargin: Style.space(24)
            width: Style.space(36)
            height: Style.space(36)
            text: "×"
            fontSize: Style.font.title
            foreground: Color.popups.text
            tooltipText: "Close"
            onClicked: root.closeRequested()
        }
        }
    }
}
