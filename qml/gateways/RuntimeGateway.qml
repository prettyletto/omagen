import QtQuick

Item {
    id: root

    property string executable: ""

    signal statusLoaded(var status)
    signal statusFailed(string message)
    signal installed(string hookPath)
    signal installFailed(string message)
    signal promptDismissed()
    signal promptDismissFailed(string message)

    function check() { statusCommand.exec([root.executable, "runtime", "status"]) }
    function install() { installCommand.exec([root.executable, "runtime", "install"]) }
    function dismiss() { dismissCommand.exec([root.executable, "runtime", "dismiss"]) }

    BackendCommand {
        id: statusCommand
        failureFallback: "Failed to inspect Omagen Advanced Runtime"
        invalidJsonFallback: "Backend returned invalid runtime status JSON"
        onCompleted: root.statusLoaded(result)
        onFailed: root.statusFailed(message)
    }

    BackendCommand {
        id: installCommand
        failureFallback: "Failed to install Omagen Advanced Runtime"
        invalidJsonFallback: "Backend returned invalid runtime installation JSON"
        onCompleted: function(result) {
            if (result.installed !== true || !result.hook_path) {
                root.installFailed("Backend returned incomplete runtime installation data")
                return
            }
            root.installed(result.hook_path)
        }
        onFailed: root.installFailed(message)
    }

    BackendCommand {
        id: dismissCommand
        failureFallback: "Failed to save Omagen runtime setup choice"
        onCompleted: root.promptDismissed()
        onFailed: root.promptDismissFailed(message)
    }
}
