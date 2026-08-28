import QtQuick

// Owns protocol history inspection/navigation state. Applying a returned
// checkpoint remains an application-level style-document operation and is
// exposed as a high-level navigation signal.
Item {
    id: root

    property var backend: null
    property var session: null
    property bool workspaceReady: false
    property bool previewBusy: false
    property bool cancelBusy: false
    property bool applyBusy: false

    property bool busy: false
    property bool canBack: false
    property bool canForward: false
    property string message: ""

    signal navigationCompleted(var navigation)

    function refresh() {
        if (!root.session || !root.session.active || !root.session.sessionId || root.busy)
            return
        root.busy = true
        root.backend.inspectProtocol(root.session.sessionId)
    }

    function navigate(direction) {
        if (!root.workspaceReady || root.busy || root.previewBusy || root.cancelBusy
                || root.applyBusy || !root.session || !root.session.sessionId)
            return
        root.message = ""
        root.busy = true
        if (direction === "back")
            root.backend.navigateProtocolBack(root.session.sessionId)
        else
            root.backend.navigateProtocolForward(root.session.sessionId)
    }

    function reset() {
        root.busy = false
        root.canBack = false
        root.canForward = false
        root.message = ""
    }

    function updateAvailability(snapshot) {
        root.canBack = false
        root.canForward = false
        const checkpoints = snapshot && snapshot.checkpoints ? snapshot.checkpoints : []
        const currentId = snapshot ? snapshot.current_checkpoint_id || "" : ""
        for (let i = 0; i < checkpoints.length; i++) {
            const checkpoint = checkpoints[i]
            if (checkpoint.id !== currentId)
                continue
            root.canBack = (checkpoint.parent_id || "") !== ""
            root.canForward = (checkpoint.children || []).length > 0
            return
        }
    }

    Connections {
        target: root.backend

        function onProtocolSnapshotLoaded(sessionId, snapshot) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.busy = false
            root.updateAvailability(snapshot)
        }

        function onProtocolSnapshotFailed(sessionId, message) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.busy = false
            root.canBack = false
            root.canForward = false
            root.message = message
        }

        function onProtocolNavigationCompleted(sessionId, navigation) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.busy = false
            root.message = "History cursor moved and the preview was reapplied."
            root.navigationCompleted(navigation)
        }

        function onProtocolNavigationFailed(sessionId, message) {
            if (!root.session || !root.session.active || sessionId !== root.session.sessionId)
                return
            root.busy = false
            root.message = message
            root.refresh()
        }
    }
}
