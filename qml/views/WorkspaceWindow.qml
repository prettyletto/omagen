import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root

    property bool active: false
    property bool cancelBusy: false
    property string sourceImage: ""
    property string sessionId: ""
    property string originalTheme: ""
    property string originalBackgroundKind: ""
    property string originalBackgroundPath: ""
    property string errorMessage: ""

    signal hideRequested()
    signal cancelRequested()

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-workspace"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        focus: root.visible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape && !root.cancelBusy) {
                root.hideRequested();
                event.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Theme Workspace"
                color: Color.foreground
                font.pixelSize: 32
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.cancelBusy ? "Restoring original theme..." : "Session active"
                color: Color.foreground
                opacity: 0.65
                font.pixelSize: 16
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 700
                text: "Session: " + root.sessionId
                color: Color.foreground
                opacity: 0.65
                font.pixelSize: 13
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Original theme: " + root.originalTheme
                color: Color.foreground
                font.pixelSize: 14
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 700
                text: "Original background: " + root.originalBackgroundKind + " · " + root.originalBackgroundPath
                color: Color.foreground
                opacity: 0.65
                font.pixelSize: 13
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: 420
                height: 220
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 10
                color: Util.alpha(Color.background, 0.5)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.sourceImage !== "" ? Util.fileUrl(root.sourceImage) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 420
                    sourceSize.height: 220
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Rectangle {
                    width: 160
                    height: 44
                    radius: 8
                    color: Color.accent
                    opacity: root.cancelBusy ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "Hide"
                        color: Color.background
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.cancelBusy
                        onClicked: root.hideRequested()
                    }
                }

                Rectangle {
                    width: 160
                    height: 44
                    radius: 8
                    color: Color.urgent
                    opacity: root.cancelBusy ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: root.cancelBusy ? "Restoring..." : "Cancel"
                        color: Color.background
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.cancelBusy
                        onClicked: root.cancelRequested()
                    }
                }
            }

            Text {
                visible: root.errorMessage !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 700
                text: root.errorMessage
                color: Color.urgent
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
