import QtQuick
import Quickshell.Io

import "../services" as Services

Item {
    id: root

    property string failureFallback: "Backend command failed"
    property string invalidJsonFallback: "Backend returned invalid JSON"
    property alias running: process.running

    signal completed(var result)
    signal failed(string message)

    function exec(command) {
        process.exec(command)
    }

    Process {
        id: process
        stdout: Services.BoundedOutputParser { id: stdoutBuffer }
        stderr: Services.BoundedOutputParser { id: stderrBuffer }

        onStarted: {
            stdoutBuffer.reset()
            stderrBuffer.reset()
        }

        onExited: function(exitCode, exitStatus) {
            const stderrText = stderrBuffer.text.trim()
            if (exitCode !== 0) {
                root.failed(stderrText !== "" ? stderrText : root.failureFallback)
                return
            }
            try {
                root.completed(JSON.parse(stdoutBuffer.text))
            } catch (error) {
                root.failed(root.invalidJsonFallback)
            }
        }
    }
}
