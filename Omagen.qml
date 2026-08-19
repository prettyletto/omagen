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
    property string sourceImage: ""
    property string imagePickerError: ""
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

    function chooseImage() {
        imagePickerError = "";
        opened = false;
        imagePickerProcess.exec(["omarchy", "file", "select", "--title", "Choose an image for Omagen", "--extensions", "png jpg jpeg webp"]);
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

    Process {
        id: imagePickerProcess

        onExited: function(exitCode, exitStatus) {
            root.opened = true;
            if (exitCode === 0) {
                const path = imagePickerStdout.text.trim();
                if (path !== "")
                    root.sourceImage = path;

                return ;
            }
            if (exitCode === 1)
                return ;

            root.imagePickerError = imagePickerStderr.text.trim();
        }

        stdout: StdioCollector {
            id: imagePickerStdout

            waitForEnd: true
        }

        stderr: StdioCollector {
            id: imagePickerStderr

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
                        text: root.sourceImage === "" ? "Choose Image" : "Change Image"
                        color: Color.background
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.chooseImage()
                    }

                }

                Rectangle {
                    visible: root.sourceImage !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    height: 180
                    radius: 10

                    Image {
                        anchors.fill: parent
                        source: root.sourceImage !== "" ? Util.fileUrl(root.sourceImage) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 420
                        sourceSize.height: 180
                    }

                }

                Text {
                    visible: root.sourceImage !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    text: root.sourceImage
                    color: Color.muted
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.imagePickerError !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.imagePickerError
                    color: Color.red
                    font.pixelSize: 12
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
