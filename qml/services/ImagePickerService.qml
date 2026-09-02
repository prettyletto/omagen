import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""
    property alias running: picker.running
    property bool ignoreNextExit: false

    signal selected(string path)
    signal cancelled()
    signal failed(string message)

    function choose(directory) {
        root.ignoreNextExit = false;
        var command = root.executable !== "" ? root.executable : "omarchy"
        var args = root.executable !== ""
            ? [command]
            : [command, "file", "select"]
        if (directory && root.executable !== "")
            args.push("--initial-directory", directory)
        args.push(
            "--title",
            "Choose a PNG or JPEG image for Omagen",
            "--extensions",
            "png jpg jpeg"
        )
        picker.exec(args)
    }

    function cancel() {
        // Stopping Process emits onExited. That exit belongs to the explicit
        // close request and must not be translated into onCancelled, because
        // the composition root would otherwise reopen the overlay after it
        // has just been dismissed.
        root.ignoreNextExit = true;
        if (!picker.running)
            return false;
        picker.running = false;
        return true;
    }

    Process {
        id: picker

        stdout: BoundedOutputParser {
            id: pickerStdout
        }

        stderr: BoundedOutputParser {
            id: pickerStderr
        }

        onStarted: {
            pickerStdout.reset();
            pickerStderr.reset();
        }

        onExited: function(exitCode, exitStatus) {
            if (root.ignoreNextExit) {
                root.ignoreNextExit = false;
                return;
            }

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
