import QtQuick

Item {
    id: root

    property string executable: ""

    signal snapshotLoaded(string sessionId, var snapshot)
    signal snapshotFailed(string sessionId, string message)
    signal navigationCompleted(string sessionId, var navigation)
    signal navigationFailed(string sessionId, string message)

    function inspect(sessionId) {
        inspectCommand.sessionId = sessionId
        inspectCommand.exec([root.executable, "protocol", "inspect", sessionId])
    }
    function back(sessionId) {
        backCommand.sessionId = sessionId
        backCommand.exec([root.executable, "protocol", "back", sessionId])
    }
    function forward(sessionId) {
        forwardCommand.sessionId = sessionId
        forwardCommand.exec([root.executable, "protocol", "forward", sessionId])
    }

    BackendCommand {
        id: inspectCommand
        property string sessionId: ""
        failureFallback: "Failed to inspect change history"
        invalidJsonFallback: "Backend returned invalid change history JSON"
        onCompleted: function(result) {
            if (!result.session_id || !result.snapshot) {
                root.snapshotFailed(inspectCommand.sessionId, "Backend returned incomplete change history")
                return
            }
            root.snapshotLoaded(result.session_id, result.snapshot)
        }
        onFailed: root.snapshotFailed(inspectCommand.sessionId, message)
    }

    BackendCommand {
        id: backCommand
        property string sessionId: ""
        failureFallback: "Cannot move back in change history"
        invalidJsonFallback: "Backend returned invalid back navigation JSON"
        onCompleted: function(result) {
            if (!result.to_checkpoint_id || !result.state) {
                root.navigationFailed(backCommand.sessionId, "Backend returned incomplete back navigation data")
                return
            }
            root.navigationCompleted(backCommand.sessionId, result)
        }
        onFailed: root.navigationFailed(backCommand.sessionId, message)
    }

    BackendCommand {
        id: forwardCommand
        property string sessionId: ""
        failureFallback: "Cannot move forward in change history"
        invalidJsonFallback: "Backend returned invalid forward navigation JSON"
        onCompleted: function(result) {
            if (!result.to_checkpoint_id || !result.state) {
                root.navigationFailed(forwardCommand.sessionId, "Backend returned incomplete forward navigation data")
                return
            }
            root.navigationCompleted(forwardCommand.sessionId, result)
        }
        onFailed: root.navigationFailed(forwardCommand.sessionId, message)
    }
}
