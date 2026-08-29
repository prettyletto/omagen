import QtQuick

// Owns the preview command and the small piece of state that describes an
// in-flight colour preview. Higher-level Apply and Demo sequencing remains in
// Omagen.qml until those state machines move behind their own controllers.
Item {
    id: root

    property var backend: null
    property var session: null
    property var liveCanvasPanel: null
    property var stylesForVariant: null
    property bool closeAfterCancel: false

    property bool busy: false
    property bool pendingColorPreview: false
    property string activeSignature: ""
    property string lastAppliedSignature: ""

    signal applied(string sessionId, string generationId, string variant, string themeName)
    signal rejected(string message)
    signal failed(string message)

    function stableValue(value) {
        if (value === null || value === undefined)
            return null
        if (Array.isArray(value))
            return value.map(function(item) { return root.stableValue(item) })
        if (typeof value !== "object")
            return value

        var sorted = ({})
        Object.keys(value).sort().forEach(function(key) {
            sorted[key] = root.stableValue(value[key])
        })
        return sorted
    }

    function signature(variant, overrides, styles) {
        return JSON.stringify({
            sessionId: String(root.session && root.session.sessionId || ""),
            generationId: String(root.session && root.session.generationId || ""),
            variant: String(variant || ""),
            overrides: root.stableValue(overrides || ({})),
            styles: root.stableValue(styles || null)
        })
    }

    function previewCurrentState(variant) {
        if (!root.session || !root.session.workspaceReady || !root.liveCanvasPanel)
            return

        const selectedVariant = variant || root.session.selectedVariant
        const overrides = root.liveCanvasPanel.overridesForVariant(selectedVariant)
        root.start(
            selectedVariant,
            overrides,
            root.stylesForVariant ? root.stylesForVariant(selectedVariant) : null,
            Object.keys(overrides).length > 0
        )
    }

    function start(variant, overrides, styles, pendingColors) {
        if (!root.backend || !root.session || !root.session.sessionId
                || !root.session.generationId)
            return false

        const nextSignature = root.signature(variant, overrides, styles)
        if (!root.busy && nextSignature === root.lastAppliedSignature)
            return false

        root.pendingColorPreview = pendingColors === true
        root.activeSignature = nextSignature
        root.busy = true
        root.backend.applyPreview(
            root.session.sessionId,
            root.session.generationId,
            variant,
            overrides || ({}),
            styles || null
        )
        return true
    }

    function reset() {
        root.busy = false
        root.pendingColorPreview = false
        root.activeSignature = ""
        root.lastAppliedSignature = ""
    }

    Connections {
        target: root.backend

        function onPreviewApplied(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return

            root.busy = false
            if (!root.session || sessionId !== root.session.sessionId
                    || generationId !== root.session.generationId) {
                root.rejected("Backend previewed a different generation")
                return
            }

            if (root.pendingColorPreview) {
                root.pendingColorPreview = false
                if (root.liveCanvasPanel)
                    root.liveCanvasPanel.markColorsLive()
            }
            root.lastAppliedSignature = root.activeSignature
            root.activeSignature = ""
            root.session.markPreviewed(variant)
            root.applied(sessionId, generationId, variant, themeName)
        }

        function onPreviewApplyFailed(message) {
            if (root.closeAfterCancel)
                return

            root.busy = false
            root.pendingColorPreview = false
            root.activeSignature = ""
            root.failed(message)
        }
    }
}
