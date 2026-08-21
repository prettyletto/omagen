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
    property string selectedStyle: "solid"
    property int cursorIndex: 0

    readonly property var styles: [
        { key: "solid", title: "Single color", description: "A calm, consistent accent around the active window." },
        { key: "split", title: "Dual color", description: "A two-tone active panel inspired by Ryu-style themes." },
        { key: "cycle", title: "Color sweep", description: "A rotating accent that continuously travels through the palette." },
        { key: "neon", title: "Neon pulse", description: "A glowing active panel with a soft breathing animation." }
    ]

    signal styleSelected(string style)
    signal continueRequested()
    signal backRequested()
    signal hideRequested()

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-preview-config"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    function moveCursor(delta) {
        cursorIndex = (cursorIndex + delta + styles.length) % styles.length;
    }

    function activateCursor() {
        if (busy)
            return;
        root.selectedStyle = styles[cursorIndex].key;
        root.styleSelected(root.selectedStyle);
    }

    function syncCursor() {
        for (var i = 0; i < styles.length; ++i) {
            if (styles[i].key === selectedStyle) {
                cursorIndex = i;
                return;
            }
        }
    }

    onSelectedStyleChanged: syncCursor()
    onActiveChanged: if (active) {
        syncCursor();
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    MouseArea { anchors.fill: parent; onClicked: root.hideRequested() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(760), parent.width - Style.space(48))
        height: Math.min(Style.space(620), parent.height - Style.space(48))
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: 1
        border.color: Color.popups.border
        z: 1

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.backRequested()
            onMoveRequested: function(dx, dy) {
                if (dx !== 0) root.moveCursor(dx > 0 ? 1 : -1);
                else if (dy !== 0) root.moveCursor(dy > 0 ? 2 : -2);
            }
            onActivateRequested: root.activateCursor()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(28)
                spacing: Style.space(14)

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(44)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Extra preview configuration"
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
                        tooltipText: "Back"
                        onClicked: root.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Choose how the active window panel should look in the live preview."
                    color: Color.popups.text
                    opacity: 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: Style.space(12)
                    columnSpacing: Style.space(12)

                    Repeater {
                        model: root.styles
                        delegate: Components.PanelStyleCard {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            styleKey: modelData.key
                            title: modelData.title
                            description: modelData.description
                            selected: root.selectedStyle === modelData.key
                            focused: root.cursorIndex === index
                            onClicked: {
                                root.selectedStyle = modelData.key;
                                root.styleSelected(modelData.key);
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(8)
                    Button {
                        text: "Back"
                        foreground: Color.popups.text
                        bordered: true
                        onClicked: root.backRequested()
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: root.busy ? "Starting…" : "Continue to preview"
                        foreground: Color.background
                        accent: Color.accent
                        background: Color.accent
                        bordered: true
                        enabled: !root.busy
                        onClicked: root.continueRequested()
                    }
                }
            }
        }
    }
}
