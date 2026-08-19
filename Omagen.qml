import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property bool opened: false
    property bool sessionActive: false
    property string backendStatus: "Not checked"
    property string backendVersion: ""
    property int openCount: 0
    readonly property string backendPath: decodeURIComponent(Qt.resolvedUrl("bin/omagen").toString().replace("file://", ""))

    function open(payload) {
        openCount += 1;
        opened = true;
    }

    function close() {
        opened = false;
    }

    function startSession() {
        sessionActive = true;
    }

    function checkBackend() {
        backendStatus = "Checking...";
        backendProcess.exec([root.backendPath, "ping"]);
    }

    function cancelSession() {
        sessionActive = false;
        opened = false;
    }

    Process {
        id: backendProcess

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.backendStatus = "Error: " + backendStderr.text.trim();
                root.backendVersion = "";
                return ;
            }
            try {
                const result = JSON.parse(backendStdout.text);
                root.backendStatus = result.ok ? "Connected" : "Invalid response";
                root.backendVersion = result.version ?? "";
            } catch (error) {
                root.backendStatus = "Invalid JSON";
                root.backendVersion = "";
            }
        }

        stdout: StdioCollector {
            id: backendStdout

            waitForEnd: true
        }

        stderr: StdioCollector {
            id: backendStderr

            waitForEnd: true
        }

    }

    PanelWindow {
        id: setupWindow

        visible: root.opened && !root.sessionActive
        implicitWidth: 520
        implicitHeight: 360
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
            focus: setupWindow.visible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Omagen"
                    color: Color.foreground
                    font.pixelSize: 30
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Create a theme from an image"
                    color: Color.muted
                    font.pixelSize: 15
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180
                    height: 44
                    radius: 8
                    color: Color.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Generate (fake)"
                        color: Color.background
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.startSession()
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Opened " + root.openCount + " times"
                    color: Color.muted
                    font.pixelSize: 13
                }

            }

        }

    }

    PanelWindow {
        id: workspaceWindow

        visible: root.opened && root.sessionActive
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
            focus: workspaceWindow.visible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180
                    height: 44
                    radius: 8
                    color: Color.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Check Backend"
                        color: Color.background
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.checkBackend()
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.backendStatus + (root.backendVersion !== "" ? " · " + root.backendVersion : "")
                    color: Color.muted
                    font.pixelSize: 14
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Theme Workspace"
                    color: Color.foreground
                    font.pixelSize: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Session is alive"
                    color: Color.muted
                    font.pixelSize: 16
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Rectangle {
                        width: 160
                        height: 44
                        radius: 8
                        color: Color.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Hide"
                            color: Color.background
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.close()
                        }

                    }

                    Rectangle {
                        width: 160
                        height: 44
                        radius: 8
                        color: Color.red

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel Session"
                            color: Color.background
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.cancelSession()
                        }

                    }

                }

            }

        }

    }

}
