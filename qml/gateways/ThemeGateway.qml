import QtQuick

Item {
    id: root

    property string executable: ""

    signal catalogLoaded(var themes)
    signal catalogFailed(string message)
    signal editOpened(var result)
    signal editOpenFailed(string message)

    function list() { listCommand.exec([root.executable, "theme", "list"]) }
    function openForEdit(themeId) { editCommand.exec([root.executable, "theme", "edit", themeId]) }

    BackendCommand {
        id: listCommand
        failureFallback: "Failed to load installed themes"
        invalidJsonFallback: "Backend returned invalid theme catalog JSON"
        onCompleted: function(result) {
            if (!Array.isArray(result)) {
                root.catalogFailed("Backend returned an invalid theme catalog")
                return
            }
            root.catalogLoaded(result)
        }
        onFailed: root.catalogFailed(message)
    }

    BackendCommand {
        id: editCommand
        failureFallback: "Failed to open theme for editing"
        invalidJsonFallback: "Backend returned invalid theme edit JSON"
        onCompleted: function(result) {
            if (!result || !result.session_id || result.workflow !== "theme-edit" || !result.generation_id || result.variant !== "source" || !result.palette) {
                root.editOpenFailed("Backend returned an incomplete theme edit workspace")
                return
            }
            root.editOpened(result)
        }
        onFailed: root.editOpenFailed(message)
    }
}
