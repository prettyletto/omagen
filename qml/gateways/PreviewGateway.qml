import QtQuick
import "PreviewPayload.js" as PreviewPayload

Item {
    id: root

    property string executable: ""

    signal applied(string sessionId, string generationId, string variant, string themeName)
    signal applyFailed(string message)

    function styleOverridesPayload(styles) {
        return PreviewPayload.styleOverridesPayload(styles)
    }

    function apply(sessionId, generationId, variant, colorOverrides, styles) {
        const args = [root.executable, "preview", "apply", sessionId, generationId, variant]
        if (colorOverrides && Object.keys(colorOverrides).length > 0)
            args.push("--colors-json", JSON.stringify(colorOverrides))
        const payload = root.styleOverridesPayload(styles)
        if (payload)
            args.push("--styles-json", JSON.stringify(payload))
        command.exec(args)
    }

    BackendCommand {
        id: command
        failureFallback: "Failed to apply preview"
        invalidJsonFallback: "Backend returned invalid preview JSON"
        onCompleted: function(result) {
            if (!result.session_id || !result.generation_id || !result.variant) {
                root.applyFailed("Backend returned incomplete preview data")
                return
            }
            root.applied(result.session_id, result.generation_id, result.variant, result.theme_name || "")
        }
        onFailed: root.applyFailed(message)
    }
}
