import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../components" as Components

PanelWindow {
    id: root
    property bool active: false
    property bool generationBusy: false
    property bool previewBusy: false
    property bool cancelBusy: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool workspaceReady: false
    property string sourceImage: ""
    property string sessionId: ""
    property string originalTheme: ""
    property string originalBackgroundKind: ""
    property string originalBackgroundPath: ""
    property string generationId: ""
    property string selectedVariant: "source"
    property string previewVariant: ""
    property var palettes: ({})
    property string errorMessage: ""
    signal hideRequested(); signal cancelRequested(); signal variantSelected(string variant); signal testLiveRequested(string variant); signal demoRequested(string variant)
    visible: active; color: "transparent"
    WlrLayershell.namespace: "omagen-workspace"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    Rectangle {
        anchors.fill: parent; color: Color.background; focus: root.visible
        Keys.onPressed: function(event) { if (event.key===Qt.Key_Escape && !root.cancelBusy && !root.previewBusy) { root.hideRequested(); event.accepted=true } }
        Column { anchors.fill: parent; anchors.margins: 28; spacing: 16
            Item { width: parent.width; height: 48
                Column {
                    anchors.left: parent.left
                    spacing: 2
                    Text { text: "Omagen"; color: Color.foreground; font.pixelSize: 24; font.bold: true }
                    Text { text: root.generationBusy ? "Generating six interpretations…" : root.workspaceReady ? "Choose a direction" : "Preparing workspace…"; color: Color.foreground; opacity: .58; font.pixelSize: 13 }
                }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.generationId!=="" ? root.generationId : root.sessionId; width:260; elide:Text.ElideMiddle; horizontalAlignment:Text.AlignRight; color:Color.foreground; opacity:.45; font.pixelSize:10; font.family:"monospace" }
            }
            Grid { id: previewGrid; width:parent.width; height:parent.height-48-16-54-16; columns:3; spacing:14; property real cardWidth:(width-spacing*2)/3; property real cardHeight:(height-spacing)/2
                Repeater { model:[{variant:"source",label:"Source"},{variant:"calm",label:"Calm"},{variant:"mute",label:"Mute"},{variant:"deep",label:"Deep"},{variant:"vibrant",label:"Vibrant"},{variant:"balanced",label:"Balanced"}]
                    delegate: Components.ThemePreviewCard { required property var modelData; width:previewGrid.cardWidth; height:previewGrid.cardHeight; variant:modelData.variant; label:modelData.label; palette:root.palettes[modelData.variant]||null; sourceImage:root.sourceImage; selected:root.selectedVariant===modelData.variant; previewed:root.previewVariant===modelData.variant; enabled:root.workspaceReady&&!root.previewBusy&&!root.cancelBusy; onClicked:function(variant){root.variantSelected(variant)} }
                }
            }
            Item { width:parent.width; height:54
                Text { visible:root.errorMessage!==""; anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; width:parent.width*.5; text:root.errorMessage; color:Color.urgent; font.pixelSize:11; elide:Text.ElideRight }
                Row { anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter; spacing:10
                    Rectangle {
                        width: 110; height: 40; radius: 8
                        color: Util.alpha(Color.background, .6)
                        border.width: 1; border.color: Color.muted
                        opacity: root.cancelBusy ? .45 : 1
                        Text { anchors.centerIn: parent; text: root.cancelBusy ? "Restoring…" : "Cancel"; color: Color.foreground; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; enabled: !root.cancelBusy && !root.previewBusy; onClicked: root.cancelRequested() }
                    }
                    Rectangle {
                        width: 145; height: 40; radius: 8
                        color: Color.accent
                        opacity: root.workspaceReady && !root.previewBusy && !root.cancelBusy ? 1 : .45
                        Text { anchors.centerIn: parent; text: root.previewBusy ? "Applying…" : "Test Live"; color: Color.background; font.pixelSize: 13; font.bold: true }
                        MouseArea { anchors.fill: parent; enabled: root.workspaceReady && !root.previewBusy && !root.cancelBusy; onClicked: root.testLiveRequested(root.selectedVariant) }
                    }
                    Rectangle {
                        width: 100; height: 40; radius: 8
                        color: Color.accent
                        opacity: root.workspaceReady && !root.previewBusy && !root.cancelBusy ? 1 : .45
                        Text { anchors.centerIn: parent; text: root.demoBusy ? (root.demoActive ? "Dispatching…" : "Opening…") : (root.demoActive ? "Dispatch" : "Demo"); color: Color.background; font.pixelSize: 13; font.bold: true }
                        MouseArea { anchors.fill: parent; enabled: root.demoActive ? !root.demoBusy && !root.cancelBusy : root.workspaceReady && !root.previewBusy && !root.cancelBusy; onClicked: root.demoRequested(root.selectedVariant) }
                    }
                }
            }
        }
        Rectangle { anchors.centerIn:parent; visible:root.generationBusy || (root.active&&!root.workspaceReady&&root.errorMessage===""); width:260; height:80; radius:12; color:Color.background; border.width:1; border.color:Color.muted; Text { anchors.centerIn:parent; text:root.generationBusy?"Generating themes…":"Loading palettes…"; color:Color.foreground; font.pixelSize:14 } }
    }
}
