import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property bool opened: false
    property int openCount: 0

    function open(payload) {
        openCount += 1;
        opened = true;
    }

    function close() {
        opened = false;
    }

    PanelWindow {
        visible: root.opened
        color: "transparent"
        WlrLayershell.namespace: "omagen"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

            Item {
                anchors.centerIn: parent
                width: 500
                height: 300
                focus: root.opened
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Omagen"
                        color: Color.foreground
                        font.pixelSize: 32
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Opened " + root.openCount + " times"
                        color: Color.foreground
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press Escape to hide"
                        color: Color.muted
                        font.pixelSize: 14
                    }

                }

            }

        }

    }

}
