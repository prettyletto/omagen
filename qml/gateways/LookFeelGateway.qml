import QtQuick

Item {
    id: root

    property string executable: ""

    signal catalogLoaded(var catalog)
    signal catalogFailed(string message)
    signal resolved(var composition)
    signal resolveFailed(string message)
    signal presetSaved(var entry)
    signal presetSaveFailed(string message)

    function list() { catalogCommand.exec([root.executable, "look-feel", "list"]) }
    function resolve(preset) { resolveCommand.exec([root.executable, "look-feel", "resolve", preset]) }
    function save(name, composition) {
        saveCommand.exec([root.executable, "look-feel", "save", String(name).trim(), JSON.stringify(composition || ({}))])
    }

    BackendCommand {
        id: catalogCommand
        failureFallback: "Failed to load Look & Feel presets"
        invalidJsonFallback: "Backend returned invalid Look & Feel catalog JSON"
        timeoutFallback: "Look & Feel catalog request timed out"
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
        timeoutFallback: "Look & Feel preset request timed out"
        onCompleted: function(result) {
            if (!result || !result.preset || !result.window || !result.shell || !result.bar || !result.animations || !result.terminal) {
                root.resolveFailed("Backend returned an incomplete Look & Feel preset")
                return
            }
            root.resolved(result)
        }
        onFailed: root.resolveFailed(message)
    }

    BackendCommand {
        id: saveCommand
        failureFallback: "Failed to save Look & Feel preset"
        invalidJsonFallback: "Backend returned invalid Look & Feel save JSON"
        timeoutFallback: "Look & Feel preset save timed out"
        onCompleted: function(result) {
            if (!result || !result.id || result.local !== true) {
                root.presetSaveFailed("Backend returned incomplete Look & Feel preset data")
                return
            }
            root.presetSaved(result)
        }
        onFailed: root.presetSaveFailed(message)
    }
}
