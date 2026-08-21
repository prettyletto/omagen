import QtQuick
import Quickshell.Io

Item {
    id: root

    signal selected(string path)
    signal cancelled()
    signal failed(string message)

    function choose() {
        picker.exec([
            "omarchy",
            "file",
            "select",
            "--title",
            "Choose a PNG or JPEG image for Omagen",
            "--extensions",
            "png jpg jpeg"
        ]);
    }

    Process {
        id: picker

        stdout: StdioCollector {
            id: pickerStdout
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: pickerStderr
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.selected(pickerStdout.text.trim());
                return;
            }

            if (exitCode === 1) {
                root.cancelled();
                return;
            }

            const message = pickerStderr.text.trim();
            root.failed(message !== "" ? message : "Image picker failed");
        }
    }
}
