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
    property bool previewBusy: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool cancelBusy: false
    property bool applyBusy: false
    property bool applyRecoveryRequired: false
    property bool protocolCanBack: false
    property bool protocolCanForward: false
    property bool protocolBusy: false
    property string protocolMessage: ""
    property string errorMessage: ""
    property string selectedVariant: "source"
    property string monitorName: ""
    property string suggestedThemeName: ""
    property var variants: []

    signal hideRequested()
    signal closeCanvasRequested()
    signal startDemoRequested()
    signal cancelRequested()
    signal variantRequested(string variant)
    signal protocolBackRequested()
    signal protocolForwardRequested()
    signal applyRequested(string variant, string name, bool generateUnlock, bool capturePreview)

    function resolveScreen() {
        const screens = Quickshell.screens || []
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === root.monitorName)
                return screens[i]
        }
        return null
    }

    visible: root.active
    screen: root.resolveScreen()
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagen-live-canvas"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: Style.space(430)

    Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.popups.background, 0.97)
        border.width: 1
        border.color: Color.popups.border

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.hideRequested()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(22)
            spacing: Style.space(12)
            z: 1

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(42)

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                        text: "LIVE CANVAS"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: "Real desktop / " + (root.monitorName || "focused monitor")
                        color: Color.foreground
                        opacity: 0.6
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                }

                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(34)
                    height: Style.space(34)
                    text: "—"
                    fontSize: Style.font.title
                    foreground: Color.foreground
                    tooltipText: "Hide Studio panel"
                    onClicked: root.hideRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(76)
                radius: Style.cornerRadius
                color: Util.alpha(Color.accent, 0.1)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.45)

                Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(3)
                    Text {
                        text: "ACTIVE DIRECTION"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    Text {
                        text: root.selectedVariant.toUpperCase()
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.demoActive ? "Choose another direction to reapply it without losing this canvas." : "Live theme test is active. Start demo to open the four-pane workspace."
                color: Color.foreground
                opacity: 0.62
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: root.variants
                    delegate: Button {
                        required property var modelData
                        Layout.fillWidth: true
                        text: (root.selectedVariant === modelData.variant ? "●  " : "○  ") + modelData.label
                        leftAlign: true
                        foreground: Color.foreground
                        accent: root.selectedVariant === modelData.variant ? Color.accent : Color.foreground
                        background: root.selectedVariant === modelData.variant ? Util.alpha(Color.accent, 0.12) : Util.alpha(Color.foreground, 0.04)
                        bordered: true
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.variantRequested(modelData.variant)
                    }
                }
            }

            Components.ProtocolNavigationControls {
                Layout.fillWidth: true
                canBack: root.protocolCanBack
                canForward: root.protocolCanForward
                busy: root.protocolBusy
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onBackRequested: root.protocolBackRequested()
                onForwardRequested: root.protocolForwardRequested()
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorMessage !== ""
                text: root.errorMessage
                color: Color.urgent
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Text {
                Layout.fillWidth: true
                visible: root.protocolMessage !== ""
                text: root.protocolMessage
                color: Color.foreground
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Item { Layout.fillHeight: true }

            Button {
                Layout.fillWidth: true
                text: root.applyBusy ? "Applying…" : "Apply theme"
                foreground: Color.background
                accent: Color.accent
                background: Color.accent
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: themeNameDialog.openWith(root.suggestedThemeName)
            }
            Button {
                Layout.fillWidth: true
                text: root.demoBusy ? (root.demoActive ? "Stopping demo…" : "Starting demo…") : (root.demoActive ? "Stop demo" : "Start demo")
                foreground: Color.foreground
                bordered: true
                enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: root.demoActive ? root.closeCanvasRequested() : root.startDemoRequested()
            }
            Button {
                Layout.fillWidth: true
                text: root.cancelBusy ? "Restoring original desktop…" : "Restore & close"
                foreground: Color.foreground
                bordered: true
                enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: root.cancelRequested()
            }
        }
    }

    Components.ThemeNameDialog {
        id: themeNameDialog
        anchors.fill: parent
        busy: root.applyBusy
        onConfirmed: function(name, generateUnlock, capturePreview) {
            root.applyRequested(root.selectedVariant, name, generateUnlock, capturePreview)
        }
    }

    onActiveChanged: if (active)
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); })
}
