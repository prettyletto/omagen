import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal sessionBegan(
        string sessionId,
        string originalTheme,
        string backgroundKind,
        string backgroundPath
    )
    signal sessionBeginFailed(string message)
    signal sessionCancelled(string sessionId)
    signal sessionCancelFailed(string message)

    function beginSession() {
        sessionBeginProcess.exec([root.executable, "session", "begin"]);
    }

    function cancelSession(sessionId) {
        sessionCancelProcess.exec([
            root.executable,
            "session",
            "cancel",
            sessionId
        ]);
    }

    Process {
        id: sessionBeginProcess

        stdout: StdioCollector {
            id: sessionBeginStdout
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: sessionBeginStderr
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionBeginStderr.text.trim();
                root.sessionBeginFailed(
                    message !== "" ? message : "Failed to begin session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionBeginStdout.text);
                const background = result.original_background || {};
                const sessionId = result.session_id || "";
                const originalTheme = result.original_theme || "";
                const backgroundKind = background.kind || "";
                const backgroundPath = background.path || "";

                if (
                    sessionId === "" ||
                    originalTheme === "" ||
                    backgroundKind === "" ||
                    backgroundPath === ""
                ) {
                    root.sessionBeginFailed(
                        "Backend returned incomplete session data"
                    );
                    return;
                }

                root.sessionBegan(
                    sessionId,
                    originalTheme,
                    backgroundKind,
                    backgroundPath
                );
            } catch (error) {
                root.sessionBeginFailed("Backend returned invalid JSON");
            }
        }
    }

    Process {
        id: sessionCancelProcess

        stdout: StdioCollector {
            id: sessionCancelStdout
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: sessionCancelStderr
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionCancelStderr.text.trim();
                root.sessionCancelFailed(
                    message !== "" ? message : "Failed to cancel session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionCancelStdout.text);
                if (result.ok !== true || !result.session_id) {
                    root.sessionCancelFailed(
                        "Backend returned invalid cancellation result"
                    );
                    return;
                }
                root.sessionCancelled(result.session_id);
            } catch (error) {
                root.sessionCancelFailed(
                    "Backend returned invalid cancellation JSON"
                );
            }
        }
    }
}
