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

    signal applied(string sessionId, string generationId, string variant, string themeName)
    signal rejected(string message)
    signal failed(string message)

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
            return

        root.pendingColorPreview = pendingColors === true
        root.busy = true
        root.backend.applyPreview(
            root.session.sessionId,
            root.session.generationId,
            variant,
            overrides || ({}),
            styles || null
        )
    }

    function reset() {
        root.busy = false
        root.pendingColorPreview = false
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
            root.session.markPreviewed(variant)
            root.applied(sessionId, generationId, variant, themeName)
        }

        function onPreviewApplyFailed(message) {
            if (root.closeAfterCancel)
                return

            root.busy = false
            root.pendingColorPreview = false
            root.failed(message)
        }
    }
}
