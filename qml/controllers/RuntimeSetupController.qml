import QtQuick

// Owns the development-only Advanced Runtime setup prompt and install state.
// The backend runtime command remains the authority for user-owned hook
// installation; this controller only coordinates the QML prompt lifecycle.
Item {
    id: root

    property var backend: null

    property bool open: false
    property bool busy: false
    property bool installed: false
    property bool promptPending: false
    property bool firstRun: false
    property string theme: ""
    property string message: ""

    signal promptRequired()
    signal continueToBackend()
    signal errorRaised(string message)

    function openSetup(themeName) {
        root.open = true
        root.busy = true
        root.message = ""
        root.promptPending = false
        root.firstRun = false
        if (themeName)
            root.theme = themeName
        root.backend.checkRuntime()
    }

    function probeStartup() {
        root.promptPending = true
        root.firstRun = true
        root.open = false
        root.backend.checkRuntime()
    }

    function closeSetup() {
        root.open = false
        root.busy = false
        root.message = ""
    }

    function dismiss() {
        const wasFirstRun = root.firstRun
        root.closeSetup()
        if (wasFirstRun)
            root.backend.dismissRuntimePrompt()
    }

    function keepNative() {
        if (!root.firstRun) {
            root.closeSetup()
            return
        }
        root.firstRun = false
        root.promptPending = false
        root.closeSetup()
        root.backend.dismissRuntimePrompt()
    }

    function install() {
        if (root.busy)
            return
        root.busy = true
        root.message = ""
        root.backend.installRuntime()
    }

    Connections {
        target: root.backend

        function onRuntimeStatusLoaded(status) {
            root.busy = false
            root.installed = status && status.installed === true
            if (root.promptPending) {
                root.promptPending = false
                if (status && status.prompt_required === true) {
                    root.open = true
                    root.firstRun = true
                    root.promptRequired()
                    return
                }
                root.firstRun = false
                root.open = false
                root.continueToBackend()
                return
            }
            if (root.installed)
                root.message = ""
        }

        function onRuntimeStatusFailed(message) {
            if (root.promptPending) {
                root.promptPending = false
                root.firstRun = false
                root.open = false
                root.continueToBackend()
                return
            }
            root.busy = false
            root.message = message
            root.errorRaised(message)
        }

        function onRuntimeInstalled(hookPath) {
            root.busy = false
            root.installed = true
            root.promptPending = false
            root.firstRun = false
            root.message = "Advanced runtime enabled. Reapply the advanced theme to activate the complete runtime path."
        }

        function onRuntimeInstallFailed(message) {
            root.busy = false
            root.message = message
            root.errorRaised(message)
        }

        function onRuntimePromptDismissFailed(message) {
            root.message = message
            root.errorRaised(message)
        }
    }
}
