import QtQuick

// Owns frontend generation sequencing: generate, describe, and discard. The
// backend/session packages remain authoritative for generation artifacts and
// durable session state.
Item {
    id: root

    property var backend: null
    property var session: null
    property bool cancelBusy: false
    property bool closeAfterCancel: false

    property bool generating: false
    property bool describing: false
    property bool regenerationPending: false
    property bool returning: false

    signal failed(string sessionId, string message, bool wasRegeneration)
    signal described(string sessionId, string generationId, var variants, bool wasRegeneration)
    signal discarded(string sessionId, string generationId)
    signal discardFailed(string sessionId, string message)

    function generate(imagePath, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency, regenerate) {
        if (!root.session || !root.session.sessionId || root.generating || root.describing
                || root.cancelBusy)
            return
        root.generating = true
        root.describing = false
        root.regenerationPending = regenerate === true
        root.backend.generateTheme(
            root.session.sessionId,
            imagePath,
            shellStyle,
            desktopStyle,
            barStyle,
            animationsStyle,
            lookFeel,
            terminalTranslucency
        )
    }

    function discard() {
        if (!root.session || !root.session.active || !root.session.sessionId
                || !root.session.generationId || root.returning || root.cancelBusy)
            return
        root.returning = true
        root.backend.discardGeneration(root.session.sessionId, root.session.generationId)
    }

    function reset() {
        root.generating = false
        root.describing = false
        root.regenerationPending = false
        root.returning = false
    }

    Connections {
        target: root.backend

        function onGenerationCompleted(sessionId, generationId) {
            if (root.closeAfterCancel || root.cancelBusy || !root.session
                    || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.generating = false
            root.describing = true
            root.backend.describeGeneration(sessionId, generationId)
        }

        function onGenerationFailed(sessionId, message) {
            if (root.closeAfterCancel || root.cancelBusy || !root.session
                    || !root.session.active || sessionId !== root.session.sessionId)
                return
            const wasRegeneration = root.regenerationPending
            root.generating = false
            root.regenerationPending = false
            root.failed(sessionId, message, wasRegeneration)
        }

        function onGenerationDescribed(sessionId, generationId, variants) {
            if (root.closeAfterCancel || root.cancelBusy || !root.session
                    || !root.session.active || sessionId !== root.session.sessionId)
                return
            const wasRegeneration = root.regenerationPending
            root.describing = false
            root.regenerationPending = false
            root.session.setGeneration(generationId, variants)
            root.described(sessionId, generationId, variants, wasRegeneration)
        }

        function onGenerationDescribeFailed(sessionId, message) {
            if (root.closeAfterCancel || root.cancelBusy || !root.session
                    || !root.session.active || sessionId !== root.session.sessionId)
                return
            const wasRegeneration = root.regenerationPending
            root.describing = false
            root.regenerationPending = false
            root.failed(sessionId, message, wasRegeneration)
        }

        function onGenerationDiscarded(sessionId, generationId) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId
                    || generationId !== root.session.generationId)
                return
            root.returning = false
            root.regenerationPending = false
            root.discarded(sessionId, generationId)
        }

        function onGenerationDiscardFailed(sessionId, message) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.returning = false
            root.discardFailed(sessionId, message)
        }
    }
}
