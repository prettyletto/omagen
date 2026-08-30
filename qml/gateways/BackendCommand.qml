import QtQuick
import Quickshell.Io

import "../services" as Services

Item {
    id: root

    property string failureFallback: "Backend command failed"
    property string invalidJsonFallback: "Backend returned invalid JSON"
    property string timeoutFallback: "Backend command timed out"
    property int timeoutMs: 10000
    property alias running: process.running

    signal completed(var result)
    signal failed(string message)

    property bool waiting: false
    property bool ignoreNextExit: false

    function exec(command) {
        // A reused Process cannot accept a new command while it is still
        // running. Leave the existing request alone; its timeout will release
        // the process and surface a useful error instead of leaving callers
        // in an unbounded loading state.
        if (process.running)
            return
        root.waiting = true
        process.exec(command)
        timeoutTimer.restart()
    }

    Timer {
        id: timeoutTimer
        interval: root.timeoutMs
        repeat: false

        onTriggered: {
            if (!root.waiting)
                return

            // Stopping Process emits onExited. Mark that exit as ours so the
            // normal non-zero/fallback path cannot report a second error.
            root.waiting = false
            root.ignoreNextExit = true
            if (process.running)
                process.running = false
            root.failed(root.timeoutFallback)
        }
    }

    Process {
        id: process
        stdout: Services.BoundedOutputParser { id: stdoutBuffer }
        stderr: Services.BoundedOutputParser { id: stderrBuffer }

        onStarted: {
            root.ignoreNextExit = false
            stdoutBuffer.reset()
            stderrBuffer.reset()
        }

        onExited: function(exitCode, exitStatus) {
            timeoutTimer.stop()
            root.waiting = false
            if (root.ignoreNextExit) {
                root.ignoreNextExit = false
                return
            }

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
