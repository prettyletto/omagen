import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property bool opened: false
    property bool sessionActive: false
    property bool sessionBusy: false
    property int openCount: 0
    property string backendStatus: "Not checked"
    property string backendVersion: ""
    property string sourceImage: ""
    property string imagePickerError: ""
    property string sessionId: ""
    property string originalTheme: ""
    property string originalBackground: ""
    property string sessionError: ""
    readonly property string backendPath: decodeURIComponent(Qt.resolvedUrl("bin/omagen").toString().replace("file://", ""))

    function open(payload) {
        openCount += 1;
        opened = true;
    }

    function close() {
        opened = false;
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

    function beginSession() {
        if (sourceImage === "" || sessionBusy)
            return ;

        sessionError = "";
        sessionBusy = true;
        sessionBeginProcess.exec([root.backendPath, "session", "begin"]);
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
                root.backendVersion = result.version || "";
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

            const error = imagePickerStderr.text.trim();
            root.imagePickerError = error !== "" ? error : "Image picker failed";
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

    Process {
        id: sessionBeginProcess

        onExited: function(exitCode, exitStatus) {
            root.sessionBusy = false;
            if (exitCode !== 0) {
                const error = sessionBeginStderr.text.trim();
                root.sessionError = error !== "" ? error : "Failed to begin session";
                return ;
            }
            try {
                const result = JSON.parse(sessionBeginStdout.text);
                const id = result.session_id || "";
                const theme = result.original_theme || "";
                const background = result.original_background || "";
                if (id === "" || theme === "" || background === "") {
                    root.sessionError = "Backend returned incomplete session data";
                    return ;
                }
                root.sessionId = id;
                root.originalTheme = theme;
                root.originalBackground = background;
                root.sessionActive = true;
                root.sessionError = "";
            } catch (error) {
                root.sessionError = "Backend returned invalid JSON";
            }
        }

        stdout: StdioCollector {
            id: sessionBeginStdout

            waitForEnd: true
        }

        stderr: StdioCollector {
            id: sessionBeginStderr

            waitForEnd: true
        }

    }

    PanelWindow {
        id: setupWindow

        visible: root.opened && !root.sessionActive
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
            focus: setupWindow.visible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close();
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

                    Text {
                        anchors.centerIn: parent
                        text: root.sourceImage === "" ? "Choose Image" : "Change Image"
                        color: Color.background
                        font.pixelSize: 14
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
                    height: 220
                    radius: 10
                    color: Color.darkerBackground
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

                Text {
                    visible: root.imagePickerError !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    text: root.imagePickerError
                    color: Color.red
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    visible: root.sourceImage !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180
                    height: 44
                    radius: 8
                    color: Color.accent
                    opacity: root.sessionBusy ? 0.6 : 1

                    Text {
                        anchors.centerIn: parent
                        text: root.sessionBusy ? "Starting..." : "Continue"
                        color: Color.background
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.sessionBusy
                        onClicked: root.beginSession()
                    }

                }

                Text {
                    visible: root.sessionError !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    text: root.sessionError
                    color: Color.red
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
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
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Theme Workspace"
                    color: Color.foreground
                    font.pixelSize: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Session active"
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
                    text: "Original background: " + root.originalBackground
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
                    color: Color.darkerBackground
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
                    height: 44
                    radius: 8
                    color: Color.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Check Backend"
                        color: Color.background
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.checkBackend()
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.backendStatus + (root.backendVersion !== "" ? " · " + root.backendVersion : "")
                    color: Color.foreground
                    opacity: 0.65
                    font.pixelSize: 14
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 160
                    height: 44
                    radius: 8
                    color: Color.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Hide"
                        color: Color.background
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }

                }

            }

        }

    }

}
