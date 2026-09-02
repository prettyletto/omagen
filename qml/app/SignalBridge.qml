import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property bool glitchEnabled: false
    property string currentStatePath: ""
    property string currentBackgroundLink: ""

    property int shellGlitchEpoch: 0
    property string shellGlitchTrigger: ""
    property double lastShellGlitchAt: 0
    readonly property var notificationService: root.shell
        && typeof root.shell.firstPartyServiceFor === "function"
        ? root.shell.firstPartyServiceFor("omarchy.notifications") : null
    readonly property var notificationPopupModel: root.notificationService
        && "popupModel" in root.notificationService
        ? root.notificationService.popupModel : null
    property bool notificationSignalVisible: false
    property string lastNotificationSignalKey: ""
    property int notificationSignalEpoch: 0
    property string observedBackgroundPath: ""
    property bool backgroundSignalVisible: false
    property int backgroundSignalEpoch: 0

    function triggerShellGlitch(eventName) {
        if (!root.glitchEnabled)
            return
        const now = Date.now()
        // Opening a window also changes focus. Combine that event pair into a
        // single, deliberately slow signal instead of visual noise.
        if (now - root.lastShellGlitchAt < 520)
            return
        root.lastShellGlitchAt = now
        root.shellGlitchTrigger = eventName
        root.shellGlitchEpoch += 1
    }

    function triggerNotificationGlitch() {
        if (root.notificationPopupModel === null)
            return
        // The native service keeps one fullscreen layer mapped while any toast
        // is visible, so a second toast does not emit another layer.opened.
        // This tiny empty-input bridge maps briefly for every inserted row
        // under a fresh namespace epoch; generated Hyprland readers can react
        // to the namespace while other readers ignore the layer.
        if (root.glitchEnabled)
            root.triggerShellGlitch("notification")
        if (root.notificationSignalVisible) {
            root.notificationSignalVisible = false
            notificationSignalReopenTimer.restart()
            return
        }
        root.notificationSignalEpoch += 1
        root.notificationSignalVisible = true
        notificationSignalTimer.restart()
    }

    function resolveCurrentBackground() {
        if (!backgroundResolveProcess.running)
            backgroundResolveProcess.running = true
    }

    function observeCurrentBackground(path) {
        const resolved = String(path || "").trim()
        if (resolved === "")
            return
        // Loading the plugin establishes a baseline. Only a later wallpaper
        // change is an event, so login/reload never creates a false pulse.
        if (root.observedBackgroundPath === "") {
            root.observedBackgroundPath = resolved
            return
        }
        if (resolved === root.observedBackgroundPath)
            return
        root.observedBackgroundPath = resolved
        root.triggerShellGlitch("background")
        if (root.backgroundSignalVisible) {
            root.backgroundSignalVisible = false
            backgroundSignalReopenTimer.restart()
            return
        }
        root.backgroundSignalEpoch += 1
        root.backgroundSignalVisible = true
        backgroundSignalTimer.restart()
    }

    Timer {
        id: notificationSignalTimer
        interval: 120
        repeat: false
        onTriggered: root.notificationSignalVisible = false
    }

    Timer {
        id: notificationSignalReopenTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (root.notificationPopupModel === null)
                return
            root.notificationSignalEpoch += 1
            root.notificationSignalVisible = true
            notificationSignalTimer.restart()
        }
    }

    Timer {
        id: backgroundSignalTimer
        interval: 120
        repeat: false
        onTriggered: root.backgroundSignalVisible = false
    }

    Timer {
        id: backgroundSignalReopenTimer
        interval: 16
        repeat: false
        onTriggered: {
            root.backgroundSignalEpoch += 1
            root.backgroundSignalVisible = true
            backgroundSignalTimer.restart()
        }
    }

    FileView {
        path: root.currentStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: backgroundResolveDebounce.restart()
    }

    Timer {
        id: backgroundResolveDebounce
        interval: 80
        repeat: false
        onTriggered: root.resolveCurrentBackground()
    }

    Process {
        id: backgroundResolveProcess
        command: ["readlink", "-f", root.currentBackgroundLink]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.observeCurrentBackground(text)
        }
    }

    Component.onCompleted: root.resolveCurrentBackground()

    // ListModel's public change signals vary between Quickshell/Qt builds.
    // Polling the newest immutable snapshot keeps this additive bridge stable
    // across those builds and catches a new row while the native layer stays
    // mapped for an earlier toast.
    Timer {
        interval: 80
        repeat: true
        running: root.notificationPopupModel !== null
        onTriggered: {
            const model = root.notificationPopupModel
            const count = model ? Number(model.count || 0) : 0
            const newest = count > 0 ? model.get(0) : null
            const key = newest
                ? String(newest.originalId || "") + ":" + String(newest.timestamp || "")
                : ""
            if (!key) {
                root.lastNotificationSignalKey = ""
            } else if (key !== root.lastNotificationSignalKey) {
                root.lastNotificationSignalKey = key
                root.triggerNotificationGlitch()
            }
        }
    }
}
