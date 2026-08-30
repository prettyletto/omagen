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
    property string lastAppliedThemeName: ""
    // Preview is single-flight. While the native driver is changing the
    // desktop, retain only the newest intent; BackendCommand deliberately
    // refuses to start a second process on the same seam.
    property var queuedRequest: null

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
            return "invalid"

        const selectedVariant = variant || root.session.selectedVariant
        const overrides = root.liveCanvasPanel.overridesForVariant(selectedVariant)
        return root.start(
            selectedVariant,
            overrides,
            root.stylesForVariant ? root.stylesForVariant(selectedVariant) : null,
            Object.keys(overrides).length > 0
        )
    }

    function start(variant, overrides, styles, pendingColors) {
        if (!root.backend || !root.session || !root.session.sessionId
                || !root.session.generationId)
            return "invalid"

        const nextSignature = root.signature(variant, overrides, styles)
        if (!root.busy && nextSignature === root.lastAppliedSignature) {
            // Preserve the normal completion signal for callers such as Demo
            // and Apply. A deduplicated request is still a completed preview
            // from the coordinator's point of view.
            root.applied(
                root.session.sessionId,
                root.session.generationId,
                String(variant || ""),
                root.lastAppliedThemeName
            )
            return "alreadyLive"
        }

        const request = {
            variant: String(variant || ""),
            overrides: overrides || ({}),
            styles: styles || null,
            pendingColors: pendingColors === true,
            signature: nextSignature
        }
        if (root.busy) {
            // Do not queue a sequence. The most recent complete appearance is
            // the only one the user can still intend to see.
            root.queuedRequest = request
            return "queued"
        }

        root.pendingColorPreview = request.pendingColors
        root.activeSignature = nextSignature
        root.busy = true
        root.backend.applyPreview(
            root.session.sessionId,
            root.session.generationId,
            request.variant,
            request.overrides,
            request.styles
        )
        return "started"
    }

    function startQueuedOrEmit(sessionId, generationId, variant, themeName) {
        const queued = root.queuedRequest
        root.queuedRequest = null
        if (!queued) {
            root.applied(sessionId, generationId, variant, themeName)
            return
        }

        if (queued.signature === root.lastAppliedSignature) {
            // The latest request was equivalent to the preview that just
            // completed. Report one completion and avoid a second driver run.
            root.pendingColorPreview = false
            root.lastAppliedThemeName = themeName
            root.applied(sessionId, generationId, queued.variant, themeName)
            return
        }

        const outcome = root.start(
            queued.variant,
            queued.overrides,
            queued.styles,
            queued.pendingColors
        )
        if (outcome === "invalid")
            root.failed("Preview request became invalid while applying the latest appearance")
    }

    function reset() {
        root.busy = false
        root.pendingColorPreview = false
        root.activeSignature = ""
        root.lastAppliedSignature = ""
        root.queuedRequest = null
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
            root.lastAppliedThemeName = themeName
            root.activeSignature = ""
            root.session.markPreviewed(variant)
            root.startQueuedOrEmit(sessionId, generationId, variant, themeName)
        }

        function onPreviewApplyFailed(message) {
            if (root.closeAfterCancel)
                return

            root.busy = false
            root.pendingColorPreview = false
            root.activeSignature = ""
            const queued = root.queuedRequest
            root.queuedRequest = null
            if (queued) {
                const outcome = root.start(
                    queued.variant,
                    queued.overrides,
                    queued.styles,
                    queued.pendingColors
                )
                if (outcome !== "started" && outcome !== "alreadyLive")
                    root.failed(message)
                return
            }
            root.failed(message)
        }
    }
}
