import QtQuick

// Owns Demo resource state and the distinction between backend-backed Full /
// Window demos and QML-only Shell / Bar demonstrations. Apply listens to the
// completion signals exposed here; the application root only composes the
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
        return root.active && (root.mode === "full" || root.mode === "window")
    }

    function monitorName() {
        return root.focusedMonitorName ? String(root.focusedMonitorName()) : ""
    }

    function startDemo(variant) {
        if (root.active || root.blocked())
            return

        root.errorRaised("")
        root.session.selectVariant(variant)
        root.pendingDemo = true
        root.busy = true
        root.activateCanvasRequested()
        root.hideApplicationRequested()
        root.hideLiveCanvasRequested()
        // Omarchy reloads all Ghostty instances as part of applying a theme.
        // Create the scene first, then apply the selected preview; this is the
        // same ordering as opening the four applications manually before
        // switching a theme.
        root.backend.openDemo(root.session.sessionId)
    }

    function startWindowDemo() {
        if (root.blocked())
            return
        if (root.mode === "window" && root.active) {
            root.dispatch()
            return
        }
        if (root.mode === "shell" && root.active)
            root.stopShellDemo()
        if (root.mode === "bar" && root.active)
            root.stopBarDemo()

        root.errorRaised("")
        root.pendingWindowDemo = true
        root.activateCanvasRequested()
        root.hideApplicationRequested()
        if (root.active) {
            root.busy = true
            root.backend.closeDemo(root.session.sessionId)
            return
        }
        root.pendingWindowDemo = false
        root.busy = true
        root.backend.openWindowDemo(root.session.sessionId)
    }

    function startShellDemo() {
        if (root.blocked())
            return
        if (root.mode === "shell" && root.active) {
            root.stopShellDemo()
            return
        }
        if (root.mode === "bar" && root.active)
            root.stopBarDemo()
        if (root.active) {
            root.errorRaised("Stop the current desktop demo before starting Shell Demo.")
            return
        }

        root.errorRaised("")
        root.activateCanvasRequested()
        root.monitor = root.monitorName()
        root.hideApplicationRequested()
        root.active = true
        root.mode = "shell"
    }

    function startBarDemo() {
        if (root.blocked())
            return
        if (root.mode === "bar" && root.active) {
            root.stopBarDemo()
            return
        }
        if (root.active) {
            root.errorRaised("Stop the current desktop demo before starting Bar Demo.")
            return
        }

        root.errorRaised("")
        root.activateCanvasRequested()
        root.monitor = root.monitorName()
        root.hideApplicationRequested()
        root.active = true
        root.mode = "bar"
    }

    function stopBarDemo() {
        if (root.mode !== "bar")
            return
        root.active = false
        root.mode = "none"
        root.stopped()
    }

    function stopShellDemo() {
        if (root.mode !== "shell")
            return
        root.active = false
        root.mode = "none"
        root.stopped()
    }

    function dispatch() {
        if (!root.active || root.busy || root.cancelBusy)
            return
        if (root.mode === "shell") {
            root.stopShellDemo()
            return
        }
        if (root.mode === "bar") {
            root.stopBarDemo()
            return
        }
        if (!root.session || root.session.sessionId === "")
            return

        root.errorRaised("")
        root.busy = true
        root.backend.closeDemo(root.session.sessionId)
    }

    function openWindowAfterClose() {
        root.busy = true
        root.backend.openWindowDemo(root.session.sessionId)
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
        root.mode = root.active ? (canvasMode || "full") : "none"
        root.busy = false
        root.pendingDemo = false
        root.pendingWindowDemo = false
    }

    function markClosed() {
        root.active = false
        root.mode = "none"
        root.monitor = ""
        root.pendingDemo = false
    }

    function cancel() {
        root.busy = false
        root.markClosed()
        root.pendingWindowDemo = false
    }

    function reset() {
        root.cancel()
    }

    Connections {
        target: root.backend

        function onDemoOpened(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return
            if (sessionId !== root.session.sessionId) {
                root.busy = false
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
            root.pendingDemo = false
            root.openFailed(message)
        }

        function onWindowDemoOpened(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return
            if (sessionId !== root.session.sessionId) {
                root.busy = false
                root.pendingWindowDemo = false
                root.errorRaised("Backend opened a different Window demo session")
                root.windowOpenFailed("Backend opened a different Window demo session")
                return
            }
            root.pendingWindowDemo = false
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
            root.pendingWindowDemo = false
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.windowOpenFailed(message)
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
            root.busy = false
            root.active = false
            root.mode = "none"
            root.monitor = ""
            root.closed(sessionId, wasClosed)
        }

        function onDemoCloseFailed(message) {
            if (root.closeAfterCancel)
                return
            root.busy = false
            root.closeFailed(message)
        }
    }
}
