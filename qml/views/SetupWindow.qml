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
    property bool sessionActive: false
    property bool cancelBusy: false
    property string sourceImage: ""
    property string workflowMode: "fast"
    property string errorMessage: ""
    property bool glitchEnabled: false
    property int glitchEpoch: 0
    property int cursorIndex: 0
    readonly property int actionCount: sourceImage === ""
        ? (sessionActive ? 2 : 1)
        : (sessionActive ? 5 : 4)

    signal chooseImageRequested()
    signal workflowModeSelected(string mode)
    signal continueRequested()
    signal cancelRequested()
    signal hideRequested()

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-setup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    function moveCursor(delta) {
        cursorIndex = (cursorIndex + delta + actionCount) % actionCount;
    }

    function activateCursor() {
        if (busy)
            return;
        if (cursorIndex === 0)
            chooseImageRequested();
        else if (sourceImage !== "" && cursorIndex === 1)
            workflowModeSelected("fast");
        else if (sourceImage !== "" && cursorIndex === 2)
            workflowModeSelected("in-depth");
        else if (sourceImage !== "" && cursorIndex === 3)
            continueRequested();
        else if (sessionActive && cursorIndex === actionCount - 1)
            cancelRequested();
    }

    onActiveChanged: if (active) {
        cursorIndex = 0;
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }
    onSourceImageChanged: if (cursorIndex >= actionCount) cursorIndex = actionCount - 1;

    MouseArea {
        anchors.fill: parent
        onClicked: root.hideRequested()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(560), parent.width - Style.space(48))
        // The image-selected state needs room for the preview, path, Change
        // image, Continue, and footer controls.  Keep the empty state compact
        // while letting the full state keep every action inside the card.
        height: Math.min(root.sourceImage === "" ? 270 : 610, parent.height - 48)
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

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.hideRequested()
            onMoveRequested: function(dx, dy) {
                if (dy !== 0) root.moveCursor(dy > 0 ? 1 : -1);
            }
            onActivateRequested: root.activateCursor()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(28)
                spacing: Style.space(14)

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(42)

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        Text {
                            text: "Omagen"
                            color: Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.heading
                            font.bold: true
                        }
                        Text {
                            text: "Quattro theme studio"
                            color: Color.popups.text
                            opacity: 0.58
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                    }

                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(36)
                        height: Style.space(36)
                        text: "×"
                        fontSize: Style.font.title
                        foreground: Color.popups.text
                        tooltipText: "Close"
                        onClicked: root.hideRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Create a theme from a PNG or JPEG image"
                    color: Color.popups.text
                    opacity: 0.7
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(230)
                    visible: root.sourceImage !== ""
                    radius: Style.cornerRadius
                    color: Util.alpha(Color.background, 0.45)
                    border.width: 1
                    border.color: Util.alpha(Color.popups.border, 0.55)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.sourceImage !== "" ? Util.fileUrl(root.sourceImage) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 560
                        sourceSize.height: 230
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.sourceImage !== ""
                    text: root.sourceImage
                    textFormat: Text.PlainText
                    color: Color.popups.text
                    opacity: 0.58
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.sourceImage !== ""
                    text: "Choose your workflow"
                    color: Color.popups.text
                    opacity: 0.72
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.sourceImage !== ""
                    spacing: Style.space(6)

                    Button {
                        Layout.fillWidth: true
                        text: "Fast\nPick → choose → apply"
                        foreground: Color.popups.text
                        accent: Color.accent
                        background: root.workflowMode === "fast" ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.popups.text, 0.04)
                        bordered: true
                        hasCursor: root.cursorIndex === 1
                        onClicked: root.workflowModeSelected("fast")
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "In-depth\nOpen Studio extras"
                        foreground: Color.popups.text
                        accent: Color.accent
                        background: root.workflowMode === "in-depth" ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.popups.text, 0.04)
                        bordered: true
                        hasCursor: root.cursorIndex === 2
                        onClicked: root.workflowModeSelected("in-depth")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.sourceImage !== ""
                    text: root.workflowMode === "fast"
                        ? "Fast keeps the normal Omagen path: choose a direction, enter Live Canvas, then apply the theme."
                        : "In-depth opens Studio controls for window, shell, and bar composition before generation."
                    color: Color.popups.text
                    opacity: 0.58
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Button {
                        Layout.fillWidth: true
                        text: root.sourceImage === "" ? "Choose image" : "Change image"
                        iconText: "󰉋"
                        leftAlign: true
                        foreground: Color.popups.text
                        hasCursor: root.cursorIndex === 0
                        enabled: !root.busy
                        onClicked: root.chooseImageRequested()
                    }
                    Button {
                        Layout.fillWidth: true
                        visible: root.sourceImage !== ""
                        text: root.busy ? "Starting…" : "> Continue"
                        leftAlign: true
                        foreground: Color.popups.text
                        accent: Color.accent
                        hasCursor: root.sourceImage !== "" && root.cursorIndex === 3
                        enabled: !root.busy
                        onClicked: root.continueRequested()
                    }
                    Button {
                        Layout.fillWidth: true
                        visible: root.sessionActive
                        text: root.cancelBusy ? "Restoring original desktop…" : "Cancel session"
                        leftAlign: true
                        foreground: Color.popups.text
                        bordered: true
                        hasCursor: root.sessionActive && root.cursorIndex === root.actionCount - 1
                        enabled: !root.busy && !root.cancelBusy
                        onClicked: root.cancelRequested()
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

                Text {
                    Layout.fillWidth: true
                    visible: root.errorMessage !== ""
                    text: root.errorMessage
                    textFormat: Text.PlainText
                    color: Color.urgent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
