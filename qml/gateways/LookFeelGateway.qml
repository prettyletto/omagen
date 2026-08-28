import QtQuick

Item {
    id: root

    property string executable: ""

    signal catalogLoaded(var catalog)
    signal catalogFailed(string message)
    signal resolved(var composition)
    signal resolveFailed(string message)

    function list() { catalogCommand.exec([root.executable, "look-feel", "list"]) }
    function resolve(preset) { resolveCommand.exec([root.executable, "look-feel", "resolve", preset]) }

    BackendCommand {
        id: catalogCommand
        failureFallback: "Failed to load Look & Feel presets"
        invalidJsonFallback: "Backend returned invalid Look & Feel catalog JSON"
        onCompleted: function(result) {
            if (!Array.isArray(result)) {
                root.catalogFailed("Backend returned an invalid Look & Feel catalog")
                return
            }
            root.catalogLoaded(result)
        }
        onFailed: root.catalogFailed(message)
    }

    BackendCommand {
        id: resolveCommand
        failureFallback: "Failed to resolve Look & Feel preset"
        invalidJsonFallback: "Backend returned invalid Look & Feel preset JSON"
        onCompleted: function(result) {
            if (!result || !result.preset || !result.window || !result.shell || !result.bar || !result.animations || !result.terminal) {
                root.resolveFailed("Backend returned an incomplete Look & Feel preset")
                return
            }
            root.resolved(result)
        }
        onFailed: root.resolveFailed(message)
    }
}
