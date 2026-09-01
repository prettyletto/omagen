import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views
import "qml/app" as App
import "qml/controllers" as Controllers
import "qml/app/StyleDocuments.js" as StyleDocuments

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
    property alias runtimeSetupOpen: runtimeSetupController.open
    property alias runtimeSetupBusy: runtimeSetupController.busy
    property alias runtimeSetupInstalled: runtimeSetupController.installed
    property alias runtimePromptPending: runtimeSetupController.promptPending
    property alias runtimeSetupFirstRun: runtimeSetupController.firstRun
    property alias runtimeSetupTheme: runtimeSetupController.theme
    property alias runtimeSetupMessage: runtimeSetupController.message
    property alias generationBusy: generationController.generating
    property alias describeBusy: generationController.describing
    property alias regenerationPending: generationController.regenerationPending
    property alias backBusy: generationController.returning
    property alias previewBusy: previewController.busy
    property alias pendingColorPreview: previewController.pendingColorPreview
    property alias applyBusy: applyController.busy
    property alias applyRecoveryRequired: applyController.recoveryRequired
    property alias demoBusy: demoController.busy
    property alias demoActive: demoController.active
    property alias demoMode: demoController.mode
    property bool liveCanvasActive: false
    property bool livePanelOpen: false
    property bool applyCapturePanelHidden: false
    readonly property bool liveCanvasPanelSuppressed: root.applyCapturePanelHidden
    property bool themePickerOpen: false
    property alias liveCanvasMonitor: demoController.monitor
    property alias pendingDemo: demoController.pendingDemo
    property alias pendingWindowDemo: demoController.pendingWindowDemo
    property bool recoveryBusy: false
    property string route: "unknown"
    // Keep the bar widget and summon lifecycle resident, but defer the
    // heavyweight Studio canvas until a workspace is actually requested.
    // Durable session state and controllers survive Loader teardown/reload.
    readonly property var liveCanvasPanel: liveCanvasLoader.item
    property var deferredCanvasAction: null
    property var resumableSession: null
    property string sourceImage: ""
    property string workflowMode: "fast"
    property bool extraConfigsEnabled: false
    property bool workflowBackPending: false
    property string workflowBackImage: ""
    property string workflowBackMode: ""
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, windowOpacity: 100, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    // This remains the source preset/theme value while desktopStyle carries a
    // staged user override. Reset in the Window editor must return here, not
    // to a generic 100% fallback or the currently edited slider value.
    property int windowOpacityBaseline: 100
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null })
    property var animationsStyle: ({ version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false })
    property var lookFeel: ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    property var lookFeelRecipe: null
    property alias lookFeelCatalog: lookFeelController.catalog
    property alias lookFeelBusy: lookFeelController.busy
    property alias lookFeelPresetBusy: lookFeelController.saving
    property alias lookFeelCatalogLoading: lookFeelController.catalogLoading
    property alias lookFeelCatalogError: lookFeelController.catalogError
    property alias wizardStep: wizardController.step
    property alias wizardStepCount: wizardController.stepCount
    property alias wizardCanGoBack: wizardController.canGoBack
    property alias wizardCanGoNext: wizardController.canGoNext
    property alias wizardNextLabel: wizardController.nextLabel
    property alias wizardAdvancedChoice: wizardController.advancedChoice
    property alias wizardLookFeelDecided: wizardController.lookFeelDecided
    property alias wizardOperationBusy: wizardController.operationBusy
    property alias wizardPaletteSelected: wizardController.paletteSelected
    property alias wizardRestoreFromFirstStep: wizardController.restoreFromFirstStep
    property alias wizardWorkflowOpen: wizardController.workflowStepActive
    property alias wizardWorkflowMode: wizardController.workflowMode
    property alias wizardWorkflowConfirmed: wizardController.workflowModeConfirmed
    property alias wizardWorkflowHistoryAvailable: wizardController.workflowHistoryAvailable
    property alias wizardCanOpenWorkflow: wizardController.canOpenWorkflow
    property alias wizardCanContinueWorkflow: wizardController.canContinueWorkflow
    property var terminalTranslucency: ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" })
    property string errorMessage: ""
    readonly property var signalAnimationsStyle: session.active
        ? root.animationsStyle
        : (root.resumableSession && root.resumableSession.animations_style
            ? root.normalizeAnimationsStyle(root.resumableSession.animations_style) : null)
    readonly property bool cyberpunkSignalActive: root.signalAnimationsStyle !== null
        && root.signalAnimationsStyle.glitch !== "none"
        && root.signalAnimationsStyle.reducedMotion !== true
    readonly property string homePath: String(Quickshell.env("HOME") || "")
    readonly property string stateHomePath: {
        const configured = String(Quickshell.env("XDG_STATE_HOME") || "")
        return configured !== "" ? configured : root.homePath + "/.local/state"
    }
    readonly property string currentStatePath: root.stateHomePath + "/omarchy/current"
    readonly property string currentBackgroundLink: root.currentStatePath + "/background"
    property alias shellGlitchEpoch: signalBridge.shellGlitchEpoch
    property alias shellGlitchTrigger: signalBridge.shellGlitchTrigger
    property alias notificationPopupModel: signalBridge.notificationPopupModel
    property alias notificationSignalVisible: signalBridge.notificationSignalVisible
    property alias notificationSignalEpoch: signalBridge.notificationSignalEpoch
    property alias backgroundSignalVisible: signalBridge.backgroundSignalVisible
    property alias backgroundSignalEpoch: signalBridge.backgroundSignalEpoch

    App.SignalBridge {
        id: signalBridge
        shell: root.shell
        glitchEnabled: root.cyberpunkSignalActive
        currentStatePath: root.currentStatePath
        currentBackgroundLink: root.currentBackgroundLink
    }

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
        signalBridge.triggerShellGlitch(eventName)
    }

    function normalizeShellStyle(value) {
        return StyleDocuments.normalizeShellStyle(value)
    }
    function normalizeDesktopStyle(value) {
        return StyleDocuments.normalizeDesktopStyle(value)
    }
    function normalizeAnimationsStyle(value) {
        return StyleDocuments.normalizeAnimationsStyle(value)
    }
    function normalizeBarStyle(value) {
        return StyleDocuments.normalizeBarStyle(value)
    }
    function normalizeTerminalTranslucency(value) {
        return StyleDocuments.normalizeTerminalTranslucency(value)
    }
    function copyLookFeelDocument(value) {
        return StyleDocuments.copyLookFeelDocument(value)
    }
    function normalizedLookFeelRecipe(composition) {
        return StyleDocuments.normalizedLookFeelRecipe(composition)
    }
    function styleJson(value) {
        return StyleDocuments.styleJson(value)
    }
    function mergeStyleDocument(current, incoming) {
        return StyleDocuments.mergeStyleDocument(current, incoming)
    }
    function normalizeEditedShellStyle(value) {
        return root.normalizeShellStyle(root.mergeStyleDocument(root.shellStyle, value))
    }
    function normalizeEditedDesktopStyle(value) {
        return root.normalizeDesktopStyle(root.mergeStyleDocument(root.desktopStyle, value))
    }
    function normalizeEditedBarStyle(value) {
        return root.normalizeBarStyle(root.mergeStyleDocument(root.barStyle, value))
    }
    function normalizeEditedAnimationsStyle(value) {
        return root.normalizeAnimationsStyle(root.mergeStyleDocument(root.animationsStyle, value))
    }
    function normalizeEditedTerminalTranslucency(value) {
        return root.normalizeTerminalTranslucency(root.mergeStyleDocument(root.terminalTranslucency, value))
    }
    function windowOpacityFromDesktopStyle(value, fallback) {
        value = value || ({})
        var raw = value.windowOpacity !== undefined ? value.windowOpacity : value.window_opacity
        var opacity = Number(raw)
        if (!isFinite(opacity) || opacity < 0 || opacity > 100)
            return fallback
        return Math.round(opacity)
    }
    function setWindowOpacityBaseline(value) {
        root.windowOpacityBaseline = root.windowOpacityFromDesktopStyle(value, 100)
    }
    function nativeLookFeelRecipe() {
        return root.normalizedLookFeelRecipe({
            window: { borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, windowOpacity: 100, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" },
            shell: { preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) },
            bar: { surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null },
            animations: { version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false },
            terminal: { schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" }
        })
    }
    function refreshLookFeelCustomized() {
        var recipe = root.lookFeelRecipe || root.nativeLookFeelRecipe()
        var next = root.copyLookFeelDocument(root.lookFeel)
        next.customized = {
            window: root.styleJson(root.desktopStyle) !== root.styleJson(recipe.window),
            shell: root.styleJson(root.shellStyle) !== root.styleJson(recipe.shell),
            bar: root.styleJson(root.barStyle) !== root.styleJson(recipe.bar),
            animations: root.styleJson(root.animationsStyle) !== root.styleJson(recipe.animations),
            terminal: root.styleJson(root.terminalTranslucency) !== root.styleJson(recipe.terminal)
        }
        root.lookFeel = next
    }
    function applyLookFeelComposition(composition) {
        var resolved = root.normalizedLookFeelRecipe(composition)
        root.lookFeelRecipe = resolved
        root.setWindowOpacityBaseline(resolved.window)
        root.lookFeel = root.copyLookFeelDocument(composition)
        // A preset is a complete composition. Do not carry a Window (or any
        // other) override from the previously edited theme into the new
        // recipe: doing so made Glass Blur display and stage the old 100%
        // opacity instead of its own 72% starting value. Once selected, a
        // user edit is still staged normally and Reset returns to this recipe.
        root.desktopStyle = resolved.window
        root.shellStyle = resolved.shell
        root.barStyle = resolved.bar
        root.animationsStyle = resolved.animations
        root.terminalTranslucency = resolved.terminal
        root.refreshLookFeelCustomized()
    }
    function requestLookFeelPreset(preset) {
        if (!lookFeelController.requestPreset(preset))
            return
        wizardController.chooseLookFeel()
        root.errorMessage = ""
    }

    // Look & Feel selection is itself a reversible live-preview action. The
    // complete style snapshot is assembled by previewStyles(), then handed to
    // PreviewController so its single-flight/latest-intent rules remain the
    // only native preview coordinator.
    function previewResolvedLookFeel() {
        if (!session.workspaceReady || !root.liveCanvasActive
                || root.cancelBusy || root.demoBusy || root.applyBusy)
            return "unavailable"
        if (!liveCanvasPanel)
            return "unavailable"

        const variant = session.selectedVariant || "source"
        if (!session.hasPalette(variant))
            return "unavailable"

        const overrides = liveCanvasPanel.overridesForVariant(variant)
        root.prepareLiveBar()
        return previewController.start(
            variant,
            overrides,
            root.previewStyles(variant),
            Object.keys(overrides).length > 0
        )
    }
    function loadLookFeelRecipe(preset) {
        if (!preset || preset === "omarchy-native") {
            root.lookFeelRecipe = null
            root.windowOpacityBaseline = 100
            lookFeelController.loadRecipe(preset)
            return
        }
        lookFeelController.loadRecipe(preset)
    }
    function resetLookFeelScope(scope) {
        if (!root.lookFeelRecipe || root.lookFeelBusy)
            return
        if (scope === "all") {
            root.desktopStyle = root.lookFeelRecipe.window
            root.setWindowOpacityBaseline(root.lookFeelRecipe.window)
            root.shellStyle = root.lookFeelRecipe.shell
            root.barStyle = root.lookFeelRecipe.bar
            root.animationsStyle = root.lookFeelRecipe.animations
            root.terminalTranslucency = root.lookFeelRecipe.terminal
        } else if (scope === "window") {
            root.desktopStyle = root.lookFeelRecipe.window
            root.setWindowOpacityBaseline(root.lookFeelRecipe.window)
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
            root.openRuntimeSetup(parsed.theme || parsed.theme_name || runtimeSetupTheme)
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
            // Full Demo is hidden when it starts so the desktop composition is
            // unobstructed. An explicit summon is the user's control gesture,
            // however, so reopen the Demo step here to expose Stop Full Demo
            // and keep the session on the ownership-aware cleanup path.
            if (root.demoActive && root.demoMode === "full") {
                livePanelOpen = true;
                opened = false;
                return;
            }
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
        runtimeSetupController.probeStartup()
        route = "loading";
    }

    function openRuntimeSetup(themeName) {
        if (root.sessionBusy || root.cancelBusy)
            return
        deferredCanvasAction = null
        runtimeSetupController.openSetup(themeName || runtimeSetupTheme)
        root.settingsOpen = false
        root.route = "runtime-setup"
        root.livePanelOpen = false
        root.opened = true
    }

    function close() {
        if (wizardController.workflowStepActive) {
            root.cancelPreSessionWorkflow()
            return
        }
        opened = false;
        settingsOpen = false;
        runtimeSetupOpen = false;
        deferredCanvasAction = null;
        livePanelOpen = false;
        themePickerOpen = false;
    }

    function chooseInstalledTheme() {
        if (sessionBusy || cancelBusy || session.active)
            return;
        errorMessage = "";
        opened = false;
        themePickerOpen = true;
        themeEditController.list();
    }

    function closeRuntimeSetup() {
        deferredCanvasAction = null
        runtimeSetupController.closeSetup()
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
        deferredCanvasAction = null
        runtimeSetupController.dismiss()
        if (session.active) {
            route = "workspace";
            livePanelOpen = liveCanvasActive;
        } else {
            route = "setup";
            livePanelOpen = false;
        }
        opened = false
    }

    function keepNativeRuntimeSetup() {
        if (!runtimeSetupFirstRun) {
            closeRuntimeSetup();
            return;
        }
        runtimeSetupController.keepNative()
        route = "setup";
        opened = true;
    }

    function reopenLiveCanvasPanel() {
        if (!session.active || !liveCanvasActive || root.liveCanvasPanelSuppressed)
            return;
        errorMessage = "";
        route = "workspace";
        livePanelOpen = true;
        opened = false;
    }

    function hideLiveCanvasPanel() {
        if (wizardController.workflowStepActive) {
            root.cancelPreSessionWorkflow()
            return
        }
        deferredCanvasAction = null
        livePanelOpen = false;
        opened = false;
    }

    function closeSettings() {
        if (settingsBusy)
            return;
        deferredCanvasAction = null
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
        wizardController.reset()
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
        if (session.workflow === "theme-edit") {
            var resumedEdit = resumableSession.theme_edit || ({})
            root.lookFeelRecipe = resumedEdit.shell || resumedEdit.desktop || resumedEdit.bar || resumedEdit.animations || resumedEdit.terminal
                ? root.normalizedLookFeelRecipe({
                    window: resumedEdit.desktop,
                    shell: resumedEdit.shell,
                    bar: resumedEdit.bar,
                    animations: resumedEdit.animations,
                    terminal: resumedEdit.terminal
                }) : null
            root.setWindowOpacityBaseline(root.lookFeelRecipe ? root.lookFeelRecipe.window : root.desktopStyle)
        } else {
            root.loadLookFeelRecipe(lookFeel.preset)
        }
        extraConfigsEnabled = resumableSession.extra_configs === true;
        workflowMode = extraConfigsEnabled ? "in-depth" : "fast";
        const resumedMonitor = resumableSession.canvas_monitor || "";
        resumableSession = null;
        route = "workspace";
        // A shell reload destroys this QML object, not the session-owned
        // Demo windows. Rebind to the durable canvas state in place; calling
        // demo open here would classify transiently reloading windows as
        // missing and launch duplicate applications.
        demoController.resume(canvasActive, canvasMode, resumedMonitor);
        liveCanvasActive = true;
        livePanelOpen = canvasMode === "full" ? false : true;
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

        deferredCanvasAction = null
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

        // A new session may only be created after the pre-session workflow
        // choice has been explicitly confirmed. Existing active sessions use
        // this same function only for intentional regeneration.
        if (!session.active && !wizardController.workflowModeConfirmed)
            return;

        // Regenerate inside the existing durable session. The backend commits
        // the new configuration and generation together, so active-session.json
        // remains present and a failed run leaves the previous workspace valid.
        if (session.active) {
            errorMessage = "";
            sessionBusy = true;
            opened = true;
            route = "workspace";
            generationController.generate(
                sourceImage,
                extraConfigsEnabled ? shellStyle : null,
                extraConfigsEnabled ? desktopStyle : null,
                extraConfigsEnabled ? barStyle : null,
                extraConfigsEnabled ? animationsStyle : null,
                extraConfigsEnabled ? lookFeel : null,
                extraConfigsEnabled ? terminalTranslucency : null,
                true
            );
            return;
        }

        errorMessage = "";
        sessionBusy = true;
        backend.beginSession(extraConfigsEnabled ? shellStyle : null, desktopStyle, barStyle, animationsStyle, extraConfigsEnabled ? lookFeel : null, extraConfigsEnabled ? terminalTranslucency : null);
    }

    function continueFromSetup() {
        if (sessionBusy || cancelBusy)
            return;
        if (session.active || sourceImage === "")
            return;
        if (!wizardController.canOpenWorkflow) {
            root.errorMessage = "Choose an image before continuing to Workflow."
            return;
        }
        // SetupWindow's Continue action is only the handoff. The workflow
        // page owns mode selection and the later backend Begin request.
        root.errorMessage = "";
        root.route = "workspace";
        root.livePanelOpen = true;
        root.opened = false;
    }

    function continueFromWorkflow() {
        if (sessionBusy || cancelBusy || session.active)
            return;
        if (!wizardController.workflowStepActive) {
            root.errorMessage = "Choose an image before continuing to Workflow."
            return;
        }
        if (!wizardController.confirmWorkflow()) {
            root.errorMessage = "Choose Fast or In-depth before continuing."
            return;
        }
        workflowMode = wizardController.workflowMode;
        extraConfigsEnabled = workflowMode === "in-depth";
        beginSession();
    }

    function selectVariant(variant) { if (!previewBusy && !cancelBusy && !demoBusy && !applyBusy) session.selectVariant(variant) }

    function focusedMonitorName() {
        const monitor = Hyprland.focusedMonitor
        return monitor ? String(monitor.name || "") : ""
    }

    function enterLiveCanvas(variant) {
        if (!session.workspaceReady || !session.hasPalette(variant) || cancelBusy || demoBusy || applyBusy)
            return;

        if (!liveCanvasPanel) {
            root.liveCanvasActive = true
            root.livePanelOpen = true
            root.deferredCanvasAction = function() { root.enterLiveCanvas(variant) }
            return
        }

        session.selectVariant(variant);
        errorMessage = "";

        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;

        // An active Demo and a normal Live Canvas entry both apply the
        // selected direction through the existing preview transaction. The
        // preview controller deduplicates a later Test Live click when the
        // candidate has not changed.
        if (demoActive) {
            const overrides = liveCanvasPanel.overridesForVariant(variant);
            root.prepareLiveBar();
            previewController.start(variant, overrides, root.previewStyles(variant), Object.keys(overrides).length > 0);
            return;
        }

        testLive(variant);
    }

    // Test Live is the explicit commit point for a candidate bar. The shell's
    // native bar setting is user-owned and may still contain the persisted
    // transparency toggle, but a live candidate must start with a visible
    // surface. The bar's double-click gesture can turn transparency back on.
    function prepareLiveBar() {
        if (!root.shell || typeof root.shell.mutateShellConfig !== "function")
            return;
        if (!root.shell.barConfig || root.shell.barConfig.transparent !== true)
            return;
        root.shell.mutateShellConfig(function(config) {
            if (!config.bar || typeof config.bar !== "object") config.bar = {};
            config.bar.transparent = false;
        });
    }

    function testLive(variant) {
        if (!session.workspaceReady || cancelBusy || demoBusy || applyBusy) return;
        if (!liveCanvasPanel) {
            root.liveCanvasActive = true
            root.livePanelOpen = true
            root.deferredCanvasAction = function() { root.testLive(variant) }
            return
        }
        errorMessage = "";
        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;
        const overrides = liveCanvasPanel.overridesForVariant(variant);
        root.prepareLiveBar();
        previewController.start(variant, overrides, root.previewStyles(variant), Object.keys(overrides).length > 0);
    }
    function previewStyles(variant) {
        if (!root.extraConfigsEnabled)
            return null;
        if (!liveCanvasPanel)
            return null;
        if (session.workflow === "theme-edit" && (!session.themeEdit || !(session.themeEdit.managed_scopes || []).length))
            return null;
        return {
            managedScopes: session.workflow === "theme-edit" && session.themeEdit
                ? (session.themeEdit.managed_scopes || []) : [],
            shell: liveCanvasPanel.shellStyleForVariant(variant || session.selectedVariant),
            desktop: root.desktopStyle,
            bar: root.barStyle,
            animations: root.animationsStyle,
            look_feel: root.lookFeel,
            terminal: root.terminalTranslucency
        };
    }

    function markThemeEditScope(scope) {
        if (session.workflow !== "theme-edit")
            return;
        var edit = session.themeEdit || ({})
        var scopes = (edit.managed_scopes || []).slice()
        if (scopes.indexOf(scope) === -1)
            scopes.push(scope)
        edit.managed_scopes = scopes
        session.themeEdit = edit
    }

    function previewCurrentState(variant) {
        previewController.previewCurrentState(variant);
    }

    function testLiveColors(variant, overrides, nextShellStyle, nextDesktopStyle, nextBarStyle, nextAnimationsStyle) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy || applyBusy)
            return;
        if (!liveCanvasPanel) {
            root.liveCanvasActive = true
            root.livePanelOpen = true
            root.deferredCanvasAction = function() { root.testLiveColors(variant, overrides, nextShellStyle, nextDesktopStyle, nextBarStyle, nextAnimationsStyle) }
            return
        }
        if (nextShellStyle)
            root.shellStyle = root.normalizeEditedShellStyle(nextShellStyle);
        if (nextDesktopStyle)
            root.desktopStyle = root.normalizeEditedDesktopStyle(nextDesktopStyle);
        if (nextBarStyle)
            root.barStyle = root.normalizeEditedBarStyle(nextBarStyle);
        if (nextAnimationsStyle)
            root.animationsStyle = root.normalizeEditedAnimationsStyle(nextAnimationsStyle);
        liveCanvasPanel.setStagedColors(overrides || ({}), variant);
        session.selectVariant(variant);
        errorMessage = "";
        const effectiveOverrides = liveCanvasPanel.overridesForVariant(variant);
        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;
        root.prepareLiveBar();
        previewController.start(variant, effectiveOverrides, root.previewStyles(variant), Object.keys(effectiveOverrides).length > 0);
    }
    function suggestedThemeName() {
        if (session.workflow === "theme-edit" && session.themeEdit)
            return session.themeEdit.source_name || session.themeEdit.name || session.themeEdit.id || "Edited Theme"
        let filename = root.sourceImage || ""
        if (filename === "") return "Omagen Theme"
        filename = filename.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").trim()
        if (filename === "") return "Omagen Theme"
        return filename.split(/\s+/).map(function(word) { return word.length ? word.charAt(0).toUpperCase() + word.slice(1) : word }).join(" ")
    }
    function applyTheme(variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName) {
        applyController.apply(variant, name, generateUnlock, capturePreview, replaceSource === true, saveLookFeelPreset === true, lookFeelPresetName)
    }

    function currentLookFeelComposition() {
        return StyleDocuments.serializeLookFeelComposition({
            schemaVersion: Number(root.lookFeel.schemaVersion || root.lookFeel.schema_version || 1),
            preset: String(root.lookFeel.preset || "omarchy-native"),
            presetRevision: Number(root.lookFeel.presetRevision || root.lookFeel.preset_revision || 1),
            customized: root.lookFeel.customized || ({}),
            window: root.desktopStyle,
            shell: root.shellStyle,
            bar: root.barStyle,
            animations: root.animationsStyle,
            terminal: root.terminalTranslucency
        })
    }

    function saveLookFeelPreset(name) {
        root.errorMessage = ""
        lookFeelController.savePreset(name, root.currentLookFeelComposition())
    }

    function startDemo(variant) {
        return demoController.requestMode("full", variant)
    }

    function startWindowDemo() {
        return demoController.requestMode("window")
    }

    function startShellDemo() {
        return demoController.requestMode("shell")
    }

    function startBarDemo() {
        return demoController.requestMode("bar")
    }

    function requestDemoMode(mode) {
        const target = String(mode || "")
        return demoController.requestMode(
            target,
            target === "full" ? session.selectedVariant : ""
        )
    }

    function stopBarDemo() {
        demoController.stopBarDemo()
    }

    function backendDemoActive() {
        return demoController.backendDemoActive()
    }

    function stopShellDemo() {
        demoController.stopShellDemo()
    }

    function dispatchDemo() {
        demoController.dispatch()
    }

    function cancelSession() {
        if (!session.active || session.sessionId === "" || cancelBusy) {
            if (wizardController.workflowStepActive)
                return root.cancelPreSessionWorkflow()
            return;
        }

        errorMessage = "";
        cancelBusy = true;
        cancelReturnRoute = route;
        applyController.cancel();
        demoController.cancel();
        livePanelOpen = false;
        liveCanvasActive = false;
        // The backend cancel command closes any demo, recovers an interrupted
        // Apply, restores the original theme/background, and removes the
        // session. It is deliberately the single cleanup path for explicit
        // Cancel, independent of which frontend operation was in flight.
        backend.cancelSession(session.sessionId);
    }

    // Terminal wizard intent: let the existing backend cancellation transaction
    // restore every resource it owns, then clear the frontend with the close
    // flag. This keeps ordinary Cancel/return-to-setup behavior unchanged.
    function restoreAndCloseSession() {
        if (!session.active || session.sessionId === "" || cancelBusy)
            return false
        closeAfterCancel = true
        root.cancelSession()
        return true
    }

    // Freeze the four advanced documents at the wizard boundary. The root is
    // the staged-document owner; taking fresh copies here prevents a Demo
    // round trip from exposing editor-owned nested objects or an in-flight
    // preview response as the next Advanced view's source of truth.
    function commitAdvancedStylesForNavigation() {
        if (wizardController.advancedChoice !== "customize")
            return
        root.shellStyle = root.normalizeEditedShellStyle(root.shellStyle)
        root.desktopStyle = root.normalizeEditedDesktopStyle(root.desktopStyle)
        root.barStyle = root.normalizeEditedBarStyle(root.barStyle)
        root.animationsStyle = root.normalizeEditedAnimationsStyle(root.animationsStyle)
        root.refreshLookFeelCustomized()
    }

    function wizardBack() {
        if (wizardController.step === 3)
            root.commitAdvancedStylesForNavigation()
        return wizardController.requestBack()
    }
    function wizardNext() {
        if (wizardController.step === 0) {
            // PaletteStep renders the same selectedVariant owned by SessionState.
            // Re-commit that concrete value at the page boundary so Next never
            // advances with only a visual/default card selection.
            const selectedVariant = session.ensureSelectedVariant(wizardController.selectedVariant)
            if (selectedVariant !== "")
                session.selectVariant(selectedVariant)
        }
        if (wizardController.step === 2)
            root.commitAdvancedStylesForNavigation()
        return wizardController.requestNext()
    }
    function chooseWizardAdvanced(choice) { return wizardController.chooseAdvanced(choice) }
    function chooseWizardLookFeel() { return wizardController.chooseLookFeel() }
    function skipWizardLookFeel() { return wizardController.skipLookFeel() }
    function wizardRestoreAndClose() { return wizardController.requestRestoreAndClose() }
    function beginWizardWorkflow(imageSelected) { wizardController.beginWorkflow(imageSelected === true) }
    function selectWizardWorkflow(mode) {
        if (!wizardController.selectWorkflowMode(mode))
            return false
        workflowMode = wizardController.workflowMode
        extraConfigsEnabled = workflowMode === "in-depth"
        if (extraConfigsEnabled)
            lookFeelController.list()
        return true
    }
    function wizardContinueWorkflow() { return root.continueFromWorkflow() }
    function cancelPreSessionWorkflow() {
        if (!wizardController.workflowStepActive)
            return false
        wizardController.cancelWorkflow()
        sourceImage = ""
        workflowMode = "fast"
        extraConfigsEnabled = false
        demoController.monitor = ""
        errorMessage = ""
        deferredCanvasAction = null
        livePanelOpen = false
        opened = false
        route = "setup"
        return true
    }

    function returnToWorkflowDecision() {
        if (!session.active || session.sessionId === "" || workflowBackPending || cancelBusy)
            return false
        workflowBackPending = true
        workflowBackImage = sourceImage
        workflowBackMode = workflowMode
        cancelReturnRoute = "workspace"
        root.cancelSession()
        return true
    }

    // A generated workspace is bound to a durable backend session. Returning
    // to configuration keeps the original rollback boundary but invalidates
    // the current directions. Continuing generates a fresh workspace inside
    // this same session instead of treating the old generation as current.
    function returnToConfiguration() {
        if (!session.active || session.sessionId === "" || session.generationId === "" || sessionBusy || generationBusy || describeBusy || backBusy || cancelBusy || previewBusy || applyBusy)
            return;

        errorMessage = "";
        generationController.discard();
    }

    function clearSession(closeWhenDone) {
        const shouldClose = closeWhenDone === true || closeAfterCancel;
        deferredCanvasAction = null;
        if (liveCanvasPanel) {
            liveCanvasPanel.resetApplyDialog();
            liveCanvasPanel.clearColorSession();
        }
        session.clear();
        sessionBusy = false;
        cancelBusy = false;
        closeAfterCancel = false;
        workflowBackPending = false;
        workflowBackImage = "";
        workflowBackMode = "";
        sourceImage = "";
        workflowMode = "fast";
        extraConfigsEnabled = false;
        lookFeelRecipe = null;
        windowOpacityBaseline = 100;
        lookFeel = ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) });
        terminalTranslucency = ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" });
        shellStyle = ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) });
        desktopStyle = ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, windowOpacity: 100, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" });
        barStyle = ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null });
        animationsStyle = root.normalizeAnimationsStyle({ preset: "native" });
        errorMessage = "";
        opened = !shouldClose;
        applyController.reset();
        lookFeelController.reset();
        // Refresh after a successful Apply so a newly saved local recipe is
        // immediately available if the user starts another session without
        // restarting the plugin.
        lookFeelController.list();
        generationController.reset();
        previewController.reset();
        demoController.reset();
        wizardController.reset();
        liveCanvasActive = false;
        livePanelOpen = false;
        applyCapturePanelHidden = false;
        route = "setup";
        cancelReturnRoute = "workspace";
        resumableSession = null;
        recoveryBusy = false;
        themePickerOpen = false;
    }

    State.SessionState {
        id: session
    }

    Controllers.LiveCanvasWizardController {
        id: wizardController
        sessionReady: session.workspaceReady
        operationBusy: root.sessionBusy || root.generationBusy || root.describeBusy
                || root.backBusy || root.previewBusy || root.demoBusy
                || root.cancelBusy || root.applyBusy || root.lookFeelBusy || root.lookFeelPresetBusy
        // The generated source palette is already a valid selection before
        // any optional live preview mutation. Using previewVariant here made
        // the first Next button stay disabled until the user clicked a card.
        paletteSelected: session.workspaceReady
        selectedVariant: session.selectedVariant
        selectedLookFeelPreset: String(root.lookFeel.preset || "omarchy-native")
        restoreFromFirstStep: session.active && session.workflow === "theme-edit"

        onRestoreAndCloseRequested: root.restoreAndCloseSession()
        onWorkflowBackRequested: root.cancelSession()
        onWorkflowCancelRequested: root.cancelPreSessionWorkflow()
        onGoNextRequested: {
            // Edited advanced documents need one complete staged preview when
            // the user leaves that page. Palette and preset clicks already
            // preview through their own immediate-selection paths.
            if (wizardController.step === 2 && wizardController.advancedChoice === "customize")
                root.previewCurrentState(session.selectedVariant)
        }
    }

    Controllers.ThemeEditController {
        id: themeEditController
        backend: backend
        onOpened: function(result) {
            root.sessionBusy = false;
            root.themePickerOpen = false;
            wizardController.reset();
            root.sourceImage = "";
            root.extraConfigsEnabled = true;
            root.workflowMode = "in-depth";
            session.activateThemeEdit(result);
            root.lookFeelRecipe = result.recipe
                ? root.normalizedLookFeelRecipe({
                    window: result.recipe.desktop,
                    shell: result.recipe.shell,
                    bar: result.recipe.bar,
                    animations: result.recipe.animations,
                    terminal: result.recipe.terminal
                }) : null;
            root.shellStyle = root.normalizeShellStyle(session.shellStyle);
            root.desktopStyle = root.normalizeDesktopStyle(session.desktopStyle);
            root.setWindowOpacityBaseline(root.lookFeelRecipe ? root.lookFeelRecipe.window : root.desktopStyle);
            root.barStyle = root.normalizeBarStyle(session.barStyle);
            root.animationsStyle = root.normalizeAnimationsStyle(session.animationsStyle);
            root.lookFeel = root.copyLookFeelDocument(session.lookFeel);
            root.terminalTranslucency = root.normalizeTerminalTranslucency(session.terminalTranslucency);
            root.liveCanvasActive = true;
            root.livePanelOpen = true;
            root.opened = false;
            root.route = "workspace";
            root.sessionBusy = true;
            // Theme-edit starts with the trusted source palette. Generate the
            // remaining Omagen directions from that palette so the user can
            // compare and preview all six variants without supplying a new
            // image. The backend preserves the selected theme's assets.
            root.enterLiveCanvas("source");
            generationController.generate(
                "",
                root.extraConfigsEnabled ? root.shellStyle : null,
                root.extraConfigsEnabled ? root.desktopStyle : null,
                root.extraConfigsEnabled ? root.barStyle : null,
                root.extraConfigsEnabled ? root.animationsStyle : null,
                root.extraConfigsEnabled ? root.lookFeel : null,
                root.extraConfigsEnabled ? root.terminalTranslucency : null,
                true
            );
        }
        onErrorRaised: function(message) { root.errorMessage = message }
    }

    Services.ImagePickerService {
        id: imagePicker
        executable: root.imagePickerPath

        onSelected: function(path) {
            root.sourceImage = path;
            if (session.active) {
                root.opened = true;
                return;
            }
            root.workflowMode = "";
            root.extraConfigsEnabled = false;
            wizardController.beginWorkflow(true);
            demoController.monitor = root.focusedMonitorName();
            // The image is only staged here. The pre-session wizard owns the
            // Keep SetupWindow visible until its explicit Continue to
            // Workflow handoff. No backend session or generation starts here.
            root.route = "setup";
            root.livePanelOpen = false;
            root.opened = true;
        }

        onCancelled: {
            if (wizardController.workflowStepActive) {
                root.route = "setup";
                root.livePanelOpen = false;
                root.opened = true;
                return;
            }
            root.opened = true;
        }

        onFailed: function(message) {
            root.errorMessage = message;
            if (wizardController.workflowStepActive) {
                root.route = "setup";
                root.livePanelOpen = false;
                root.opened = true;
                return;
            }
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
            wizardController.finishWorkflow();
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
            // Carry the confirmed workflow mode into generation as well as
            // Begin. Fast keeps the existing lightweight generation path;
            // In-depth receives the staged composition documents selected for
            // the Studio pages. The backend session remains the durable
            // authority for the resulting workspace.
            generationController.generate(
                root.sourceImage,
                root.extraConfigsEnabled ? root.shellStyle : null,
                root.extraConfigsEnabled ? root.desktopStyle : null,
                root.extraConfigsEnabled ? root.barStyle : null,
                root.extraConfigsEnabled ? root.animationsStyle : null,
                root.extraConfigsEnabled ? root.lookFeel : null,
                root.extraConfigsEnabled ? root.terminalTranslucency : null,
                false
            );
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
            wizardController.workflowBeginFailed()
            root.closeAfterCancel = false;
            root.errorMessage = message;
        }

        onBackendReady: {
            lookFeelController.list()
            backend.checkResumeSession()
        }
        onBackendUnavailable: function(message) {
            root.resumableSession = null;
            root.route = "setup";
            root.errorMessage = "Omagen could not start its backend: " + message;
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
            if (root.workflowBackPending) {
                const preservedImage = root.workflowBackImage;
                const preservedMode = root.workflowBackMode;
                root.workflowBackPending = false;
                root.workflowBackImage = "";
                root.workflowBackMode = "";
                root.clearSession();
                root.sourceImage = preservedImage;
                root.workflowMode = preservedMode;
                root.beginWizardWorkflow(true);
                root.selectWizardWorkflow(preservedMode);
                demoController.monitor = root.focusedMonitorName();
                root.route = "workspace";
                root.livePanelOpen = true;
                root.opened = false;
                return;
            }
            root.clearSession();
        }

        onSessionCancelFailed: function(message) {
            root.cancelBusy = false;
            root.closeAfterCancel = false;
            if (root.workflowBackPending) {
                root.workflowBackPending = false;
                root.workflowBackImage = "";
                root.workflowBackMode = "";
                root.liveCanvasActive = true;
                root.livePanelOpen = true;
                root.opened = false;
                root.route = "workspace";
            }
            root.errorMessage = message;
            if (!root.livePanelOpen) {
                root.opened = true;
                root.route = root.cancelReturnRoute;
            }
        }

    }

    Controllers.LookFeelController {
        id: lookFeelController
        backend: backend
        extraConfigsEnabled: root.extraConfigsEnabled
        previewBusy: previewController.busy
        applyBusy: applyController.busy
        cancelBusy: root.cancelBusy

        onResolved: function(composition, applies) {
            if (applies) {
                root.applyLookFeelComposition(composition)
                root.previewResolvedLookFeel()
            } else {
                root.lookFeelRecipe = root.normalizedLookFeelRecipe(composition)
                root.setWindowOpacityBaseline(root.lookFeelRecipe.window)
                root.refreshLookFeelCustomized()
            }
        }
        onPresetSaved: function(entry) {
            root.errorMessage = "Saved Look & Feel preset: " + String(entry.name || entry.id || "local preset")
            if (liveCanvasPanel)
                liveCanvasPanel.closeLookFeelPresetDialog()
            lookFeelController.list()
        }
        onErrorRaised: root.errorMessage = message
    }

    Controllers.GenerationController {
        id: generationController
        backend: backend
        session: session
        cancelBusy: root.cancelBusy
        closeAfterCancel: root.closeAfterCancel
    }

    Connections {
        target: generationController

        function onFailed(sessionId, message, wasRegeneration) {
            root.sessionBusy = false
            if (wasRegeneration) {
                root.liveCanvasActive = true
                root.livePanelOpen = true
                root.opened = false
                root.route = "workspace"
            }
            root.errorMessage = message
        }

        function onDescribed(sessionId, generationId, variants, wasRegeneration) {
            root.sessionBusy = false
            root.liveCanvasActive = true
            root.livePanelOpen = true
            root.opened = false
            root.route = "workspace"
            if (!wasRegeneration)
                wizardController.finishWorkflow()
            if (session.workflow === "theme-edit" && variants.length === 1) {
                root.sessionBusy = true;
                generationController.generate(
                    "",
                    root.extraConfigsEnabled ? root.shellStyle : null,
                    root.extraConfigsEnabled ? root.desktopStyle : null,
                    root.extraConfigsEnabled ? root.barStyle : null,
                    root.extraConfigsEnabled ? root.animationsStyle : null,
                    root.extraConfigsEnabled ? root.lookFeel : null,
                    root.extraConfigsEnabled ? root.terminalTranslucency : null,
                    true
                );
                return;
            }
            // Continue opens Live Canvas on Source and applies it once. A
            // later Test Live click with no edits is deduplicated by the
            // preview controller instead of replacing the same bar again.
            root.enterLiveCanvas("source")
        }

        function onDiscarded(sessionId, generationId) {
            root.liveCanvasActive = false
            demoController.markClosed()
            root.livePanelOpen = false
            // Returning from the first live page discards only the generated
            // workspace. Keep the selected image and confirmed workflow mode
            // available for the next Continue without creating a new session.
            wizardController.resetNavigation()
            if (liveCanvasPanel)
                liveCanvasPanel.clearColorSession()
            session.clearGeneration()
            root.liveCanvasActive = true
            root.livePanelOpen = true
            root.opened = false
            root.route = "workspace"
        }

        function onDiscardFailed(sessionId, message) {
            root.errorMessage = message
            root.opened = true
            root.route = "workspace"
        }
    }

    Controllers.RuntimeSetupController {
        id: runtimeSetupController
        backend: backend

        onPromptRequired: {
            root.route = "runtime-setup"
            root.opened = true
        }
        onContinueToBackend: {
            root.route = "loading"
            backend.checkBackend()
        }
        onErrorRaised: root.errorMessage = message
    }

    Controllers.DemoController {
        id: demoController
        backend: backend
        session: session
        previewController: previewController
        focusedMonitorName: function() { return root.focusedMonitorName() }
        applyActive: applyController.active
        workspaceReady: session.workspaceReady
        previewBusy: previewController.busy
        applyBusy: applyController.busy
        cancelBusy: root.cancelBusy
        liveCanvasActive: root.liveCanvasActive
        closeAfterCancel: root.closeAfterCancel

        onActivateCanvasRequested: {
            root.liveCanvasActive = true
            root.livePanelOpen = true
        }
        onHideApplicationRequested: root.opened = false
        onHideLiveCanvasRequested: root.livePanelOpen = false
        onStopped: root.livePanelOpen = root.liveCanvasActive
        onErrorRaised: root.errorMessage = message
    }

    Controllers.ApplyController {
        id: applyController
        backend: backend
        session: session
        previewController: previewController
        demoController: demoController
        workspaceReady: session.workspaceReady
        previewBusy: previewController.busy
        demoBusy: root.demoBusy
        cancelBusy: root.cancelBusy
        demoActive: root.demoActive
        demoMode: root.demoMode
        closeAfterCancel: root.closeAfterCancel

        onErrorRaised: function(message) {
            root.errorMessage = message
        }
        onHideApplication: root.opened = false
        onHideLiveCanvasRequested: {
            root.applyCapturePanelHidden = true
            root.livePanelOpen = false
        }
        onShowApplication: {
            root.opened = true
            if (root.applyCapturePanelHidden) {
                root.applyCapturePanelHidden = false
                root.livePanelOpen = root.liveCanvasActive
            }
        }
        onDemoBusyRequested: function(busy) {
            root.demoBusy = busy
        }
        onStopBarDemoRequested: root.stopBarDemo()
        onCompleted: root.clearSession(true)
    }

    Controllers.PreviewController {
        id: previewController
        backend: backend
        session: session
        liveCanvasPanel: root.liveCanvasPanel
        stylesForVariant: function(variant) { return root.previewStyles(variant) }
        closeAfterCancel: root.closeAfterCancel

        onRejected: function(message) {
            root.errorMessage = message
        }

        onApplied: function(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return
            if (applyController.handlePreviewApplied())
                return
            if (demoController.handlePreviewApplied())
                return
            // Shell and Bar Demos are QML-only reader surfaces. They do not own
            // a backend workspace or demo-state.json, so previewing them must
            // not enter the window/full-demo reflow path.
            if (root.backendDemoActive()) {
                // Reassert workspace ownership after the candidate reload. The
                // Demo itself remains in Hyprland's dwindle layout; only the
                // Studio panel is an overlay and must never become a tiled pane.
                demoController.reflow()
                return
            }

            if (root.pendingDemo) {
                demoController.finishPendingDemo()
                root.livePanelOpen = true
                root.opened = false
                return
            }

            if (root.liveCanvasActive) {
                root.livePanelOpen = true
                root.opened = false
            } else {
                root.opened = false
                root.livePanelOpen = false
            }
        }

        onFailed: function(message) {
            if (root.closeAfterCancel)
                return
            if (applyController.handlePreviewFailed(message))
                return
            if (demoController.handlePreviewFailed(message))
                return
            root.errorMessage = message
            if (root.pendingDemo) {
                demoController.finishPendingDemo()
                root.livePanelOpen = root.liveCanvasActive
            }
        }
    }

    Connections {
        target: demoController

        function onOpened(sessionId, workspace, monitor, reused) {
            if (applyController.active)
                return
            if (root.pendingDemo) {
                previewController.previewCurrentState(session.selectedVariant)
                return
            }
            root.opened = false
            root.livePanelOpen = root.demoMode === "full" ? false : root.liveCanvasActive
        }

        function onOpenFailed(message) {
            if (applyController.active)
                return
            root.errorMessage = message
            root.livePanelOpen = root.liveCanvasActive
            root.opened = root.liveCanvasActive ? false : true
        }

        function onWindowOpened(sessionId, workspace, monitor, reused) {
            if (applyController.active)
                return
            root.opened = false
            root.livePanelOpen = root.liveCanvasActive
        }

        function onWindowOpenFailed(message) {
            if (applyController.active)
                return
            root.errorMessage = message
            root.opened = root.liveCanvasActive ? false : true
        }

        function onReflowed(sessionId) {
            if (root.closeAfterCancel || applyController.active)
                return
            if (sessionId !== session.sessionId) {
                root.errorMessage = "Backend reflowed a different live canvas session"
                return
            }
            if (root.pendingDemo) {
                demoController.finishPendingDemo()
                root.livePanelOpen = root.demoMode === "full" ? false : true
                root.opened = false
                return
            }
            // Reapplication from the side panel keeps the panel available for
            // the next direction instead of forcing a trip back through the
            // bar widget.
            root.livePanelOpen = root.demoMode === "full" ? false : true
            root.opened = false
        }

        function onReflowFailed(message) {
            if (root.closeAfterCancel || applyController.active)
                return
            // Demo cleanup removes demo-state.json after its windows and
            // workspace are gone. A queued reflow can arrive just after that
            // cleanup and otherwise exposes an internal transient path to the
            // user. Treat the missing state as an already-closed Demo.
            if (message.indexOf("demo-state.json") !== -1 && message.indexOf("no such file") !== -1) {
                demoController.markClosed()
                root.errorMessage = ""
                root.livePanelOpen = root.liveCanvasActive
                return
            }
            root.errorMessage = message
            demoController.finishPendingDemo()
            root.livePanelOpen = root.liveCanvasActive
            root.opened = root.liveCanvasActive ? false : true
        }

        function onCaptured(sessionId, previewPath) {
            if (applyController.active)
                return
        }

        function onCaptureFailed(message) {
            if (applyController.active)
                return
            root.errorMessage = message
            root.opened = true
        }

        function onClosed(sessionId, wasClosed) {
            if (applyController.active)
                return
            if (sessionId !== session.sessionId) {
                root.errorMessage = "Backend closed a different demo session"
                return
            }
            root.livePanelOpen = root.liveCanvasActive
            root.opened = root.liveCanvasActive ? false : true
        }

        function onCloseFailed(message) {
            if (applyController.active)
                return
            root.errorMessage = message
            if (root.pendingWindowDemo) {
                root.pendingWindowDemo = false
                root.opened = true
            } else {
                root.livePanelOpen = root.liveCanvasActive
                root.opened = false
            }
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
        onEditThemeRequested: root.chooseInstalledTheme()
        onAdvancedRuntimeRequested: root.openRuntimeSetup("")
        workflowMode: root.workflowMode
        onWorkflowModeSelected: {
            if (session.active) {
                root.workflowMode = mode;
                root.extraConfigsEnabled = mode === "in-depth";
                if (root.extraConfigsEnabled)
                    lookFeelController.list();
            } else {
                root.selectWizardWorkflow(mode);
            }
        }
        onContinueRequested: root.continueFromSetup()
        onCancelRequested: session.active ? root.cancelSession() : root.cancelPreSessionWorkflow()
        onHideRequested: root.close()
    }

    Views.ThemePickerWindow {
        active: root.themePickerOpen
        busy: themeEditController.opening
        themes: themeEditController.themes
        errorMessage: root.errorMessage
        onThemeSelected: function(themeId) {
            root.errorMessage = ""
            root.sessionBusy = true
            themeEditController.open(themeId)
        }
        onCloseRequested: {
            root.themePickerOpen = false
            root.opened = true
            root.sessionBusy = false
            themeEditController.reset()
        }
    }

    Views.AdvancedRuntimeSetupWindow {
        active: root.runtimeSetupOpen
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        busy: root.runtimeSetupBusy
        installed: root.runtimeSetupInstalled
        firstRun: root.runtimeSetupFirstRun
        themeName: root.runtimeSetupTheme
        message: root.runtimeSetupMessage

        onInstallRequested: runtimeSetupController.install()
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

    Loader {
        id: liveCanvasLoader
        active: session.active || root.liveCanvasActive || root.livePanelOpen || root.demoActive
                || root.applyBusy || root.wizardWorkflowOpen
        onLoaded: {
            var action = root.deferredCanvasAction
            root.deferredCanvasAction = null
            if (action)
                action()
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                root.deferredCanvasAction = null
                root.errorMessage = "Omagen Studio could not load its workspace"
            }
        }
        sourceComponent: Component {
            Views.LiveCanvasPanel {
        active: root.route === "workspace" && root.livePanelOpen
                && ((session.active && root.liveCanvasActive) || root.wizardWorkflowOpen)
        previewBusy: root.previewBusy
        demoBusy: root.demoBusy
        demoActive: root.demoActive
        demoMode: root.demoMode
        cancelBusy: root.cancelBusy
        applyBusy: root.applyBusy
        generationBusy: root.generationBusy || root.describeBusy
        workspaceReady: session.workspaceReady
        wizardStep: root.wizardStep
        wizardStepCount: root.wizardStepCount
        wizardCanGoBack: root.wizardCanGoBack
        wizardCanGoNext: root.wizardCanGoNext
        wizardNextLabel: root.wizardNextLabel
        wizardAdvancedChoice: root.wizardAdvancedChoice
        wizardLookFeelDecided: root.wizardLookFeelDecided
        wizardOperationBusy: root.wizardOperationBusy
        wizardPaletteSelected: root.wizardPaletteSelected
        wizardRestoreFromFirstStep: root.wizardRestoreFromFirstStep
        wizardCanContinueWorkflow: root.wizardCanContinueWorkflow
        workflowStep: root.wizardWorkflowOpen
        workflowMode: root.wizardWorkflowMode
        workflowSelected: root.wizardWorkflowConfirmed
        sourceImage: root.sourceImage
        extraConfigsEnabled: root.extraConfigsEnabled
        lookFeel: root.lookFeel
        lookFeelRecipe: root.lookFeelRecipe
        lookFeelCatalog: root.lookFeelCatalog
        lookFeelBusy: root.lookFeelBusy
        lookFeelPresetBusy: root.lookFeelPresetBusy
        lookFeelCatalogLoading: root.lookFeelCatalogLoading
        lookFeelCatalogError: root.lookFeelCatalogError
        terminalTranslucency: root.terminalTranslucency
        terminalPresetOpacity: root.lookFeelRecipe && root.lookFeelRecipe.terminal
            ? Number(root.lookFeelRecipe.terminal.opacity || 0.82) : 0.82
        shellStyle: root.shellStyle
        desktopStyle: root.desktopStyle
        windowOpacityBaseline: root.windowOpacityBaseline
        barStyle: root.barStyle
        animationsStyle: root.animationsStyle
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        errorMessage: root.errorMessage
        selectedVariant: session.selectedVariant
        monitorName: root.liveCanvasMonitor
        suggestedThemeName: root.suggestedThemeName()
        sourceThemeName: session.themeEdit ? String(session.themeEdit.name || session.themeEdit.source_name || session.themeEdit.id || "") : ""
        variants: root.variants
        palettes: session.palettes

        onHideRequested: root.hideLiveCanvasPanel()
        onCloseCanvasRequested: root.dispatchDemo()
        onStartDemoRequested: root.requestDemoMode("full")
        onWindowDemoRequested: root.requestDemoMode("window")
        onWindowDemoStopRequested: root.dispatchDemo()
        onShellDemoRequested: root.requestDemoMode("shell")
        onShellDemoStopRequested: root.stopShellDemo()
        onBarDemoRequested: root.requestDemoMode("bar")
        onBarDemoStopRequested: root.stopBarDemo()
        onCancelRequested: root.cancelSession()
        onVariantRequested: function(variant) { root.enterLiveCanvas(variant) }
        onColorTestLiveRequested: function(variant, overrides, shellStyle, desktopStyle, barStyle, animationsStyle) { root.testLiveColors(variant, overrides, shellStyle, desktopStyle, barStyle, animationsStyle) }
        onTestLiveRequested: root.previewCurrentState(session.selectedVariant)
        onGoBackRequested: root.wizardBack()
        onGoNextRequested: root.wizardNext()
        onAdvancedChoiceRequested: function(choice) { root.chooseWizardAdvanced(choice) }
        onLookFeelSelectedRequested: root.chooseWizardLookFeel()
        onLookFeelSkippedRequested: root.skipWizardLookFeel()
        onDemoSkippedRequested: root.wizardNext()
        onRestoreAndCloseRequested: root.wizardRestoreAndClose()
        onWorkflowModeSelected: function(mode) { root.selectWizardWorkflow(mode) }
        onWorkflowContinueRequested: root.wizardContinueWorkflow()
        onLookFeelCatalogRetryRequested: lookFeelController.list()
        onAdvancedStylesChanged: function(shellStyle, desktopStyle, barStyle, animationsStyle) {
            root.markThemeEditScope("shell-bar")
            root.markThemeEditScope("window-motion")
            root.shellStyle = root.normalizeEditedShellStyle(shellStyle)
            root.desktopStyle = root.normalizeEditedDesktopStyle(desktopStyle)
            root.barStyle = root.normalizeEditedBarStyle(barStyle)
            root.animationsStyle = root.normalizeEditedAnimationsStyle(animationsStyle)
            root.refreshLookFeelCustomized()
        }
        onLookFeelPresetRequested: { root.markThemeEditScope("shell-bar"); root.markThemeEditScope("window-motion"); root.requestLookFeelPreset(preset) }
        onSaveLookFeelPresetRequested: root.saveLookFeelPreset(name)
        onLookFeelResetRequested: { root.markThemeEditScope(scope === "terminal" ? "terminal" : scope === "shell" || scope === "bar" ? "shell-bar" : "window-motion"); root.resetLookFeelScope(scope) }
        onTerminalIntentChanged: function(terminal) {
            root.markThemeEditScope("terminal")
            root.terminalTranslucency = root.normalizeEditedTerminalTranslucency(terminal)
            root.refreshLookFeelCustomized()
        }
        onApplyRequested: function(variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName) {
            root.errorMessage = ""
            root.applyTheme(variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName)
        }
            }
        }
    }

    Loader {
        id: shellDemoLoader
        active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "shell"
        sourceComponent: Component {
            Views.ShellDemoPanel {
                active: true
                monitorName: root.liveCanvasMonitor
                shellStyle: root.shellStyle
                glitchEnabled: root.cyberpunkSignalActive
                glitchEpoch: root.shellGlitchEpoch
                onCloseRequested: root.stopShellDemo()
            }
        }
    }

    Loader {
        id: barDemoLoader
        active: session.active && root.liveCanvasActive && root.demoActive && root.demoMode === "bar"
        sourceComponent: Component {
            Views.BarDemoPanel {
                active: true
                glitchEnabled: root.cyberpunkSignalActive
                glitchEpoch: root.shellGlitchEpoch
                monitorName: root.liveCanvasMonitor
                barStyle: root.barStyle
                onCloseRequested: root.stopBarDemo()
            }
        }
    }

    Views.LiveCanvasHandle {
        active: session.active && root.liveCanvasActive && !root.opened && !root.livePanelOpen
            && !root.liveCanvasPanelSuppressed
        glitchEnabled: root.cyberpunkSignalActive
        glitchEpoch: root.shellGlitchEpoch
        monitorName: root.liveCanvasMonitor
        demoActive: root.demoActive
        demoMode: root.demoMode
        actionBusy: root.demoBusy || root.previewBusy || root.applyBusy || root.cancelBusy
        onReopenRequested: root.reopenLiveCanvasPanel()
        onDemoModeRequested: function(mode) {
            root.requestDemoMode(mode)
        }
        onSaveApplyRequested: {
            if (root.demoBusy || root.previewBusy || root.applyBusy || root.cancelBusy)
                return
            // Full Demo intentionally hides the side panel. This direct
            // affordance keeps Save & Apply available without making users
            // discover the tiny reopen handle and navigate to Finish first.
            wizardController.step = wizardController.stepCount - 1
            root.livePanelOpen = true
            root.opened = false
            if (root.liveCanvasPanel)
                Qt.callLater(function() { root.liveCanvasPanel.openApplyDialog() })
            else {
                root.deferredCanvasAction = function() {
                    if (root.liveCanvasPanel && root.livePanelOpen)
                        root.liveCanvasPanel.openApplyDialog()
                }
            }
        }
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
