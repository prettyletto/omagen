import QtQuick
import Quickshell

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views

Item {
    id: root

    property bool opened: false
    property bool sessionBusy: false
    property bool cancelBusy: false
    property string cancelReturnRoute: "workspace"
    property bool closeAfterCancel: false
    property bool settingsOpen: false
    property string settingsReturnRoute: "setup"
    property bool settingsBusy: false
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
    property bool liveCanvasActive: false
    property bool livePanelOpen: false
    property string liveCanvasMonitor: ""
    property bool pendingDemo: false
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
    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" })
    property string errorMessage: ""

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

    function normalizeShellStyle(value) {
        value = value || ({})
        var surface = value.surface || "flat"
        var detail = value.detail || "native"
        var tooltip = value.tooltip || "native"
        var notifications = value.notifications || "native"
        return {
            surface: surface,
            detail: detail,
            tooltip: tooltip,
            notifications: notifications
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
        return { borderStyle: border, borderSize: borderSize, borderSizeMode: borderSizeMode, borderSpeed: borderSpeed, shape: value.shape || "native", spacing: value.spacing || "native", depth: value.depth || "native", inactiveStyle: value.inactiveStyle || value.inactive_style || "native" }
    }
    function normalizeBarStyle(value) { value = value || ({}); return { surface: value.surface || "native", density: value.density || "native", attention: value.attention || "semantic", form: value.form || "continuous", visibility: value.visibility || "native" } }

    function open(payload) {
        let action = "open";
        try {
            let parsed = ({});
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
        route = "loading";
        backend.checkBackend();
    }

    function close() {
        opened = false;
        settingsOpen = false;
        livePanelOpen = false;
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
        session.resume(resumableSession);
        sourceImage = resumableSession.source_image || "";
        shellStyle = normalizeShellStyle(resumableSession.shell_style || resumableSession.desktop_style);
        desktopStyle = normalizeDesktopStyle(resumableSession.desktop_style);
        barStyle = normalizeBarStyle(resumableSession.bar_style);
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
            backend.generateTheme(session.sessionId, sourceImage, extraConfigsEnabled ? shellStyle : null, extraConfigsEnabled ? desktopStyle : null, extraConfigsEnabled ? barStyle : null);
            return;
        }

        errorMessage = "";
        sessionBusy = true;
        backend.beginSession(extraConfigsEnabled ? shellStyle : null, desktopStyle, barStyle);
    }

    function continueFromSetup() {
        extraConfigsEnabled = workflowMode === "in-depth";
        beginSession();
    }

    function selectVariant(variant) { if (!previewBusy && !cancelBusy && !demoBusy && !applyBusy) session.selectVariant(variant) }
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
            backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles());
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
        backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles());
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
        }
        liveCanvasPanel.setStagedColors(state.color_overrides || {}, state.variant);
    }

    function previewStyles() {
        if (!root.extraConfigsEnabled)
            return null;
        return { shell: root.shellStyle, desktop: root.desktopStyle, bar: root.barStyle };
    }

    function previewCurrentState(variant) {
        const overrides = liveCanvasPanel.overridesForVariant(variant);
        root.pendingColorPreview = Object.keys(overrides).length > 0;
        root.previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant, overrides, root.previewStyles());
    }

    function testLiveColors(variant, overrides, nextShellStyle, nextDesktopStyle, nextBarStyle) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy || applyBusy)
            return;
        if (nextShellStyle)
            root.shellStyle = root.normalizeShellStyle(nextShellStyle);
        if (nextDesktopStyle)
            root.desktopStyle = root.normalizeDesktopStyle(nextDesktopStyle);
        if (nextBarStyle)
            root.barStyle = root.normalizeBarStyle(nextBarStyle);
        liveCanvasPanel.setStagedColors(overrides || ({}), variant);
        session.selectVariant(variant);
        errorMessage = "";
        const effectiveOverrides = liveCanvasPanel.overridesForVariant(variant);
        pendingColorPreview = Object.keys(effectiveOverrides).length > 0;
        liveCanvasActive = true;
        livePanelOpen = true;
        opened = false;
        previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant, effectiveOverrides, root.previewStyles());
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
            if (demoActive) {
                root.previewCurrentState(variant)
            } else {
                backend.openDemo(session.sessionId)
            }
            return
        }

        if (demoActive) {
            pendingApplyAfterDemo = true
            pendingApplyCloseDemo = true
            demoBusy = true
            root.previewCurrentState(variant)
            return
        }
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

    function dispatchDemo() {
        if (!demoActive || demoBusy || cancelBusy || session.sessionId === "")
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
        shellStyle = ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" });
        desktopStyle = ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", inactiveStyle: "native" });
        barStyle = ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" });
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
        liveCanvasActive = false;
        livePanelOpen = false;
        liveCanvasMonitor = "";
        pendingDemo = false;
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
            backendBarStyle
        ) {
            root.sessionBusy = false;
            session.activate(
                sessionId
            );
            root.shellStyle = root.normalizeShellStyle(backendShellStyle);
            root.desktopStyle = root.normalizeDesktopStyle(backendDesktopStyle);
            root.barStyle = root.normalizeBarStyle(backendBarStyle);
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
            backend.generateTheme(sessionId, root.sourceImage, null, null, null);
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

        onBackendReady: backend.checkResumeSession()
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

            if (root.demoActive) {
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
            root.livePanelOpen = root.liveCanvasActive;
            if (root.pendingApplyAbortAfterDemo) {
                root.resetPendingApply()
                root.applyBusy = false
                root.opened = true
                return
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
            if (root.pendingApplyAfterDemo || root.pendingApplyAbortAfterDemo) {
                // A failed Demo close must abort this Apply attempt. Keeping
                // applyBusy/pendingApplyAfterDemo set would leave the UI
                // waiting forever for a demoClosed signal that will not come.
                root.resetPendingApply();
                root.applyBusy = false;
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

        Views.RecoveryWindow {
            active: root.opened && root.route === "recovery"
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
        cancelBusy: root.cancelBusy
        applyBusy: root.applyBusy
        generationBusy: root.generationBusy || root.describeBusy
        workspaceReady: session.workspaceReady
        extraConfigsEnabled: root.extraConfigsEnabled
        shellStyle: root.shellStyle
        desktopStyle: root.desktopStyle
        barStyle: root.barStyle
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
        onCancelRequested: root.cancelSession()
        onVariantRequested: function(variant) { root.enterLiveCanvas(variant) }
        onColorTestLiveRequested: function(variant, overrides, shellStyle, desktopStyle, barStyle) { root.testLiveColors(variant, overrides, shellStyle, desktopStyle, barStyle) }
        onAdvancedStylesChanged: function(shellStyle, desktopStyle, barStyle) {
            root.shellStyle = root.normalizeShellStyle(shellStyle)
            root.desktopStyle = root.normalizeDesktopStyle(desktopStyle)
            root.barStyle = root.normalizeBarStyle(barStyle)
        }
        onProtocolBackRequested: root.navigateProtocol("back")
        onProtocolForwardRequested: root.navigateProtocol("forward")
        onApplyRequested: function(variant, name, generateUnlock, capturePreview) {
            root.applyTheme(variant, name, generateUnlock, capturePreview)
        }
    }

    Views.LiveCanvasHandle {
        active: session.active && root.liveCanvasActive && !root.opened && !root.livePanelOpen
        monitorName: root.liveCanvasMonitor
        onReopenRequested: root.reopenLiveCanvasPanel()
    }

    Views.SettingsWindow {
        id: settingsWindow
        active: root.opened && root.route === "settings" && root.settingsOpen
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
