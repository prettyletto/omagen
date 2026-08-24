import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal selected(string path)
    signal cancelled()
    signal failed(string message)

    function choose(directory) {
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
