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
    property bool generationBusy: false
    property bool previewBusy: false
    property bool cancelBusy: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool applyBusy: false
    property string suggestedThemeName: ""
    property bool workspaceReady: false
    property string sourceImage: ""
    property var shellStyle: ({ surface: "flat", detail: "native" })
    property string sessionId: ""
    property string generationId: ""
    property string selectedVariant: "source"
    property string previewVariant: ""
    property var palettes: ({})
    property string errorMessage: ""
    property int cursorIndex: 0

    readonly property var variants: [
        { variant: "source", label: "Source" },
        { variant: "calm", label: "Calm" },
        { variant: "mute", label: "Mute" },
        { variant: "deep", label: "Deep" },
        { variant: "vibrant", label: "Vibrant" },
        { variant: "balanced", label: "Balanced" }
    ]

    signal hideRequested()
    signal cancelRequested()
    signal variantSelected(string variant)
    signal testLiveRequested(string variant)
    signal demoRequested(string variant)
    signal applyRequested(string variant, string name, bool generateUnlock, bool capturePreview)

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-workspace"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    function syncCursor() {
        for (var i = 0; i < variants.length; i++) {
            if (variants[i].variant === selectedVariant) {
                cursorIndex = i;
                return;
            }
        }
    }

    function moveCursor(dx, dy) {
        var row = Math.floor(cursorIndex / 3);
        var col = cursorIndex % 3;
        if (dx !== 0) col = (col + (dx > 0 ? 1 : -1) + 3) % 3;
        if (dy !== 0) row = (row + (dy > 0 ? 1 : -1) + 2) % 2;
        cursorIndex = row * 3 + col;
        if (workspaceReady && !previewBusy && !cancelBusy && !applyBusy)
            variantSelected(variants[cursorIndex].variant);
    }

    function activateCursor() {
        if (!workspaceReady || previewBusy || cancelBusy || applyBusy)
            return;
        variantSelected(variants[cursorIndex].variant);
    }

    onSelectedVariantChanged: syncCursor()
    onActiveChanged: if (active) {
        syncCursor();
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0; color: Util.alpha(Color.accent, 0.035) }
                GradientStop { position: 0.38; color: "transparent" }
                GradientStop { position: 1; color: Util.alpha(Color.background, 0.18) }
            }
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.hideRequested()
            onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy); }
            onActivateRequested: root.activateCursor()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(28)
                spacing: Style.space(16)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(62)

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(3)

                            Text {
                                text: "QUATTRO THEME STUDIO  /  PALETTE GALLERY"
                                color: Color.accent
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1.25
                            }

                            Text {
                                text: "Omagen"
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }

                            Text {
                                text: root.generationBusy ? "Generating six interpretations…" : root.workspaceReady ? "Choose a direction" : "Preparing workspace…"
                                color: Color.foreground
                            opacity: 0.58
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                    }

                    Column {
                        anchors.right: closeButton.left
                        anchors.rightMargin: Style.space(14)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(260)
                        spacing: Style.space(3)

                        Text {
                            width: parent.width
                            text: "6 DIRECTIONS"
                            horizontalAlignment: Text.AlignRight
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.generationId !== "" ? root.generationId : root.sessionId
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignRight
                            color: Color.foreground
                            opacity: 0.45
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Button {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(36)
                        height: Style.space(36)
                        text: "×"
                        fontSize: Style.font.title
                        foreground: Color.foreground
                        tooltipText: "Close overlay"
                        onClicked: root.hideRequested()
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rows: 2
                    columnSpacing: Style.space(14)
                    rowSpacing: Style.space(16)

                    Repeater {
                        model: root.variants
                        delegate: Components.ThemePreviewCard {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            variant: modelData.variant
                            label: modelData.label
                            palette: root.palettes[modelData.variant] || null
                            sourceImage: root.sourceImage
                            selected: root.selectedVariant === modelData.variant
                            focused: root.cursorIndex === index
                            previewed: root.previewVariant === modelData.variant
                            enabled: root.workspaceReady && !root.previewBusy && !root.cancelBusy
                            onClicked: function(variant) {
                                root.cursorIndex = index;
                                root.variantSelected(variant);
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(54)

                    Text {
                        visible: root.errorMessage !== ""
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.4
                        text: root.errorMessage
                        color: Color.urgent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.errorMessage === ""
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ ↓ ← →  navigate     Enter  select     Esc  close"
                        color: Color.foreground
                        opacity: 0.42
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Button {
                            text: root.cancelBusy ? "Restoring…" : "Cancel"
                            foreground: Color.foreground
                            bordered: true
                            enabled: !root.cancelBusy && !root.previewBusy && !root.applyBusy
                            onClicked: root.cancelRequested()
                        }
                        Button {
                            text: root.previewBusy ? "Applying…" : "Test live"
                            foreground: Color.foreground
                            accent: Color.accent
                            background: Util.alpha(Color.accent, 0.08)
                            bordered: true
                            enabled: root.workspaceReady && !root.previewBusy && !root.cancelBusy && !root.applyBusy
                            onClicked: root.testLiveRequested(root.selectedVariant)
                        }
                        Button {
                            text: root.demoBusy ? (root.demoActive ? "Dispatching…" : "Opening…") : (root.demoActive ? "Dispatch" : "Demo")
                            foreground: Color.foreground
                            accent: Color.accent
                            background: Util.alpha(Color.accent, 0.08)
                            bordered: true
                            enabled: root.demoActive ? !root.demoBusy && !root.cancelBusy && !root.applyBusy : root.workspaceReady && !root.previewBusy && !root.cancelBusy && !root.applyBusy
                            onClicked: root.demoRequested(root.selectedVariant)
                        }
                        Button {
                            text: root.applyBusy ? "Applying…" : "Apply theme"
                            foreground: Color.background
                            accent: Color.accent
                            background: Color.accent
                            bordered: true
                            enabled: root.workspaceReady && !root.previewBusy && !root.cancelBusy && !root.applyBusy
                            onClicked: themeNameDialog.openWith(root.suggestedThemeName)
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: root.generationBusy || (root.active && !root.workspaceReady && root.errorMessage === "")
            width: Style.space(260)
            height: Style.space(80)
            radius: Style.cornerRadius
            color: Color.popups.background
            border.width: 1
            border.color: Color.popups.border
            z: 2
            Text {
                anchors.centerIn: parent
                text: root.generationBusy ? "Generating themes…" : "Loading palettes…"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
        }
    }

    Components.ThemeNameDialog {
        id: themeNameDialog
        anchors.fill: parent
        busy: root.applyBusy
        onConfirmed: function(name, generateUnlock, capturePreview) {
            root.applyRequested(root.selectedVariant, name, generateUnlock, capturePreview);
        }
    }
}
