import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components
import "../components/Contrast.js" as Contrast

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property bool sessionActive: false
    property bool cancelBusy: false
    property string sourceImage: ""
    // Retained for the root handoff contract. The choice itself is rendered
    // and made on the first Live Canvas wizard page now.
    property string workflowMode: "fast"
    property string errorMessage: ""
    property bool glitchEnabled: false
    property int glitchEpoch: 0
    property int cursorIndex: 0
    // Setup exposes image selection/editing, then a fixed forward action once
    // an image is selected. Session Cancel remains the final action when a
    // session is already active.
    readonly property int actionCount: sourceImage === ""
        ? (sessionActive ? 3 : 3)
        : (sessionActive ? 4 : 4)

    signal chooseImageRequested()
    signal editThemeRequested()
    signal advancedRuntimeRequested()
    signal workflowModeSelected(string mode)
    signal continueRequested()
    signal cancelRequested()
    signal hideRequested()

    visible: active
    color: "transparent"
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.hideRequested()
    }
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
        else if (cursorIndex === 1)
            editThemeRequested();
        else if (!sessionActive && cursorIndex === 2)
            advancedRuntimeRequested();
        else if (sourceImage !== "" && cursorIndex === (sessionActive ? 2 : 3))
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
        width: Math.min(Style.space(620), parent.width - Style.space(48))
        // The content scrolls independently, while the action footer remains
        // visible. This prevents the image-selected state from clipping its
        // only forward action on short or scaled displays.
        height: Math.min(root.sourceImage === "" ? Style.space(350) : (root.sessionActive ? Style.space(640) : Style.space(600)), parent.height - Style.space(48))
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
                anchors.margins: Style.space(24)
                spacing: Style.space(10)

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
                    text: root.sourceImage === ""
                        ? "Create a theme from a PNG or JPEG image"
                        : "Image ready — continue to choose your workflow"
                    color: Color.popups.text
                    opacity: 0.7
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                }

                Flickable {
                    id: contentScroller
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: contentColumn.implicitHeight + Style.space(4)
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    WheelHandler {
                        onWheel: function(event) {
                            if (!contentScroller.interactive || event.angleDelta.y === 0)
                                return;
                            contentScroller.cancelFlick();
                            const maximum = Math.max(0, contentScroller.contentHeight - contentScroller.height);
                            contentScroller.contentY = Math.max(0, Math.min(maximum, contentScroller.contentY - event.angleDelta.y / 2));
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        id: contentColumn
                        width: contentScroller.width
                        spacing: Style.space(10)

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(190)
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
                                sourceSize.width: 620
                                sourceSize.height: 190
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
                            text: "Edit installed theme"
                            iconText: "󰏢"
                            leftAlign: true
                            foreground: Color.popups.text
                            accent: Color.accent
                            hasCursor: root.cursorIndex === 1
                            enabled: !root.busy
                            onClicked: root.editThemeRequested()
                        }

                        Button {
                            Layout.fillWidth: true
                            visible: !root.sessionActive
                            text: "Advanced runtime setup"
                            iconText: "󰒓"
                            leftAlign: true
                            foreground: Color.popups.text
                            hasCursor: root.cursorIndex === 2
                            enabled: !root.busy
                            tooltipText: "Review or enable the optional advanced theme bridge"
                            onClicked: root.advancedRuntimeRequested()
                        }

                        Item {
                            Layout.fillHeight: true
                            visible: root.sourceImage === ""
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(60)
                    visible: root.sourceImage !== ""
                    color: Util.alpha(Color.accent, 0.06)
                    border.width: 1
                    border.color: Util.alpha(Color.accent, 0.28)
                    radius: Style.space(6)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(12)
                        anchors.rightMargin: Style.space(12)
                        spacing: Style.space(10)

                        Text {
                            Layout.fillWidth: true
                            text: "Next: choose your workflow"
                            color: Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Button {
                            Layout.preferredWidth: Style.space(190)
                            Layout.preferredHeight: Style.space(40)
                            text: "Continue to Workflow  →"
                            foreground: Contrast.textFor(Color.accent, Color.popups.background, Color.popups.text)
                            accent: Color.accent
                            background: Color.accent
                            bordered: true
                            hasCursor: root.cursorIndex === (root.sessionActive ? 2 : 3)
                            enabled: !root.busy && !root.cancelBusy
                            onClicked: root.continueRequested()
                        }
                    }
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
