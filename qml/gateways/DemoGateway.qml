import QtQuick

Item {
    id: root

    property string executable: ""

    signal opened(string sessionId, string workspace, string monitor, bool reused)
    signal openFailed(string message)
    signal windowOpened(string sessionId, string workspace, string monitor, bool reused)
    signal windowOpenFailed(string message)
    signal reflowed(string sessionId)
    signal reflowFailed(string message)
    signal closed(string sessionId, bool wasClosed)
    signal closeFailed(string message)
    signal captured(string sessionId, string previewPath)
    signal captureFailed(string message)

    function open(sessionId) { openCommand.exec([root.executable, "demo", "open", sessionId]) }
    function openWindow(sessionId) { windowOpenCommand.exec([root.executable, "demo", "open-window", sessionId]) }
    function reflow(sessionId) { reflowCommand.exec([root.executable, "demo", "reflow", sessionId]) }
    function close(sessionId) { closeCommand.exec([root.executable, "demo", "close", sessionId]) }
    function capture(sessionId) { captureCommand.exec([root.executable, "demo", "capture", sessionId]) }

    BackendCommand {
        id: openCommand
        failureFallback: "Failed to open demo workspace"
        invalidJsonFallback: "Backend returned invalid demo JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id || !result.workspace || !result.monitor) {
                root.openFailed("Backend returned incomplete live canvas data")
                return
            }
            root.opened(result.session_id, result.workspace, result.monitor, result.reused === true)
        }
        onFailed: root.openFailed(message)
    }

    BackendCommand {
        id: windowOpenCommand
        failureFallback: "Failed to open Window demo"
        invalidJsonFallback: "Backend returned invalid Window demo JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id || !result.workspace || !result.monitor) {
                root.windowOpenFailed("Backend returned incomplete Window demo data")
                return
            }
            root.windowOpened(result.session_id, result.workspace, result.monitor, result.reused === true)
        }
        onFailed: root.windowOpenFailed(message)
    }

    BackendCommand {
        id: reflowCommand
        failureFallback: "Failed to reflow live canvas"
        invalidJsonFallback: "Backend returned invalid live canvas reflow JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id) {
                root.reflowFailed("Backend returned incomplete live canvas reflow data")
                return
            }
            root.reflowed(result.session_id)
        }
        onFailed: root.reflowFailed(message)
    }

    BackendCommand {
        id: closeCommand
        failureFallback: "Failed to close demo workspace"
        invalidJsonFallback: "Backend returned invalid demo cleanup JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id) {
                root.closeFailed("Backend returned incomplete demo cleanup data")
                return
            }
            root.closed(result.session_id, result.closed === true)
        }
        onFailed: root.closeFailed(message)
    }

    BackendCommand {
        id: captureCommand
        failureFallback: "Failed to capture Demo preview"
        invalidJsonFallback: "Backend returned invalid Demo capture JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id || !result.preview_path) {
                root.captureFailed("Backend returned incomplete Demo capture data")
                return
            }
            root.captured(result.session_id, result.preview_path)
        }
        onFailed: root.captureFailed(message)
    }
}
