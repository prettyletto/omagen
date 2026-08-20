import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property string sourceImage: ""
    property string errorMessage: ""

    signal chooseImageRequested()
    signal settingsRequested()
    signal continueRequested()
    signal hideRequested()

    visible: active
    implicitWidth: 520
    implicitHeight: 600
    color: "transparent"
    WlrLayershell.namespace: "omagen-setup"
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
            anchors.centerIn: parent
            spacing: 18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Omagen"
                color: Color.foreground
                font.pixelSize: 30
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Create a theme from an image"
                color: Color.foreground
                opacity: 0.65
                font.pixelSize: 15
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 44
                radius: 8
                color: Color.accent
                opacity: root.busy ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: root.sourceImage === "" ? "Choose Image" : "Change Image"
                    color: Color.background
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    onClicked: root.chooseImageRequested()
                }
            }

            Rectangle {
                visible: root.sourceImage !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                height: 220
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

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 40
                radius: 8
                color: Util.alpha(Color.background, 0.5)
                border.width: 1
                border.color: Color.muted

                Text {
                    anchors.centerIn: parent
                    text: "Settings"
                    color: Color.foreground
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    onClicked: root.settingsRequested()
                }
            }

            Text {
                visible: root.sourceImage !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                text: root.sourceImage
                color: Color.foreground
                opacity: 0.65
                font.pixelSize: 12
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                visible: root.sourceImage !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 44
                radius: 8
                color: Color.accent
                opacity: root.busy ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Starting..." : "Continue"
                    color: Color.background
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    onClicked: root.continueRequested()
                }
            }

            Text {
                visible: root.errorMessage !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                text: root.errorMessage
                color: Color.urgent
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
