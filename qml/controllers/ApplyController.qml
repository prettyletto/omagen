import QtQuick

// Owns the Apply transaction across final preview, optional Demo capture,
// Demo close, and the durable theme application. Omagen.qml forwards the
// small number of Demo/Preview completion events that are shared with other
// application flows, but it does not own this pending-operation state.
Item {
    id: root

    property var backend: null
    property var session: null
    property var previewController: null
    property var demoController: null

    property bool workspaceReady: false
    property bool previewBusy: false
    property bool demoBusy: false
    property bool cancelBusy: false
    property bool demoActive: false
    property string demoMode: "none"
    property bool closeAfterCancel: false

    property bool busy: false
    property bool recoveryRequired: false
    readonly property bool active: root.busy

    property string pendingVariant: ""
    property string pendingName: ""
    property bool pendingUnlock: false
    property bool pendingAfterDemo: false
    property bool pendingCapture: false
    property bool pendingFreshFullDemo: false
    property bool pendingReplaceSource: false
    property string pendingLookFeelPresetName: ""
    property bool pendingPreview: false
    property bool pendingCloseDemo: false
    property bool pendingAbortAfterDemo: false
    property bool cancelled: false

    signal errorRaised(string message)
    signal hideApplication()
    signal hideLiveCanvasRequested()
    signal showApplication()
    signal demoBusyRequested(bool busy)
    signal stopBarDemoRequested()
    signal completed()

    // An already-live preview is a successful no-op, not a missing signal.
    // Continue into durable Apply immediately so the transaction cannot wait
    // forever for a preview process that correctly did not start.
    function requestFinalPreview(variant) {
        const outcome = root.previewController.previewCurrentState(variant)
        if (outcome === "alreadyLive") {
            // PreviewController emitted the same completion signal used by a
            // real preview. The synchronous signal has already advanced Apply.
            return true
        }
        if (outcome === "invalid") {
            root.handlePreviewFailed("Unable to prepare the final preview")
            return false
        }
        return outcome === "started" || outcome === "queued"
    }

    function apply(variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName) {
        if (!root.workspaceReady || root.busy || root.previewBusy || root.cancelBusy || root.demoBusy)
            return

        root.cancelled = false
        root.errorRaised("")
        root.busy = true
        root.recoveryRequired = false
        root.pendingVariant = variant
        root.pendingName = name
        root.pendingUnlock = generateUnlock === true
        root.pendingCapture = capturePreview === true
        root.pendingReplaceSource = replaceSource === true
        root.pendingLookFeelPresetName = saveLookFeelPreset === true ? String(lookFeelPresetName || "").trim() : ""
        root.pendingPreview = true
        root.pendingCloseDemo = false

        // Apply must materialize one final preview first so staged colours and
        // advanced Window/Shell/Bar settings cannot be lost when Test Live was
        // skipped.
        if (root.pendingCapture) {
            root.pendingAfterDemo = true
            root.pendingFreshFullDemo = true
            root.hideLiveCanvasRequested()
            root.hideApplication()
            root.demoBusyRequested(true)
            if (root.backendDemoActive()) {
                // A captured preview must always represent the Full Demo
                // scene, never the surface that happened to be active when
                // the Apply dialog was confirmed.
                root.backend.closeDemo(root.session.sessionId)
            } else {
                root.backend.openDemo(root.session.sessionId)
            }
            return
        }

        if (root.backendDemoActive()) {
            root.pendingAfterDemo = true
            root.pendingCloseDemo = true
            root.demoBusyRequested(true)
            root.requestFinalPreview(variant)
            return
        }

        root.pendingAfterDemo = false
        root.pendingFreshFullDemo = false
        if (root.demoMode === "bar")
            root.stopBarDemoRequested()
        root.requestFinalPreview(variant)
    }

    function backendDemoActive() {
        return root.demoActive && root.demoMode !== "none"
    }

    function clearPending() {
        root.pendingAfterDemo = false
        root.pendingCapture = false
        root.pendingFreshFullDemo = false
        root.pendingReplaceSource = false
        root.pendingLookFeelPresetName = ""
        root.pendingPreview = false
        root.pendingCloseDemo = false
        root.pendingAbortAfterDemo = false
        root.pendingUnlock = false
        root.pendingVariant = ""
        root.pendingName = ""
    }

    function fail(message) {
        root.errorRaised(message)
        root.pendingCapture = false
        if (root.demoActive) {
            root.pendingAbortAfterDemo = true
            root.demoBusyRequested(true)
            root.backend.closeDemo(root.session.sessionId)
            return
        }

        root.clearPending()
        root.busy = false
        root.demoBusyRequested(false)
        root.showApplication()
    }

    function cancel() {
        root.cancelled = true
        root.clearPending()
        root.busy = false
        root.recoveryRequired = false
    }

    function reset() {
        root.cancelled = false
        root.clearPending()
        root.busy = false
        root.recoveryRequired = false
    }

    function handlePreviewApplied() {
        if (!root.active || root.cancelled)
            return false

        root.pendingPreview = false
        if (root.pendingCapture) {
            root.demoBusyRequested(true)
            root.backend.captureDemoPreview(root.session.sessionId)
            return true
        }
        if (root.pendingCloseDemo) {
            root.pendingCloseDemo = false
            root.demoBusyRequested(true)
            root.backend.closeDemo(root.session.sessionId)
            return true
        }

        root.showApplication()
        root.backend.applyTheme(
            root.session.sessionId,
            root.session.generationId,
            root.pendingVariant,
            root.pendingName,
            root.pendingUnlock,
            false,
            root.pendingReplaceSource,
            root.pendingLookFeelPresetName
        )
        return true
    }

    function handlePreviewFailed(message) {
        if (!root.active || root.cancelled)
            return false
        root.fail(message)
        return true
    }

    function handleDemoOpened(sessionId) {
        if (!root.active || root.cancelled)
            return false
        if (sessionId !== root.session.sessionId) {
            root.fail("Backend opened a different demo session")
            return true
        }
        if (root.pendingCapture) {
            root.pendingFreshFullDemo = false
            root.requestFinalPreview(root.pendingVariant)
            return true
        }
        return false
    }

    function handleDemoOpenFailed(message) {
        if (!root.active || root.cancelled)
            return false
        root.clearPending()
        root.busy = false
        root.demoBusyRequested(false)
        root.errorRaised(message)
        root.showApplication()
        return true
    }

    function handleDemoCaptured(sessionId) {
        if (!root.active || root.cancelled)
            return false
        if (sessionId !== root.session.sessionId) {
            root.fail("Backend captured a different Demo session")
            return true
        }
        if (!root.pendingCapture)
            return false
        root.demoBusyRequested(true)
        root.backend.closeDemo(root.session.sessionId)
        return true
    }

    function handleDemoCaptureFailed(message) {
        if (!root.active || root.cancelled)
            return false
        root.fail(message)
        return true
    }

    function handleDemoClosed(sessionId) {
        if (!root.active || root.cancelled)
            return false
        if (sessionId !== root.session.sessionId) {
            root.errorRaised("Backend closed a different demo session")
            return true
        }

        root.demoBusyRequested(false)
        if (root.pendingFreshFullDemo) {
            root.pendingFreshFullDemo = false
            root.demoBusyRequested(true)
            root.backend.openDemo(root.session.sessionId)
            return true
        }
        if (root.pendingAbortAfterDemo) {
            root.clearPending()
            root.busy = false
            root.showApplication()
            return true
        }
        if (!root.pendingAfterDemo)
            return false

        const variant = root.pendingVariant
        const name = root.pendingName
        const generateUnlock = root.pendingUnlock
        const capturePreview = root.pendingCapture
        const replaceSource = root.pendingReplaceSource
        const saveLookFeelPresetName = root.pendingLookFeelPresetName
        root.clearPending()
        // Demo capture hides Omagen while the screenshot is taken, but the
        // permanent Go/theme-set phase stays behind the applying modal until
        // the backend process fully completes.
        root.showApplication()
        root.backend.applyTheme(
            root.session.sessionId,
            root.session.generationId,
            variant,
            name,
            generateUnlock,
            capturePreview,
            replaceSource,
            saveLookFeelPresetName
        )
        return true
    }

    function handleDemoCloseFailed(message) {
        if (!root.active || root.cancelled)
            return false
        root.clearPending()
        root.busy = false
        root.demoBusyRequested(false)
        root.errorRaised(message)
        root.showApplication()
        return true
    }

    function handleThemeApplied(sessionId, generationId) {
        if (!root.active || root.cancelled)
            return false
        if (sessionId !== root.session.sessionId || generationId !== root.session.generationId) {
            root.clearPending()
            root.busy = false
            root.recoveryRequired = true
            root.errorRaised("Backend applied a different generation")
            root.showApplication()
            return true
        }
        root.busy = false
        root.clearPending()
        root.completed()
        return true
    }

    function handleThemeApplyFailed(message) {
        if (!root.active || root.cancelled)
            return false
        root.busy = false
        root.recoveryRequired = true
        root.errorRaised(message)
        root.showApplication()
        return true
    }

    Connections {
        target: root.previewController

        function onApplied() {
            root.handlePreviewApplied()
        }

        function onFailed(message) {
            root.handlePreviewFailed(message)
        }
    }

    Connections {
        target: root.demoController

        function onOpened(sessionId) {
            root.handleDemoOpened(sessionId)
        }

        function onOpenFailed(message) {
            root.handleDemoOpenFailed(message)
        }

        function onCaptured(sessionId) {
            root.handleDemoCaptured(sessionId)
        }

        function onCaptureFailed(message) {
            root.handleDemoCaptureFailed(message)
        }

        function onClosed(sessionId) {
            root.handleDemoClosed(sessionId)
        }

        function onCloseFailed(message) {
            root.handleDemoCloseFailed(message)
        }
    }

    Connections {
        target: root.backend

        function onThemeApplied(sessionId, generationId) {
            root.handleThemeApplied(sessionId, generationId)
        }

        function onThemeApplyFailed(message) {
            root.handleThemeApplyFailed(message)
        }
    }
}
