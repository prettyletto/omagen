import QtQuick

// Owns Demo resource state and the distinction between backend-backed owned
// workspaces and their Full / Window / Shell / Bar surfaces. Apply listens to
// the completion signals exposed here; the application root only composes the
// resulting panel and route state.
Item {
    id: root

    property var backend: null
    property var session: null
    property var previewController: null
    property var focusedMonitorName: null
    property bool applyActive: false
    property bool workspaceReady: false
    property bool previewBusy: false
    property bool applyBusy: false
    property bool cancelBusy: false
    property bool liveCanvasActive: false
    property bool closeAfterCancel: false

    property bool busy: false
    property bool active: false
    property string mode: "none"
    property string monitor: ""
    property bool pendingDemo: false
    property bool pendingWindowDemo: false
    property string pendingMode: "none"
    property string pendingVariant: ""

    readonly property var supportedModes: ["window", "shell", "bar", "full"]

    signal activateCanvasRequested()
    signal hideLiveCanvasRequested()
    signal hideApplicationRequested()
    signal stopped()
    signal errorRaised(string message)
    signal opened(string sessionId, string workspace, string monitor, bool reused)
    signal openFailed(string message)
    signal windowOpened(string sessionId, string workspace, string monitor, bool reused)
    signal windowOpenFailed(string message)
    signal reflowed(string sessionId)
    signal reflowFailed(string message)
    signal captured(string sessionId, string previewPath)
    signal captureFailed(string message)
    signal closed(string sessionId, bool wasClosed)
    signal closeFailed(string message)

    function blocked() {
        return root.busy || root.previewBusy || root.cancelBusy || root.applyBusy
                || !root.workspaceReady
    }

    function backendDemoActive() {
        return root.active && root.mode !== "none"
    }

    function monitorName() {
        return root.focusedMonitorName ? String(root.focusedMonitorName()) : ""
    }

    function normalizeMode(mode) {
        const candidate = String(mode || "")
        return root.supportedModes.indexOf(candidate) >= 0 ? candidate : ""
    }

    function backendMode(mode) {
        return mode !== "none"
    }

    function clearPending() {
        root.pendingDemo = false
        root.pendingWindowDemo = false
        root.pendingMode = "none"
        root.pendingVariant = ""
    }

    function openReader(mode) {
        const target = root.normalizeMode(mode)
        if (target !== "shell" && target !== "bar")
            return "invalid"
        if (!root.session || !root.session.sessionId || !root.backend)
            return "invalid"
        root.errorRaised("")
        root.clearPending()
        root.activateCanvasRequested()
        root.monitor = root.monitorName()
        root.hideApplicationRequested()
        root.busy = true
        root.backend.openDemoReader(root.session.sessionId, target)
        return "started"
    }

    function requestWindowPreview() {
        if (!root.pendingWindowDemo)
            return
        if (!root.previewController || !root.session) {
            root.clearPending()
            root.busy = false
            root.errorRaised("Unable to prepare the Window Demo preview")
            return
        }

        root.busy = true
        const outcome = root.previewController.previewCurrentState(root.session.selectedVariant)
        if (outcome === "invalid") {
            root.clearPending()
            root.busy = false
            root.errorRaised("Unable to prepare the Window Demo preview")
        }
        // PreviewController emits the normal applied signal for both a real
        // preview and an already-live no-op. Omagen.qml advances the pending
        // Window Demo only after that signal arrives.
    }

    function handlePreviewApplied() {
        if (!root.pendingWindowDemo)
            return false
        root.openWindowAfterPreview()
        return true
    }

    function handlePreviewFailed(message) {
        if (!root.pendingWindowDemo)
            return false
        root.clearPending()
        root.busy = false
        root.errorRaised(message)
        return true
    }

    function openMode(mode, variant) {
        const target = root.normalizeMode(mode)
        if (target === "")
            return "invalid"
        if (target === "shell" || target === "bar") {
            return root.openReader(target)
        }

        if (!root.session || !root.session.sessionId)
            return "invalid"

        const selectedVariant = variant || root.session.selectedVariant
        root.session.selectVariant(selectedVariant)
        root.activateCanvasRequested()
        root.hideApplicationRequested()
        root.hideLiveCanvasRequested()
        root.busy = true

        if (target === "window") {
            root.pendingDemo = false
            root.pendingWindowDemo = true
            root.requestWindowPreview()
            return "started"
        }

        root.pendingDemo = true
        root.pendingWindowDemo = false
        // Omarchy reloads all Ghostty instances as part of applying a theme.
        // Create the scene first, then apply the selected preview; this is the
        // same ordering as opening the four applications manually before
        // switching a theme.
        root.backend.openDemo(root.session.sessionId)
        return "started"
    }

    // All Demo choices enter through this transition. A repeated choice stops
    // the active surface; a different owned mode closes the backend workspace
    // before continuing, while readers can switch synchronously.
    function requestMode(mode, variant) {
        const target = root.normalizeMode(mode)
        if (target === "") {
            root.errorRaised("Unknown Demo mode")
            return "invalid"
        }

        // Stopping an active surface is always allowed when no operation is
        // already in flight. This keeps the cleanup affordance available even
        // if the session's readiness mirror briefly lags behind the backend.
        if (root.active && root.mode === target) {
            if (root.busy || root.previewBusy || root.cancelBusy || root.applyBusy)
                return "blocked"
            if (root.backendMode(target))
                root.dispatch()
            else if (target === "shell")
                root.stopShellDemo()
            else
                root.stopBarDemo()
            return "stopped"
        }

        if (root.blocked())
            return "blocked"
        if (!root.session || !root.session.sessionId) {
            root.errorRaised("No active session is available for Demo")
            return "invalid"
        }

        root.errorRaised("")
        if (root.active && root.backendDemoActive()) {
            root.pendingMode = target
            root.pendingVariant = variant || root.session.selectedVariant
            if (target === "full")
                root.session.selectVariant(root.pendingVariant)
            root.busy = true
            root.activateCanvasRequested()
            root.hideApplicationRequested()
            root.hideLiveCanvasRequested()
            root.backend.closeDemo(root.session.sessionId)
            return "switching"
        }

        // Reader surfaces are QML-only overlays, but their workspace remains
        // backend-owned so replacing one uses the same cleanup boundary as
        // Full and Window Demo.
        if (root.active) {
            if (root.mode === "shell")
                root.stopShellDemo()
            else if (root.mode === "bar")
                root.stopBarDemo()
        }
        return root.openMode(target, variant)
    }

    function startDemo(variant) { return root.requestMode("full", variant) }
    function startWindowDemo() { return root.requestMode("window") }
    function startShellDemo() { return root.requestMode("shell") }
    function startBarDemo() { return root.requestMode("bar") }

    function stopBarDemo() {
        if (root.mode !== "bar")
            return
        root.dispatch()
    }

    function stopShellDemo() {
        if (root.mode !== "shell")
            return
        root.dispatch()
    }

    function dispatch() {
        if (!root.active || root.busy || root.cancelBusy)
            return
        if (!root.session || root.session.sessionId === "")
            return

        root.errorRaised("")
        root.clearPending()
        root.busy = true
        // The visible reader surface is QML-owned. Hide it as soon as the
        // cleanup transaction is dispatched while the backend finishes
        // releasing its owned workspace asynchronously. The backend close
        // signal remains authoritative for completion and recovery.
        root.active = false
        root.mode = "none"
        root.monitor = ""
        root.backend.closeDemo(root.session.sessionId)
    }

    function openWindowAfterClose() {
        root.requestWindowPreview()
    }

    function openWindowAfterPreview() {
        if (!root.pendingWindowDemo)
            return
        root.busy = true
        root.backend.openWindowDemo(root.session.sessionId)
    }

    function continueAfterBackendClose() {
        const target = root.pendingMode
        const variant = root.pendingVariant
        root.pendingMode = "none"
        root.pendingVariant = ""
        if (target !== "none")
            root.openMode(target, variant)
    }

    function reflow() {
        root.busy = true
        root.backend.reflowDemo(root.session.sessionId)
    }

    function finishPendingDemo() {
        root.pendingDemo = false
        root.busy = false
    }

    function resume(canvasActive, canvasMode, canvasMonitor) {
        root.monitor = canvasMonitor || ""
        root.active = canvasActive === true
        root.mode = root.active ? (root.normalizeMode(canvasMode) || "full") : "none"
        root.busy = false
        root.clearPending()
    }

    function markClosed() {
        root.active = false
        root.mode = "none"
        root.monitor = ""
        root.clearPending()
    }

    function cancel() {
        root.busy = false
        root.markClosed()
    }

    function reset() {
        root.cancel()
    }

    Connections {
        target: root.backend

        function onDemoOpened(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return
            if (!root.session || sessionId !== root.session.sessionId) {
                root.busy = false
                root.active = false
                root.mode = "none"
                root.monitor = ""
                root.clearPending()
                root.errorRaised("Backend opened a different demo session")
                root.openFailed("Backend opened a different demo session")
                return
            }
            root.active = true
            root.mode = "full"
            root.monitor = monitor
            if (!root.pendingDemo && !root.applyActive)
                root.busy = false
            root.opened(sessionId, workspace, monitor, reused)
        }

        function onDemoOpenFailed(message) {
            if (root.closeAfterCancel)
                return
            root.busy = false
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.clearPending()
            root.openFailed(message)
        }

        function onWindowDemoOpened(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return
            if (!root.session || sessionId !== root.session.sessionId) {
                root.busy = false
                root.active = false
                root.mode = "none"
                root.monitor = ""
                root.clearPending()
                root.errorRaised("Backend opened a different Window demo session")
                root.windowOpenFailed("Backend opened a different Window demo session")
                return
            }
            root.clearPending()
            root.active = true
            root.mode = "window"
            root.monitor = monitor
            root.busy = false
            root.windowOpened(sessionId, workspace, monitor, reused)
        }

        function onWindowDemoOpenFailed(message) {
            if (root.closeAfterCancel)
                return
            root.busy = false
            root.clearPending()
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.windowOpenFailed(message)
        }

        function onDemoReaderOpened(sessionId, workspace, monitor, mode, reused) {
            if (root.closeAfterCancel)
                return
            if (!root.session || sessionId !== root.session.sessionId
                    || (mode !== "shell" && mode !== "bar")) {
                root.busy = false
                root.active = false
                root.mode = "none"
                root.monitor = ""
                root.clearPending()
                root.errorRaised("Backend opened an invalid reader Demo session")
                root.openFailed("Backend opened an invalid reader Demo session")
                return
            }
            root.clearPending()
            root.active = true
            root.mode = mode
            root.monitor = monitor
            root.busy = false
            root.opened(sessionId, workspace, monitor, reused)
        }

        function onDemoReaderOpenFailed(message) {
            if (root.closeAfterCancel)
                return
            root.busy = false
            root.clearPending()
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.openFailed(message)
        }

        function onDemoReflowed(sessionId) {
            if (root.closeAfterCancel)
                return
            if (sessionId !== root.session.sessionId) {
                root.busy = false
                root.errorRaised("Backend reflowed a different live canvas session")
                root.reflowFailed("Backend reflowed a different live canvas session")
                return
            }
            root.busy = false
            root.reflowed(sessionId)
        }

        function onDemoReflowFailed(message) {
            if (root.closeAfterCancel)
                return
            root.busy = false
            root.reflowFailed(message)
        }

        function onDemoCaptured(sessionId, previewPath) {
            if (root.closeAfterCancel)
                return
            root.captured(sessionId, previewPath)
        }

        function onDemoCaptureFailed(message) {
            if (root.closeAfterCancel)
                return
            root.captureFailed(message)
        }

        function onDemoClosed(sessionId, wasClosed) {
            if (root.closeAfterCancel)
                return
            if (!root.session || sessionId !== root.session.sessionId) {
                root.errorRaised("Backend closed a different live canvas session")
                return
            }
            root.busy = false
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.closed(sessionId, wasClosed)
            root.continueAfterBackendClose()
        }

        function onDemoCloseFailed(message) {
            if (root.closeAfterCancel)
                return
            root.clearPending()
            root.busy = false
            root.closeFailed(message)
        }
    }
}
