import QtQuick

Item {
    id: root

    property string executable: ""

    signal applied(string sessionId, string generationId, string variant, string themeName)
    signal applyFailed(string message)

    function apply(sessionId, generationId, variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPresetName) {
        const args = [root.executable, "apply", sessionId, generationId, variant, name]
        if (generateUnlock)
            args.push("--unlock")
        if (capturePreview)
            args.push("--live-preview")
        if (replaceSource)
            args.push("--replace-source")
        if (saveLookFeelPresetName && String(saveLookFeelPresetName).trim() !== "")
            args.push("--save-look-feel-preset", String(saveLookFeelPresetName).trim())
        command.exec(args)
    }

    BackendCommand {
        id: command
        failureFallback: "Failed to apply theme"
        invalidJsonFallback: "Backend returned invalid apply JSON"
        onCompleted: function(result) {
            if (!result.session_id || !result.generation_id || !result.variant || !result.theme_name) {
                root.applyFailed("Backend returned incomplete apply data")
                return
            }
            root.applied(result.session_id, result.generation_id, result.variant, result.theme_name)
        }
        onFailed: root.applyFailed(message)
    }
}
