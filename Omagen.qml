import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views

Item {
    id: root

    // Injected by Omarchy's single shell host. This lets the additive overlay
    // observe the native notification service without replacing it or opening
    // a competing NotificationServer.
    property var shell: null
    property bool opened: false
    property bool sessionBusy: false
    property bool cancelBusy: false
    property string cancelReturnRoute: "workspace"
    property bool closeAfterCancel: false
    property bool settingsOpen: false
    property string settingsReturnRoute: "setup"
    property bool settingsBusy: false
    property bool runtimeSetupOpen: false
    property bool runtimeSetupBusy: false
    property bool runtimeSetupInstalled: false
    property bool runtimePromptPending: false
    property bool runtimeSetupFirstRun: false
    property string runtimeSetupTheme: ""
    property string runtimeSetupMessage: ""
    property bool generationBusy: false
    property bool describeBusy: false
    property bool regenerationPending: false
    property bool backBusy: false
    property bool previewBusy: false
    property bool pendingColorPreview: false
    property bool applyBusy: false
    property bool applyRecoveryRequired: false
    property bool demoBusy: false
    property bool demoActive: false
    property string demoMode: "none"
    property bool liveCanvasActive: false
    property bool livePanelOpen: false
    property string liveCanvasMonitor: ""
    property bool pendingDemo: false
    property bool pendingWindowDemo: false
    property bool pendingApplyAfterDemo: false
    property bool pendingApplyCapture: false
    property bool pendingApplyPreview: false
    property bool pendingApplyCloseDemo: false
    property bool pendingApplyAbortAfterDemo: false
    property bool pendingApplyUnlock: false
    property bool recoveryBusy: false
    property bool protocolBusy: false
    property bool protocolCanBack: false
    property bool protocolCanForward: false
    property string protocolMessage: ""
    property string route: "unknown"
    property var resumableSession: null
    property string pendingApplyVariant: ""
    property string pendingApplyName: ""
    property string sourceImage: ""
    property string workflowMode: "fast"
    property bool extraConfigsEnabled: false
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null })
    property var animationsStyle: ({ version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false })
    property var lookFeel: ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    property var lookFeelRecipe: null
    property var lookFeelCatalog: []
    property bool lookFeelBusy: false
    property bool lookFeelResolveApplies: true
    property var terminalTranslucency: ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" })
    property string errorMessage: ""
    property int shellGlitchEpoch: 0
    property string shellGlitchTrigger: ""
    property double lastShellGlitchAt: 0
    readonly property var signalAnimationsStyle: session.active
        ? root.animationsStyle
        : (root.resumableSession && root.resumableSession.animations_style
            ? root.normalizeAnimationsStyle(root.resumableSession.animations_style) : null)
    readonly property bool cyberpunkSignalActive: root.signalAnimationsStyle !== null
        && root.signalAnimationsStyle.glitch !== "none"
        && root.signalAnimationsStyle.reducedMotion !== true
    readonly property var notificationService: root.shell
        && typeof root.shell.firstPartyServiceFor === "function"
        ? root.shell.firstPartyServiceFor("omarchy.notifications") : null
    readonly property var notificationPopupModel: root.notificationService
        && "popupModel" in root.notificationService
        ? root.notificationService.popupModel : null
    property bool notificationSignalVisible: false
    property string lastNotificationSignalKey: ""
    property int notificationSignalEpoch: 0
    readonly property string homePath: String(Quickshell.env("HOME") || "")
    readonly property string stateHomePath: {
        const configured = String(Quickshell.env("XDG_STATE_HOME") || "")
        return configured !== "" ? configured : root.homePath + "/.local/state"
    }
    readonly property string currentStatePath: root.stateHomePath + "/omarchy/current"
    readonly property string currentBackgroundLink: root.currentStatePath + "/background"
    property string observedBackgroundPath: ""
    property bool backgroundSignalVisible: false
    property int backgroundSignalEpoch: 0

    readonly property var variants: [
        { variant: "source", label: "Source" },
        { variant: "calm", label: "Calm" },
        { variant: "mute", label: "Mute" },
        { variant: "deep", label: "Deep" },
        { variant: "vibrant", label: "Vibrant" },
        { variant: "balanced", label: "Balanced" }
    ]

    readonly property string backendPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen")
            .toString()
            .replace("file://", "")
    )
    readonly property string imagePickerPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen-file-select")
            .toString()
            .replace("file://", "")
    )

    function triggerShellGlitch(eventName) {
        if (!root.cyberpunkSignalActive)
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
        // under a fresh namespace epoch;
        // the Cyberpunk Hyprland reader recognizes its namespace and owns the
        // desktop pulse. Other generated readers simply ignore the layer.
        if (root.cyberpunkSignalActive)
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

    // Omarchy changes this symlink before telling its native Background
    // plugin to transition. Watching the same state directory as the native
    // bar gives us an event boundary without polling or replacing that owner.
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

    function normalizeShellStyle(value) {
        value = value || ({})
        var preset = value.preset || "default"
        var surface = value.surface || "flat"
        var detail = value.detail || "native"
        var tooltip = value.tooltip || "native"
        var notifications = value.notifications || "native"
        var overrides = {}
        for (var key in (value.overrides || {}))
            overrides[key] = String(value.overrides[key])
        return {
            preset: preset,
            surface: surface,
            detail: detail,
            tooltip: tooltip,
            notifications: notifications,
            overrides: overrides
        }
    }
    function normalizeDesktopStyle(value) {
        value = value || ({})
        var border = value.borderStyle || value.border_style || "solid"
        if (border === "split") border = "split_top"
        var borderSize = Number(value.borderSize !== undefined ? value.borderSize : value.border_size)
        var borderSizeMode = value.borderSizeMode || value.border_size_mode || ""
        if (!isFinite(borderSize)) borderSize = -1
        if (borderSizeMode === "") {
            borderSizeMode = borderSize === 0 ? "default" : borderSize < 0 ? "default" : "fixed"
        }
        if (borderSizeMode === "default") borderSize = -1
        else if (borderSizeMode === "none") borderSize = 0
        else if (borderSizeMode === "fixed") {
            if (borderSize < 1 || borderSize > 24) { borderSize = -1; borderSizeMode = "default" }
        } else { borderSize = -1; borderSizeMode = "default" }
        var borderSpeed = Number(value.borderSpeed !== undefined ? value.borderSpeed : value.border_speed)
        if (!isFinite(borderSpeed) || borderSpeed < 10 || borderSpeed > 100) borderSpeed = 36
        return { borderStyle: border, borderSize: borderSize, borderSizeMode: borderSizeMode, borderSpeed: borderSpeed, shape: value.shape || "native", spacing: value.spacing || "native", depth: value.depth || "native", activeStyle: value.activeStyle || value.active_style || "native", inactiveStyle: value.inactiveStyle || value.inactive_style || "native" }
    }
    function normalizeAnimationsStyle(value) {
        value = value || ({})
        var borderSpeed = Number(value.borderSpeed !== undefined ? value.borderSpeed : value.border_speed)
        if (!isFinite(borderSpeed) || borderSpeed < 10 || borderSpeed > 100) borderSpeed = 36
        var windowAmount = Number(value.windowAmount !== undefined ? value.windowAmount : value.window_amount)
        if (!isFinite(windowAmount) || windowAmount < 60 || windowAmount > 100) windowAmount = 87
        var windowOpacity = Number(value.windowOpacity !== undefined ? value.windowOpacity : value.window_opacity)
        if (!isFinite(windowOpacity) || windowOpacity < 60 || windowOpacity > 100) windowOpacity = 100
        var windowSpeed = Number(value.windowSpeed !== undefined ? value.windowSpeed : value.window_speed)
        if (!isFinite(windowSpeed) || windowSpeed < 1 || windowSpeed > 10) windowSpeed = 4
        var workspaceTravel = Number(value.workspaceTravel !== undefined ? value.workspaceTravel : value.workspace_travel)
        if (!isFinite(workspaceTravel) || workspaceTravel < 5 || workspaceTravel > 100) workspaceTravel = 18
        var glitch = value.glitch || "none"
        if (glitch === "flicker") glitch = "medium"
		var rawEffect = value.screenEffect || value.screen_effect || null
		var screenEffect = rawEffect ? {
			id: rawEffect.id || "none",
			strength: rawEffect.strength || "medium",
			durationMs: Number(rawEffect.durationMs !== undefined ? rawEffect.durationMs : rawEffect.duration_ms || 0),
			triggers: rawEffect.triggers || [],
			coalesce: rawEffect.coalesce !== false
		} : null
        return {
            version: Number(value.version || 1),
            preset: value.preset || "native",
            window: value.window || "native",
            windowOpen: value.windowOpen || value.window_open || "popin",
            windowClose: value.windowClose || value.window_close || "popin",
            windowMove: value.windowMove || value.window_move || "native",
            windowAmount: windowAmount,
            windowOpacity: windowOpacity,
            windowSpeed: windowSpeed,
            workspace: value.workspace || "native",
            workspaceAxis: value.workspaceAxis || value.workspace_axis || "horizontal",
            workspaceTravel: workspaceTravel,
            specialWorkspace: value.specialWorkspace || value.special_workspace || "inherit",
            focus: value.focus || "native",
            layers: value.layers || "native",
            curve: value.curve || "bezier",
            border: value.border || "native",
            borderSpeed: borderSpeed,
            glitch: glitch,
			screenEffect: screenEffect,
            reducedMotion: value.reducedMotion === true || value.reduced_motion === true
        }
    }
    function normalizeBarStyle(value) {
        value = value || ({})
        return { surface: value.surface || "native", density: value.density || "native", attention: value.attention || "semantic", form: value.form || "continuous", visibility: value.visibility || "native", profile: value.profile || null, spec: value.spec || null }
    }
    function normalizeTerminalTranslucency(value) {
        value = value || ({})
        var opacity = Number(value.opacity !== undefined ? value.opacity : 1)
        if (!isFinite(opacity) || opacity < 0.5 || opacity > 1)
            opacity = 1
        return {
            schemaVersion: Number(value.schemaVersion !== undefined ? value.schemaVersion : value.schema_version || 1),
            mode: value.mode || "preserve",
            opacity: opacity,
            cellMode: value.cellMode || value.cell_mode || "background"
        }
    }
    function copyLookFeelDocument(value) {
        value = value || ({})
        return {
            schemaVersion: Number(value.schemaVersion !== undefined ? value.schemaVersion : value.schema_version || 1),
            preset: value.preset || "omarchy-native",
            presetRevision: Number(value.presetRevision !== undefined ? value.presetRevision : value.preset_revision || 1),
            customized: value.customized || ({})
        }
    }
    function normalizedLookFeelRecipe(composition) {
        return {
            window: root.normalizeDesktopStyle(composition.window),
            shell: root.normalizeShellStyle(composition.shell),
            bar: root.normalizeBarStyle(composition.bar),
            animations: root.normalizeAnimationsStyle(composition.animations),
            terminal: root.normalizeTerminalTranslucency(composition.terminal)
        }
    }
    function styleJson(value) {
        return JSON.stringify(value || ({}))
    }
    function refreshLookFeelCustomized() {
        if (!root.lookFeelRecipe)
            return
        var next = root.copyLookFeelDocument(root.lookFeel)
        next.customized = {
            window: root.styleJson(root.desktopStyle) !== root.styleJson(root.lookFeelRecipe.window),
            shell: root.styleJson(root.shellStyle) !== root.styleJson(root.lookFeelRecipe.shell),
            bar: root.styleJson(root.barStyle) !== root.styleJson(root.lookFeelRecipe.bar),
            animations: root.styleJson(root.animationsStyle) !== root.styleJson(root.lookFeelRecipe.animations),
            terminal: root.styleJson(root.terminalTranslucency) !== root.styleJson(root.lookFeelRecipe.terminal)
        }
        root.lookFeel = next
    }
    function applyLookFeelComposition(composition) {
        var previousCustomized = root.lookFeel.customized || ({})
        var resolved = root.normalizedLookFeelRecipe(composition)
        var currentWindow = root.desktopStyle
        var currentShell = root.shellStyle
        var currentBar = root.barStyle
        var currentAnimations = root.animationsStyle
        var currentTerminal = root.terminalTranslucency
        root.lookFeelRecipe = resolved
        root.lookFeel = root.copyLookFeelDocument(composition)
        root.desktopStyle = previousCustomized.window === true ? currentWindow : resolved.window
        root.shellStyle = previousCustomized.shell === true ? currentShell : resolved.shell
        root.barStyle = previousCustomized.bar === true ? currentBar : resolved.bar
        root.animationsStyle = previousCustomized.animations === true ? currentAnimations : resolved.animations
        root.terminalTranslucency = previousCustomized.terminal === true ? currentTerminal : resolved.terminal
        root.refreshLookFeelCustomized()
    }
    function requestLookFeelPreset(preset) {
        if (root.lookFeelBusy || root.previewBusy || root.applyBusy || root.cancelBusy)
            return
        root.lookFeelBusy = true
        root.lookFeelResolveApplies = true
        root.errorMessage = ""
        backend.resolveLookFeel(preset)
    }
    function loadLookFeelRecipe(preset) {
        if (!preset || preset === "omarchy-native") {
            root.lookFeelRecipe = null
            return
        }
        root.lookFeelResolveApplies = false
        backend.resolveLookFeel(preset)
    }
    function resetLookFeelScope(scope) {
        if (!root.lookFeelRecipe || root.lookFeelBusy)
            return
        if (scope === "all") {
            root.desktopStyle = root.lookFeelRecipe.window
            root.shellStyle = root.lookFeelRecipe.shell
            root.barStyle = root.lookFeelRecipe.bar
            root.animationsStyle = root.lookFeelRecipe.animations
            root.terminalTranslucency = root.lookFeelRecipe.terminal
        } else if (scope === "window") {
            root.desktopStyle = root.lookFeelRecipe.window
        } else if (scope === "shell") {
            root.shellStyle = root.lookFeelRecipe.shell
        } else if (scope === "bar") {
            root.barStyle = root.lookFeelRecipe.bar
        } else if (scope === "animations") {
            root.animationsStyle = root.lookFeelRecipe.animations
        } else if (scope === "terminal") {
            root.terminalTranslucency = root.lookFeelRecipe.terminal
        } else {
            return
        }
        root.refreshLookFeelCustomized()
    }

    function open(payload) {
        let action = "open";
        let parsed = ({});
        try {
            if (typeof payload === "string")
                parsed = JSON.parse(payload || "{}");
            else if (payload)
                parsed = payload;
            action = parsed.action || "open";
        } catch (error) {
            action = "open";
        }

        if (action === "quit") {
            quitSession();
            return;
        }

        if (action === "advanced-setup") {
            root.runtimeSetupOpen = true;
            root.runtimeSetupBusy = true;
            root.runtimeSetupMessage = "";
            root.runtimePromptPending = false;
            root.runtimeSetupFirstRun = false;
            root.runtimeSetupTheme = parsed.theme || parsed.theme_name || root.runtimeSetupTheme;
            root.settingsOpen = false;
            root.route = "runtime-setup";
            root.livePanelOpen = false;
            root.opened = true;
            backend.checkRuntime();
            return;
        }

        root.errorMessage = "";
        opened = true;
        if (action === "settings") {
            openSettings();
            return;
        }
        settingsOpen = false;
        if (session.active) {
            // Reopening a hidden overlay must preserve navigation within the
            // active session. In particular, Back may have intentionally
            // invalidated the old generation and returned to configuration.
            if (route !== "setup" && route !== "workspace")
                route = "workspace";
            if (liveCanvasActive) {
                livePanelOpen = true;
                opened = false;
            } else if (session.workspaceReady) {
                liveCanvasActive = true;
                livePanelOpen = true;
                opened = false;
            }
            return;
        }
        root.runtimePromptPending = true;
        root.runtimeSetupFirstRun = true;
        root.runtimeSetupOpen = false;
        route = "loading";
        backend.checkRuntime();
    }

    function close() {
        opened = false;
        settingsOpen = false;
        runtimeSetupOpen = false;
        livePanelOpen = false;
    }

    function closeRuntimeSetup() {
        runtimeSetupOpen = false;
        runtimeSetupBusy = false;
        runtimeSetupMessage = "";
        if (session.active) {
            route = "workspace";
            livePanelOpen = liveCanvasActive;
        } else {
            route = "setup";
            livePanelOpen = false;
        }
        opened = false;
    }

    function dismissRuntimeSetup() {
        const firstRun = runtimeSetupFirstRun;
        closeRuntimeSetup();
        if (firstRun)
            backend.dismissRuntimePrompt();
    }

    function keepNativeRuntimeSetup() {
        if (!runtimeSetupFirstRun) {
            closeRuntimeSetup();
            return;
        }
        runtimeSetupFirstRun = false;
        runtimePromptPending = false;
        runtimeSetupOpen = false;
        runtimeSetupBusy = false;
        runtimeSetupMessage = "";
        route = "setup";
        opened = true;
        backend.dismissRuntimePrompt();
    }

    function reopenLiveCanvasPanel() {
        if (!session.active || !liveCanvasActive)
            return;
        errorMessage = "";
        route = "workspace";
        livePanelOpen = true;
        opened = false;
    }

    function hideLiveCanvasPanel() {
        livePanelOpen = false;
        opened = false;
    }

    function closeSettings() {
        if (settingsBusy)
            return;
        settingsOpen = false;
        route = settingsReturnRoute;
        errorMessage = "";
    }

    function resumePreviousSession() {
        if (!resumableSession || recoveryBusy || resumableSession.workspace_resumable !== true) {
            if (resumableSession && resumableSession.workspace_resumable !== true)
                errorMessage = "The generated workspace is unavailable; restore and close to start again."
            return;
        }
        const canvasActive = resumableSession.canvas_active === true;
        const canvasMode = resumableSession.canvas_mode || "full";
        const resumedVariant = resumableSession.preview_variant || "source";
        session.resume(resumableSession);
        sourceImage = resumableSession.source_image || "";
        shellStyle = normalizeShellStyle(resumableSession.shell_style || resumableSession.desktop_style);
        desktopStyle = normalizeDesktopStyle(resumableSession.desktop_style);
        barStyle = normalizeBarStyle(resumableSession.bar_style);
        animationsStyle = normalizeAnimationsStyle(resumableSession.animations_style);
        var resumedLookFeel = resumableSession.look_feel || ({});
        lookFeel = {
            schemaVersion: Number(resumedLookFeel.schema_version || resumedLookFeel.schemaVersion || 1),
            preset: resumedLookFeel.preset || "omarchy-native",
            presetRevision: Number(resumedLookFeel.preset_revision || resumedLookFeel.presetRevision || 1),
            customized: resumedLookFeel.customized || ({})
        };
        var resumedTerminal = resumableSession.terminal_translucency || ({});
        terminalTranslucency = {
            schemaVersion: Number(resumedTerminal.schema_version || resumedTerminal.schemaVersion || 1),
            mode: resumedTerminal.mode || "preserve",
            opacity: Number(resumedTerminal.opacity !== undefined ? resumedTerminal.opacity : 1),
            cellMode: resumedTerminal.cell_mode || resumedTerminal.cellMode || "background"
        };
        root.loadLookFeelRecipe(lookFeel.preset)
        extraConfigsEnabled = resumableSession.extra_configs === true;
        workflowMode = extraConfigsEnabled ? "in-depth" : "fast";
        liveCanvasMonitor = resumableSession.canvas_monitor || "";
        resumableSession = null;
        route = "workspace";
        // A shell reload destroys this QML object, not the session-owned
        // Demo windows. Rebind to the durable canvas state in place; calling
        // demo open here would classify transiently reloading windows as
        // missing and launch duplicate applications.
        demoActive = canvasActive;
        demoMode = canvasActive ? canvasMode : "none";
        liveCanvasActive = true;
        demoBusy = false;
        livePanelOpen = true;
        opened = false;
    }

    function restorePreviousSession() {
        if (recoveryBusy)
            return;
        recoveryBusy = true;
        errorMessage = "";
        // Release the exclusive layer-shell keyboard focus immediately.
        // Recovery continues in the backend; if it fails, the durable session
        // remains and the next Omagen launch will offer recovery again.
        opened = false;
        backend.recoverSession();
    }

    function openSettings() {
        if (sessionBusy || cancelBusy)
            return;

        errorMessage = "";
        if (!settingsOpen)
            settingsReturnRoute = route === "settings" ? "setup" : route;
        settingsOpen = true;
        route = "settings";
        opened = true;
        settingsBusy = true;
        settings.get();
    }

    // Quit is intentionally different from hiding the overlay: an active
    // session owns a temporary theme and must be cancelled so the backend
    // restores the original theme and removes its durable session state.
    function quitSession() {
        if (cancelBusy || recoveryBusy)
            return;

        // Keep the cleanup intent alive even if session begin is still in
        // flight.  onSessionBegan will immediately hand the new id to the
        // same backend cancel path instead of starting generation.
        if (sessionBusy && !session.active) {
            closeAfterCancel = true;
            settingsOpen = false;
            opened = false;
            return;
        }

        if (session.active && session.sessionId !== "") {
            closeAfterCancel = true;
            settingsOpen = false;
            opened = false;
            cancelSession();
            return;
        }

        if (resumableSession && !recoveryBusy) {
            restorePreviousSession();
            return;
        }

        // The shell can reload after a session was created, leaving the QML
        // object unaware of the durable backend record. Probe the backend so
        // Quit still restores that session; if none exists, the handler below
        // leaves the current UI untouched and this remains a no-op.
        closeAfterCancel = true;
        backend.checkResumeSession();
    }

    function saveSettings(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
        if (settingsBusy)
            return;

        settingsBusy = true;
        errorMessage = "";
        settings.save(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
    }

    function resetSettings() {
        settingsBusy = true;
        settings.reset();
    }

    function chooseImage() {
        if (sessionBusy || cancelBusy)
            return;

        errorMessage = "";
        opened = false;
        imagePicker.choose();
    }

    function beginSession() {
        if (sourceImage === "" || sessionBusy || cancelBusy)
            return;

        // Regenerate inside the existing durable session. The backend commits
        // the new configuration and generation together, so active-session.json
        // remains present and a failed run leaves the previous workspace valid.
        if (session.active) {
            errorMessage = "";
            sessionBusy = true;
            generationBusy = true;
            describeBusy = false;
            regenerationPending = true;
            opened = true;
            route = "workspace";
            backend.generateTheme(session.sessionId, sourceImage, extraConfigsEnabled ? shellStyle : null, extraConfigsEnabled ? desktopStyle : null, extraConfigsEnabled ? barStyle : null, extraConfigsEnabled ? animationsStyle : null, extraConfigsEnabled ? lookFeel : null, extraConfigsEnabled ? terminalTranslucency : null);
            return;
        }

        errorMessage = "";
        sessionBusy = true;
        backend.beginSession(extraConfigsEnabled ? shellStyle : null, desktopStyle, barStyle, animationsStyle, extraConfigsEnabled ? lookFeel : null, extraConfigsEnabled ? terminalTranslucency : null);
    }

    function continueFromSetup() {
        extraConfigsEnabled = workflowMode === "in-depth";
        beginSession();
    }

    function selectVariant(variant) { if (!previewBusy && !cancelBusy && !demoBusy && !applyBusy) session.selectVariant(variant) }

    function focusedMonitorName() {
        const monitor = Hyprland.focusedMonitor
        return monitor ? String(monitor.name || "") : ""
    }

    function enterLiveCanvas(variant) {
        if (!session.workspaceReady || !session.hasPalette(variant) || previewBusy || cancelBusy || demoBusy || applyBusy)
            return;

        session.selectVariant(variant);
        errorMessage = "";

        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;

        // Once Live Canvas is active, changing direction only reapplies the
        // candidate through the existing preview/rollback transaction. It does
        // not create or discard the optional Demo workspace.
        if (demoActive) {
            const overrides = liveCanvasPanel.overridesForVariant(variant);
            pendingColorPreview = Object.keys(overrides).length > 0;
            previewBusy = true;
            backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles(variant));
            return;
        }

        testLive(variant);
    }
    function testLive(variant) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy || applyBusy) return;
        errorMessage = "";
        pendingColorPreview = false;
        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;
        const overrides = liveCanvasPanel.overridesForVariant(variant);
        pendingColorPreview = Object.keys(overrides).length > 0;
        previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles(variant));
    }
    function refreshProtocol() {
        if (!session.active || session.sessionId === "" || protocolBusy)
            return;
        protocolBusy = true;
        backend.inspectProtocol(session.sessionId);
    }
    function updateProtocolAvailability(snapshot) {
        protocolCanBack = false;
        protocolCanForward = false;
        const checkpoints = snapshot && snapshot.checkpoints ? snapshot.checkpoints : [];
        const currentId = snapshot ? snapshot.current_checkpoint_id || "" : "";
        for (let i = 0; i < checkpoints.length; i++) {
            const checkpoint = checkpoints[i];
            if (checkpoint.id !== currentId)
                continue;
            protocolCanBack = (checkpoint.parent_id || "") !== "";
            protocolCanForward = (checkpoint.children || []).length > 0;
            return;
        }
    }
    function navigateProtocol(direction) {
        if (!session.workspaceReady || protocolBusy || previewBusy || cancelBusy || applyBusy || session.sessionId === "")
            return;
        protocolMessage = "";
        protocolBusy = true;
        if (direction === "back")
            backend.navigateProtocolBack(session.sessionId);
        else
            backend.navigateProtocolForward(session.sessionId);
    }
    function applyProtocolState(state) {
        if (!state || !state.variant || !session.hasPalette(state.variant))
            return;
        session.selectVariant(state.variant);
        if (state.style_overrides) {
            root.shellStyle = root.normalizeShellStyle(state.style_overrides.shell || ({}));
            root.desktopStyle = root.normalizeDesktopStyle(state.style_overrides.desktop || ({}));
            root.barStyle = root.normalizeBarStyle(state.style_overrides.bar || ({}));
            root.animationsStyle = root.normalizeAnimationsStyle(state.style_overrides.animations || ({}));
            var protocolLookFeel = state.style_overrides.look_feel || ({});
            root.lookFeel = {
                schemaVersion: Number(protocolLookFeel.schema_version || protocolLookFeel.schemaVersion || 1),
                preset: protocolLookFeel.preset || "omarchy-native",
                presetRevision: Number(protocolLookFeel.preset_revision || protocolLookFeel.presetRevision || 1),
                customized: protocolLookFeel.customized || ({})
            };
            var protocolTerminal = state.style_overrides.terminal || ({});
            root.terminalTranslucency = {
                schemaVersion: Number(protocolTerminal.schema_version || protocolTerminal.schemaVersion || 1),
                mode: protocolTerminal.mode || "preserve",
                opacity: Number(protocolTerminal.opacity !== undefined ? protocolTerminal.opacity : 1),
                cellMode: protocolTerminal.cell_mode || protocolTerminal.cellMode || "background"
            };
        }
        liveCanvasPanel.setStagedColors(state.color_overrides || {}, state.variant);
    }

    function previewStyles(variant) {
        if (!root.extraConfigsEnabled)
            return null;
        return {
            shell: liveCanvasPanel.shellStyleForVariant(variant || session.selectedVariant),
            desktop: root.desktopStyle,
            bar: root.barStyle,
            animations: root.animationsStyle,
            look_feel: root.lookFeel,
            terminal: root.terminalTranslucency
        };
    }

    function previewCurrentState(variant) {
        const overrides = liveCanvasPanel.overridesForVariant(variant);
        root.pendingColorPreview = Object.keys(overrides).length > 0;
        root.previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles(variant));
    }

    function testLiveColors(variant, overrides, nextShellStyle, nextDesktopStyle, nextBarStyle, nextAnimationsStyle) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy || applyBusy)
            return;
        if (nextShellStyle)
            root.shellStyle = root.normalizeShellStyle(nextShellStyle);
        if (nextDesktopStyle)
            root.desktopStyle = root.normalizeDesktopStyle(nextDesktopStyle);
        if (nextBarStyle)
            root.barStyle = root.normalizeBarStyle(nextBarStyle);
        if (nextAnimationsStyle)
            root.animationsStyle = root.normalizeAnimationsStyle(nextAnimationsStyle);
        liveCanvasPanel.setStagedColors(overrides || ({}), variant);
        session.selectVariant(variant);
        errorMessage = "";
        const effectiveOverrides = liveCanvasPanel.overridesForVariant(variant);
        pendingColorPreview = Object.keys(effectiveOverrides).length > 0;
        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;
        previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant, effectiveOverrides, root.previewStyles(variant));
    }
    function suggestedThemeName() {
        let filename = root.sourceImage || ""
        if (filename === "") return "Omagen Theme"
        filename = filename.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").trim()
        if (filename === "") return "Omagen Theme"
        return filename.split(/\s+/).map(function(word) { return word.length ? word.charAt(0).toUpperCase() + word.slice(1) : word }).join(" ")
    }
    function applyTheme(variant, name, generateUnlock, capturePreview) {
        if (!session.workspaceReady || applyBusy || previewBusy || cancelBusy || demoBusy) return
        errorMessage = ""; applyBusy = true; applyRecoveryRequired = false

        // Apply must commit the exact state visible in Live Canvas. Always
        // materialize one final preview first so staged colours and advanced
        // Window/Shell/Bar settings cannot be lost when Test Live was skipped.
        pendingApplyVariant = variant
        pendingApplyName = name
        pendingApplyUnlock = generateUnlock === true
        pendingApplyCapture = capturePreview === true
        pendingApplyPreview = true
        pendingApplyCloseDemo = false

        if (pendingApplyCapture) {
            pendingApplyAfterDemo = true
            demoBusy = true
            opened = false
            if (root.backendDemoActive()) {
                root.previewCurrentState(variant)
            } else {
                if (demoMode === "bar")
                    root.stopBarDemo()
                backend.openDemo(session.sessionId)
            }
            return
        }

        if (root.backendDemoActive()) {
            pendingApplyAfterDemo = true
            pendingApplyCloseDemo = true
            demoBusy = true
            root.previewCurrentState(variant)
            return
        }
        if (demoMode === "bar")
            root.stopBarDemo()
        pendingApplyAfterDemo = false
        root.previewCurrentState(variant)
    }

    function resetPendingApply() {
        pendingApplyAfterDemo = false
        pendingApplyCapture = false
        pendingApplyPreview = false
        pendingApplyCloseDemo = false
        pendingApplyAbortAfterDemo = false
        pendingApplyUnlock = false
        pendingApplyVariant = ""
        pendingApplyName = ""
    }

    function failPendingApply(message) {
        errorMessage = message
        previewBusy = false
        pendingApplyCapture = false
        if (demoActive) {
            pendingApplyAbortAfterDemo = true
            demoBusy = true
            backend.closeDemo(session.sessionId)
        } else {
            resetPendingApply()
            applyBusy = false
            demoBusy = false
            opened = true
        }
    }

    function startDemo(variant) {
        if (demoActive || demoBusy || previewBusy || cancelBusy || applyBusy || !session.workspaceReady)
            return;

        errorMessage = "";
        session.selectVariant(variant);
        liveCanvasActive = true;
        pendingDemo = true;
        demoBusy = true;
        // Omarchy reloads all Ghostty instances as part of applying a theme.
        // Create the scene first, then apply the selected preview; this is the
        // same ordering as opening the four applications manually before
        // switching a theme.
        opened = false;
        backend.openDemo(session.sessionId);
    }

    function startWindowDemo() {
        if (demoBusy || previewBusy || cancelBusy || applyBusy || !session.workspaceReady)
            return;
        if (demoMode === "window" && demoActive) {
            dispatchDemo();
            return;
        }
        if (demoMode === "shell" && demoActive)
            stopShellDemo();
        if (demoMode === "bar" && demoActive)
            stopBarDemo();
        errorMessage = "";
        liveCanvasActive = true;
        livePanelOpen = true;
        pendingWindowDemo = true;
        opened = false;
        if (demoActive) {
            demoBusy = true;
            backend.closeDemo(session.sessionId);
            return;
        }
        pendingWindowDemo = false;
        demoBusy = true;
        backend.openWindowDemo(session.sessionId);
    }

    function startShellDemo() {
        if (demoBusy || previewBusy || cancelBusy || applyBusy || !session.workspaceReady)
            return;
        if (demoMode === "shell" && demoActive) {
            stopShellDemo();
            return;
        }
        if (demoMode === "bar" && demoActive)
            stopBarDemo();
        if (demoActive) {
            errorMessage = "Stop the current desktop demo before starting Shell Demo.";
            return;
        }

        errorMessage = "";
        liveCanvasActive = true;
        livePanelOpen = true;
        liveCanvasMonitor = root.focusedMonitorName();
        opened = false;
        demoActive = true;
        demoMode = "shell";
    }

    function startBarDemo() {
        if (demoBusy || previewBusy || cancelBusy || applyBusy || !session.workspaceReady)
            return;
        if (demoMode === "bar" && demoActive) {
            stopBarDemo();
            return;
        }
        if (demoActive) {
            errorMessage = "Stop the current desktop demo before starting Bar Demo.";
            return;
        }
        errorMessage = "";
        liveCanvasActive = true;
        livePanelOpen = true;
        liveCanvasMonitor = root.focusedMonitorName();
        opened = false;
        demoActive = true;
        demoMode = "bar";
    }

    function stopBarDemo() {
        if (demoMode !== "bar")
            return;
        demoActive = false;
        demoMode = "none";
        livePanelOpen = liveCanvasActive;
    }

    function backendDemoActive() {
        return demoActive && (demoMode === "full" || demoMode === "window");
    }

    function stopShellDemo() {
        if (demoMode !== "shell")
            return;
        demoActive = false;
        demoMode = "none";
        livePanelOpen = liveCanvasActive;
    }

    function dispatchDemo() {
        if (!demoActive || demoBusy || cancelBusy)
            return;

        if (demoMode === "shell") {
            stopShellDemo();
            return;
        }
        if (demoMode === "bar") {
            stopBarDemo();
            return;
        }

        if (session.sessionId === "")
            return;

        errorMessage = "";
        demoBusy = true;
        backend.closeDemo(session.sessionId);
    }

    function cancelSession() {
        if (!session.active || session.sessionId === "" || cancelBusy)
            return;

        errorMessage = "";
        cancelBusy = true;
        cancelReturnRoute = route;
        demoBusy = false;
        pendingDemo = false;
        pendingApplyAfterDemo = false;
        pendingApplyCapture = false;
        pendingApplyPreview = false;
        pendingApplyCloseDemo = false;
        pendingApplyAbortAfterDemo = false;
        pendingApplyUnlock = false;
        livePanelOpen = false;
        liveCanvasMonitor = "";
        liveCanvasActive = false;
        // The backend cancel command closes any demo, recovers an interrupted
        // Apply, restores the original theme/background, and removes the
        // session. It is deliberately the single cleanup path for explicit
        // Cancel, independent of which frontend operation was in flight.
        backend.cancelSession(session.sessionId);
    }

    // A generated workspace is bound to a durable backend session. Returning
    // to configuration keeps the original rollback boundary but invalidates
    // the current directions. Continuing generates a fresh workspace inside
    // this same session instead of treating the old generation as current.
    function returnToConfiguration() {
        if (!session.active || session.sessionId === "" || session.generationId === "" || sessionBusy || generationBusy || describeBusy || backBusy || cancelBusy || previewBusy || applyBusy)
            return;

        errorMessage = "";
        backBusy = true;
        backend.discardGeneration(session.sessionId, session.generationId);
    }

    function clearSession(closeWhenDone) {
        const shouldClose = closeWhenDone === true || closeAfterCancel;
        liveCanvasPanel.resetApplyDialog();
        liveCanvasPanel.clearColorSession();
        session.clear();
        sessionBusy = false;
        cancelBusy = false;
        closeAfterCancel = false;
        sourceImage = "";
        workflowMode = "fast";
        extraConfigsEnabled = false;
        lookFeelRecipe = null;
        lookFeelResolveApplies = true;
        lookFeel = ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) });
        terminalTranslucency = ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" });
        shellStyle = ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) });
        desktopStyle = ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" });
        barStyle = ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null });
        animationsStyle = root.normalizeAnimationsStyle({ preset: "native" });
        errorMessage = "";
        opened = !shouldClose;
        generationBusy = false;
        describeBusy = false;
        regenerationPending = false;
        backBusy = false;
        previewBusy = false;
        pendingColorPreview = false;
        demoBusy = false;
        demoActive = false;
        demoMode = "none";
        liveCanvasActive = false;
        livePanelOpen = false;
        liveCanvasMonitor = "";
        pendingDemo = false;
        pendingWindowDemo = false;
        pendingApplyAfterDemo = false;
        pendingApplyCapture = false;
        pendingApplyAbortAfterDemo = false;
        pendingApplyUnlock = false;
        pendingApplyVariant = "";
        pendingApplyName = "";
        applyBusy = false;
        applyRecoveryRequired = false;
        route = "setup";
        cancelReturnRoute = "workspace";
        resumableSession = null;
        recoveryBusy = false;
        protocolBusy = false;
        protocolCanBack = false;
        protocolCanForward = false;
        protocolMessage = "";
    }

    onOpenedChanged: if (opened && route === "workspace") Qt.callLater(root.refreshProtocol)
    onRouteChanged: if (opened && route === "workspace") Qt.callLater(root.refreshProtocol)

    State.SessionState {
        id: session
    }

    Services.ImagePickerService {
        id: imagePicker
        executable: root.imagePickerPath

        onSelected: function(path) {
            root.sourceImage = path;
            root.opened = true;
        }

        onCancelled: {
            root.opened = true;
        }

        onFailed: function(message) {
            root.errorMessage = message;
            root.opened = true;
        }
    }

    Services.BackendService {
        id: backend
        executable: root.backendPath

        onSessionBegan: function(
            sessionId,
            originalTheme,
            backgroundKind,
            backgroundPath,
            backendShellStyle,
            backendExtraConfigs,
            backendDesktopStyle,
            backendBarStyle,
            backendAnimationsStyle,
            backendLookFeel,
            backendTerminalTranslucency
        ) {
            root.sessionBusy = false;
            session.activate(
                sessionId
            );
            root.shellStyle = root.normalizeShellStyle(backendShellStyle);
            root.desktopStyle = root.normalizeDesktopStyle(backendDesktopStyle);
            root.barStyle = root.normalizeBarStyle(backendBarStyle);
            root.animationsStyle = root.normalizeAnimationsStyle(backendAnimationsStyle);
            root.lookFeel = {
                schemaVersion: Number(backendLookFeel.schema_version || backendLookFeel.schemaVersion || 1),
                preset: backendLookFeel.preset || "omarchy-native",
                presetRevision: Number(backendLookFeel.preset_revision || backendLookFeel.presetRevision || 1),
                customized: backendLookFeel.customized || ({})
            };
            root.terminalTranslucency = {
                schemaVersion: Number(backendTerminalTranslucency.schema_version || backendTerminalTranslucency.schemaVersion || 1),
                mode: backendTerminalTranslucency.mode || "preserve",
                opacity: Number(backendTerminalTranslucency.opacity !== undefined ? backendTerminalTranslucency.opacity : 1),
                cellMode: backendTerminalTranslucency.cell_mode || backendTerminalTranslucency.cellMode || "background"
            };
            root.extraConfigsEnabled = backendExtraConfigs;
            root.workflowMode = backendExtraConfigs ? "in-depth" : "fast";
            if (root.closeAfterCancel) {
                root.cancelSession();
                return;
            }
            root.route = "workspace";
            root.liveCanvasActive = true;
            root.livePanelOpen = true;
            root.opened = false;
            root.generationBusy = true;
            backend.generateTheme(sessionId, root.sourceImage, null, null, null, null, null, null);
        }

        onSessionBeginFailed: function(message) {
            root.sessionBusy = false;
            if (message.indexOf("already active") !== -1 || message.indexOf("active session") !== -1) {
                root.route = "loading";
                backend.checkResumeSession();
                return;
            }
            if (root.closeAfterCancel) {
                // Quit may arrive while begin is still in flight. There is
                // no session to cancel in this case, but the setup state
                // (including the selected image) must still be discarded.
                root.clearSession();
                return;
            }
            root.closeAfterCancel = false;
            root.errorMessage = message;
        }

        onBackendReady: {
            backend.listLookFeel()
            backend.checkResumeSession()
        }
        onBackendUnavailable: function(message) {
            root.resumableSession = null;
            root.route = "setup";
            root.errorMessage = "Omagen could not start its backend: " + message;
        }
        onLookFeelCatalogLoaded: function(catalog) {
            root.lookFeelCatalog = catalog
        }
        onLookFeelCatalogFailed: function(message) {
            root.lookFeelCatalog = []
            if (root.extraConfigsEnabled)
                root.errorMessage = message
        }
        onLookFeelResolved: function(composition) {
            root.lookFeelBusy = false
            if (root.lookFeelResolveApplies) {
                root.applyLookFeelComposition(composition)
            } else {
                root.lookFeelRecipe = root.normalizedLookFeelRecipe(composition)
                root.refreshLookFeelCustomized()
            }
        }
        onLookFeelResolveFailed: function(message) {
            root.lookFeelBusy = false
            root.errorMessage = message
        }

        onRuntimeStatusLoaded: function(status) {
            root.runtimeSetupBusy = false;
            root.runtimeSetupInstalled = status && status.installed === true;
            if (root.runtimePromptPending) {
                root.runtimePromptPending = false;
                if (status && status.prompt_required === true) {
                    root.runtimeSetupOpen = true;
                    root.runtimeSetupFirstRun = true;
                    root.route = "runtime-setup";
                    root.opened = true;
                    return;
                }
                root.runtimeSetupFirstRun = false;
                root.runtimeSetupOpen = false;
                root.route = "loading";
                backend.checkBackend();
                return;
            }
            if (root.runtimeSetupInstalled)
                root.runtimeSetupMessage = "";
        }
        onRuntimeStatusFailed: function(message) {
            if (root.runtimePromptPending) {
                root.runtimePromptPending = false;
                root.runtimeSetupFirstRun = false;
                root.runtimeSetupOpen = false;
                root.route = "loading";
                backend.checkBackend();
                return;
            }
            root.runtimeSetupBusy = false;
            root.runtimeSetupMessage = message;
        }
        onRuntimeInstalled: function(hookPath) {
            root.runtimeSetupBusy = false;
            root.runtimeSetupInstalled = true;
            root.runtimePromptPending = false;
            root.runtimeSetupFirstRun = false;
            root.runtimeSetupMessage = "Advanced runtime enabled. Reapply the advanced theme to activate the complete runtime path.";
        }
        onRuntimeInstallFailed: function(message) {
            root.runtimeSetupBusy = false;
            root.runtimeSetupMessage = message;
        }
        onRuntimePromptDismissFailed: function(message) {
            root.runtimeSetupMessage = message;
        }

        onSessionResumeChecked: function(result) {
            if (!result || result.active !== true) {
                root.resumableSession = null;
                if (root.closeAfterCancel) {
                    // A selected image is part of the temporary workspace,
                    // even when generation never started. Quit must return
                    // all the way to the initial setup state.
                    root.clearSession();
                    return;
                }
                root.route = "setup";
                return;
            }
            root.resumableSession = result;
            if (root.closeAfterCancel) {
                root.restorePreviousSession();
                return;
            }
            root.route = "recovery";
        }
        onSessionResumeCheckFailed: function(message) {
            root.resumableSession = null;
            if (root.closeAfterCancel) {
                root.closeAfterCancel = false;
                root.errorMessage = message;
                return;
            }
            root.route = "setup";
            root.errorMessage = message;
        }
        onSessionRecovered: {
            // Recovery is a terminal session transition. Clear the complete
            // frontend state as well as the durable backend record; leaving
            // demoActive or the generation behind would recreate the canvas
            // handle after the original desktop has already been restored.
            root.clearSession(true);
        }
        onSessionRecoverFailed: function(message) {
            root.recoveryBusy = false;
            root.errorMessage = message;
            root.route = "recovery";
            root.opened = true;
        }

        onSessionCancelled: function(sessionId) {
            root.cancelBusy = false;
            if (sessionId !== session.sessionId) {
                root.errorMessage = "Backend cancelled a different session";
                return;
            }
            root.clearSession();
        }

        onSessionCancelFailed: function(message) {
            root.cancelBusy = false;
            root.closeAfterCancel = false;
            root.errorMessage = message;
            root.opened = true;
            root.route = root.cancelReturnRoute;
        }

        onGenerationCompleted: function(sessionId, generationId) {
            if (root.closeAfterCancel || root.cancelBusy || !session.active || sessionId !== session.sessionId)
                return;
            root.generationBusy = false;
            root.describeBusy = true;
            backend.describeGeneration(session.sessionId, generationId);
        }
        onGenerationFailed: function(sessionId, message) {
            if (root.cancelBusy || !session.active || sessionId !== session.sessionId)
                return;
            root.generationBusy=false;
            root.sessionBusy=false;
            if (root.regenerationPending) {
                root.regenerationPending=false;
                root.liveCanvasActive = true;
                root.livePanelOpen = true;
                root.opened = false;
                root.route="workspace";
            }
            root.errorMessage=message;
        }
        onGenerationDescribed: function(sessionId, generationId, variants) {
            if (root.closeAfterCancel || root.cancelBusy || !session.active || sessionId !== session.sessionId)
                return;
            root.describeBusy=false;
            root.sessionBusy=false;
            root.regenerationPending=false;
            session.setGeneration(generationId, variants);
            root.liveCanvasActive = true;
            root.livePanelOpen = true;
            root.opened = false;
            root.route = "workspace";
            // Continue is the first user action in the session. Make that
            // action land in the real desktop with Source already applied;
            // the user should not need a second click just to enter the
            // default direction.
            root.enterLiveCanvas("source");
            root.refreshProtocol();
        }
        onGenerationDescribeFailed: function(sessionId, message) {
            if (root.cancelBusy || !session.active || sessionId !== session.sessionId)
                return;
            root.describeBusy=false;
            root.sessionBusy=false;
            if (root.regenerationPending) {
                root.regenerationPending=false;
                root.liveCanvasActive = true;
                root.livePanelOpen = true;
                root.opened = false;
                root.route="workspace";
            }
            root.errorMessage=message;
        }
        onGenerationDiscarded: function(sessionId, generationId) {
            if (!session.active || sessionId !== session.sessionId || generationId !== session.generationId)
                return;
            root.backBusy = false;
            root.regenerationPending = false;
            root.liveCanvasActive = false;
            root.demoActive = false;
            root.demoMode = "none";
            root.livePanelOpen = false;
            liveCanvasPanel.clearColorSession();
            session.clearGeneration();
            root.liveCanvasActive = true;
            root.livePanelOpen = true;
            root.opened = false;
            root.route = "workspace";
        }
        onGenerationDiscardFailed: function(sessionId, message) {
            if (!session.active || sessionId !== session.sessionId)
                return;
            root.backBusy = false;
            root.errorMessage = message;
            root.opened = true;
            root.route = "workspace";
        }
        onPreviewApplied: function(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return;
            root.previewBusy = false;
            if (sessionId!==session.sessionId || generationId!==session.generationId) { root.errorMessage="Backend previewed a different generation"; return }
            if (root.pendingColorPreview) {
                root.pendingColorPreview = false;
                liveCanvasPanel.markColorsLive();
            }
            session.markPreviewed(variant);
            root.refreshProtocol();

            if (root.pendingApplyPreview) {
                root.pendingApplyPreview = false;
                if (root.pendingApplyCapture) {
                    root.demoBusy = true;
                    backend.captureDemoPreview(session.sessionId);
                    return;
                }
                if (root.pendingApplyCloseDemo) {
                    root.pendingApplyCloseDemo = false;
                    root.demoBusy = true;
                    backend.closeDemo(session.sessionId);
                    return;
                }
                root.opened = true;
                backend.applyTheme(
                    session.sessionId,
                    session.generationId,
                    root.pendingApplyVariant,
                    root.pendingApplyName,
                    root.pendingApplyUnlock,
                    false
                );
                return;
            }

            if (root.pendingApplyCapture) {
                root.demoBusy = true;
                backend.captureDemoPreview(session.sessionId);
                return;
            }

            // Shell and Bar Demos are QML-only reader surfaces. They do not own
            // a backend workspace or demo-state.json, so previewing them must
            // not enter the window/full-demo reflow path.
            if (root.backendDemoActive()) {
                // Reassert workspace ownership after the candidate reload. The
                // Demo itself remains in Hyprland's dwindle layout; only the
                // Studio panel is an overlay and must never become a tiled pane.
                root.demoBusy = true;
                backend.reflowDemo(session.sessionId);
                return;
            }

            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.demoBusy = false;
                root.livePanelOpen = true;
                root.opened = false;
                return;
            }

            if (root.liveCanvasActive) {
                root.livePanelOpen = true;
                root.opened = false;
            } else {
                root.opened = false;
                root.livePanelOpen = false;
            }
        }
        onPreviewApplyFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.previewBusy = false;
            root.pendingColorPreview = false;
            if (root.pendingApplyPreview || root.pendingApplyCapture || root.pendingApplyCloseDemo) {
                root.failPendingApply(message)
                return
            }
            root.errorMessage = message;
            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.demoBusy = false;
            }
        }
        onDemoOpened: function(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return;
            if (sessionId !== session.sessionId) {
                root.demoBusy = false;
                root.errorMessage = "Backend opened a different demo session";
                root.opened = true;
                return;
            }
            root.demoActive = true;
            root.demoMode = "full";
            root.liveCanvasMonitor = monitor;
            if (root.pendingApplyCapture) {
                root.previewCurrentState(root.pendingApplyVariant);
                return;
            }
            if (root.pendingDemo) {
                root.previewCurrentState(session.selectedVariant);
                return;
            }
            root.demoBusy = false;
            root.opened = false;
            root.livePanelOpen = root.liveCanvasActive;
        }
        onDemoOpenFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.demoBusy = false;
            root.demoActive = false;
            root.demoMode = "none";
            root.livePanelOpen = root.liveCanvasActive;
            root.liveCanvasMonitor = "";
            root.pendingDemo = false;
            if (root.pendingApplyAfterDemo || root.pendingApplyCapture) {
                root.resetPendingApply()
                root.applyBusy = false
            }
            root.errorMessage = message;
            root.opened = root.liveCanvasActive ? false : true;
        }
        onWindowDemoOpened: function(sessionId, workspace, monitor, reused) {
            if (root.closeAfterCancel)
                return;
            if (sessionId !== session.sessionId) {
                root.demoBusy = false;
                root.pendingWindowDemo = false;
                root.errorMessage = "Backend opened a different Window demo session";
                root.opened = true;
                return;
            }
            root.pendingWindowDemo = false;
            root.demoActive = true;
            root.demoMode = "window";
            root.liveCanvasMonitor = monitor;
            root.demoBusy = false;
            root.opened = false;
            root.livePanelOpen = root.liveCanvasActive;
        }
        onWindowDemoOpenFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.demoBusy = false;
            root.pendingWindowDemo = false;
            root.demoActive = false;
            root.demoMode = "none";
            root.livePanelOpen = root.liveCanvasActive;
            root.liveCanvasMonitor = "";
            root.errorMessage = message;
            root.opened = root.liveCanvasActive ? false : true;
        }
        onDemoReflowed: function(sessionId) {
            if (root.closeAfterCancel)
                return;
            if (sessionId !== session.sessionId) {
                root.demoBusy = false;
                root.errorMessage = "Backend reflowed a different live canvas session";
                return;
            }
            root.demoBusy = false;
            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.livePanelOpen = true;
                root.opened = false;
                return;
            }
            // Reapplication from the side panel keeps the panel available for
            // the next direction instead of forcing a trip back through the
            // bar widget.
            root.livePanelOpen = true;
            root.opened = false;
        }
        onDemoReflowFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.demoBusy = false;
            // Demo cleanup removes demo-state.json after its windows and
            // workspace are gone. A queued reflow can arrive just after that
            // cleanup and otherwise exposes an internal transient path to the
            // user. Treat the missing state as an already-closed Demo.
            if (message.indexOf("demo-state.json") !== -1 && message.indexOf("no such file") !== -1) {
                root.demoActive = false;
                root.demoMode = "none";
                root.liveCanvasMonitor = "";
                root.pendingDemo = false;
                root.errorMessage = "";
                root.livePanelOpen = root.liveCanvasActive;
                return;
            }
            root.errorMessage = message;
            root.pendingDemo = false;
            root.livePanelOpen = root.liveCanvasActive;
            root.opened = root.liveCanvasActive ? false : true;
        }
        onDemoCaptured: function(sessionId, previewPath) {
            if (root.closeAfterCancel)
                return;
            if (sessionId !== session.sessionId) {
                root.failPendingApply("Backend captured a different Demo session")
                return;
            }
            if (!root.pendingApplyCapture)
                return;
            root.demoBusy = true;
            backend.closeDemo(session.sessionId);
        }
        onDemoCaptureFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            if (root.pendingApplyCapture) {
                root.failPendingApply(message)
                return
            }
            root.demoBusy = false;
            root.errorMessage = message;
            root.opened = true;
        }
        onDemoClosed: function(sessionId, closed) {
            root.demoBusy = false;
            if (sessionId !== session.sessionId) {
                root.errorMessage = "Backend closed a different demo session";
                return;
            }
            root.demoActive = false;
            root.demoMode = "none";
            root.livePanelOpen = root.liveCanvasActive;
            if (root.pendingApplyAbortAfterDemo) {
                root.resetPendingApply()
                root.applyBusy = false
                root.opened = true
                return
            }
            if (root.pendingWindowDemo) {
                root.pendingWindowDemo = false;
                root.demoBusy = true;
                backend.openWindowDemo(session.sessionId);
                return;
            }
            if (root.pendingApplyAfterDemo) {
                const variant = root.pendingApplyVariant;
                const name = root.pendingApplyName;
                const generateUnlock = root.pendingApplyUnlock;
                const capturePreview = root.pendingApplyCapture;
                root.resetPendingApply();
                // Demo capture must hide Omagen while the screenshot is taken,
                // but the permanent Go/theme-set phase belongs behind the
                // applying modal until the backend process fully completes.
                root.opened = true;
                backend.applyTheme(
                    session.sessionId,
                    session.generationId,
                    variant,
                    name,
                    generateUnlock,
                    capturePreview
                );
                return;
            }
            root.opened = root.liveCanvasActive ? false : true;
        }
        onDemoCloseFailed: function(message) {
            root.demoBusy = false;
            root.errorMessage = message;
            if (root.pendingApplyAfterDemo || root.pendingApplyAbortAfterDemo || root.pendingWindowDemo) {
                // A failed Demo close must abort this Apply attempt. Keeping
                // applyBusy/pendingApplyAfterDemo set would leave the UI
                // waiting forever for a demoClosed signal that will not come.
                root.resetPendingApply();
                root.applyBusy = false;
                root.pendingWindowDemo = false;
                root.opened = true;
            }
        }
        onThemeApplied: function(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return;
            applyBusy = false
            if (sessionId !== session.sessionId || generationId !== session.generationId) { errorMessage = "Backend applied a different generation"; return }
            root.clearSession(true)
        }
        onThemeApplyFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            applyBusy = false;
            applyRecoveryRequired = true;
            errorMessage = message;
            root.opened = true;
        }

        onProtocolSnapshotLoaded: function(sessionId, snapshot) {
            if (!session.active || sessionId !== session.sessionId)
                return;
            root.protocolBusy = false;
            root.updateProtocolAvailability(snapshot);
        }
        onProtocolSnapshotFailed: function(sessionId, message) {
            if (!session.active || sessionId !== session.sessionId)
                return;
            root.protocolBusy = false;
            root.protocolCanBack = false;
            root.protocolCanForward = false;
            root.protocolMessage = message;
        }
        onProtocolNavigationCompleted: function(sessionId, navigation) {
            if (!session.active || sessionId !== session.sessionId)
                return;
            root.applyProtocolState(navigation.state);
            root.protocolMessage = "History cursor moved and the preview was reapplied.";
            root.protocolBusy = false;
            root.refreshProtocol();
        }
        onProtocolNavigationFailed: function(sessionId, message) {
            if (!session.active || sessionId !== session.sessionId)
                return;
            root.protocolBusy = false;
            root.protocolMessage = message;
            root.refreshProtocol();
        }
    }

    State.SettingsState {
        id: settingsState
    }

    Services.SettingsService {
        id: settings
        executable: root.backendPath

        onLoaded: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
            settingsWindow.loadValues(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
        }

        onLoadFailed: function(message) {
            settingsBusy = false;
            errorMessage = message;
        }

        onSaved: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
            closeSettings();
            errorMessage = "";
        }

        onSaveFailed: function(message) {
            settingsBusy = false;
            errorMessage = message;
        }

        onResetCompleted: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
            settingsWindow.loadValues(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
            errorMessage = "";
        }

        onResetFailed: function(message) {
            settingsBusy = false;
            errorMessage = message;
        }
    }

    Views.SetupWindow {
        active: root.opened && root.route === "setup"
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        busy: root.sessionBusy
        sessionActive: session.active
        cancelBusy: root.cancelBusy
        sourceImage: root.sourceImage
        errorMessage: root.errorMessage

        onChooseImageRequested: root.chooseImage()
        workflowMode: root.workflowMode
        onWorkflowModeSelected: function(mode) {
            root.workflowMode = mode;
            root.extraConfigsEnabled = mode === "in-depth";
        }
        onContinueRequested: root.continueFromSetup()
        onCancelRequested: root.cancelSession()
        onHideRequested: root.close()
    }

    Views.AdvancedRuntimeSetupWindow {
        active: root.runtimeSetupOpen
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        busy: root.runtimeSetupBusy
        installed: root.runtimeSetupInstalled
        themeName: root.runtimeSetupTheme
        message: root.runtimeSetupMessage

        onInstallRequested: {
            root.runtimeSetupBusy = true;
            root.runtimeSetupMessage = "";
            backend.installRuntime();
        }
        onKeepNativeRequested: {
            root.keepNativeRuntimeSetup();
        }
        onHideRequested: {
            root.dismissRuntimeSetup();
        }
    }

    // Quickshell reports compositor events without taking ownership of them.
    // These raw window/workspace events drive only Omagen's contained QML
    // signal. Native shell layer events are handled by the generated Hyprland
    // hook, which owns the whole-desktop event shader.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = String(event.name || "")
            if (name === "openwindow" || name === "activewindow" || name === "activewindowv2"
                    || name === "workspace" || name === "workspacev2")
                root.triggerShellGlitch(name)
        }
    }

    // Empty-input layer bridge for notification arrivals. Native Omarchy owns
    // the visible notification surface; this surface exists only long enough
    // to give Hyprland a layer.opened signal for each new toast.
    Variants {
        model: root.notificationSignalVisible && root.notificationPopupModel !== null
            ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.notificationSignalVisible && root.notificationPopupModel !== null
            color: "transparent"
            implicitWidth: 1
            implicitHeight: 1
            anchors { top: true; left: true }
            WlrLayershell.namespace: "omagen-notification-signal-" + root.notificationSignalEpoch
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
        }
    }

    // Empty-input layer bridge for a real background transition. It is safe
    // to emit for every theme: only generated effects that subscribe to this
    // namespace react, while Omarchy remains the wallpaper owner.
    Variants {
        model: root.backgroundSignalVisible ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.backgroundSignalVisible
            color: "transparent"
            implicitWidth: 1
            implicitHeight: 1
            anchors { top: true; left: true }
            WlrLayershell.namespace: "omagen-background-signal-" + root.backgroundSignalEpoch
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
        }
    }

        Views.RecoveryWindow {
            active: root.opened && root.route === "recovery"
            glitchEnabled: root.cyberpunkSignalActive
            glitchEpoch: root.shellGlitchEpoch
            busy: root.recoveryBusy
            generationId: root.resumableSession ? root.resumableSession.generation_id || "" : ""
            previewVariant: root.resumableSession ? root.resumableSession.preview_variant || "" : ""
            workspaceResumable: root.resumableSession ? root.resumableSession.workspace_resumable === true : false
        onResumeRequested: root.resumePreviousSession()
        onRestoreRequested: root.restorePreviousSession()
        onCloseRequested: { root.recoveryBusy = false; root.opened = false }
    }

    Views.LiveCanvasPanel {
        id: liveCanvasPanel
        active: root.route === "workspace" && session.active && root.liveCanvasActive && root.livePanelOpen
        previewBusy: root.previewBusy
        demoBusy: root.demoBusy
        demoActive: root.demoActive
        demoMode: root.demoMode
        cancelBusy: root.cancelBusy
        applyBusy: root.applyBusy
        generationBusy: root.generationBusy || root.describeBusy
        workspaceReady: session.workspaceReady
        extraConfigsEnabled: root.extraConfigsEnabled
        lookFeel: root.lookFeel
        lookFeelRecipe: root.lookFeelRecipe
        lookFeelCatalog: root.lookFeelCatalog
        lookFeelBusy: root.lookFeelBusy
        terminalTranslucency: root.terminalTranslucency
        terminalPresetOpacity: root.lookFeelRecipe && root.lookFeelRecipe.terminal
            ? Number(root.lookFeelRecipe.terminal.opacity || 0.82) : 0.82
        shellStyle: root.shellStyle
        desktopStyle: root.desktopStyle
        barStyle: root.barStyle
        animationsStyle: root.animationsStyle
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        protocolCanBack: root.protocolCanBack
        protocolCanForward: root.protocolCanForward
        protocolBusy: root.protocolBusy
        protocolMessage: root.protocolMessage
        errorMessage: root.errorMessage
        selectedVariant: session.selectedVariant
        monitorName: root.liveCanvasMonitor
        suggestedThemeName: root.suggestedThemeName()
        variants: root.variants
        palettes: session.palettes

        onHideRequested: root.hideLiveCanvasPanel()
        onCloseCanvasRequested: root.dispatchDemo()
        onStartDemoRequested: root.startDemo(session.selectedVariant)
        onWindowDemoRequested: root.startWindowDemo()
        onWindowDemoStopRequested: root.dispatchDemo()
        onShellDemoRequested: root.startShellDemo()
        onShellDemoStopRequested: root.stopShellDemo()
        onBarDemoRequested: root.startBarDemo()
        onBarDemoStopRequested: root.stopBarDemo()
        onCancelRequested: root.cancelSession()
        onVariantRequested: function(variant) { root.enterLiveCanvas(variant) }
        onColorTestLiveRequested: function(variant, overrides, shellStyle, desktopStyle, barStyle, animationsStyle) { root.testLiveColors(variant, overrides, shellStyle, desktopStyle, barStyle, animationsStyle) }
        onAdvancedStylesChanged: function(shellStyle, desktopStyle, barStyle, animationsStyle) {
            root.shellStyle = root.normalizeShellStyle(shellStyle)
            root.desktopStyle = root.normalizeDesktopStyle(desktopStyle)
            root.barStyle = root.normalizeBarStyle(barStyle)
            root.animationsStyle = root.normalizeAnimationsStyle(animationsStyle)
            root.refreshLookFeelCustomized()
        }
        onLookFeelPresetRequested: root.requestLookFeelPreset(preset)
        onLookFeelResetRequested: root.resetLookFeelScope(scope)
        onTerminalIntentChanged: function(terminal) {
            root.terminalTranslucency = root.normalizeTerminalTranslucency(terminal)
            root.refreshLookFeelCustomized()
        }
        onProtocolBackRequested: root.navigateProtocol("back")
        onProtocolForwardRequested: root.navigateProtocol("forward")
        onApplyRequested: function(variant, name, generateUnlock, capturePreview) {
            root.applyTheme(variant, name, generateUnlock, capturePreview)
        }
    }

    Views.ShellDemoPanel {
        id: shellDemoPanel
        active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "shell"
        monitorName: root.liveCanvasMonitor
        shellStyle: root.shellStyle
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
    }

    Views.BarDemoPanel {
        id: barDemoPanel
        active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "bar"
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        monitorName: root.liveCanvasMonitor
        barStyle: root.barStyle
        onCloseRequested: root.stopBarDemo()
    }

    Views.LiveCanvasHandle {
        active: session.active && root.liveCanvasActive && !root.opened && !root.livePanelOpen
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        monitorName: root.liveCanvasMonitor
        onReopenRequested: root.reopenLiveCanvasPanel()
    }

    Views.SettingsWindow {
        id: settingsWindow
        active: root.opened && root.route === "settings" && root.settingsOpen
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        busy: root.settingsBusy
        errorMessage: root.errorMessage

        onSaveRequested: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
            root.saveSettings(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
        }
        onResetRequested: root.resetSettings()
        onCloseRequested: {
            root.closeSettings();
        }
    }
}
