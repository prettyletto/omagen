import QtQuick

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views

Item {
    id: root

    property bool opened: false
    property bool sessionBusy: false
    property bool cancelBusy: false
    property bool closeAfterCancel: false
    property bool settingsOpen: false
    property string settingsReturnRoute: "setup"
    property bool settingsBusy: false
    property bool generationBusy: false
    property bool describeBusy: false
    property bool previewBusy: false
    property bool applyBusy: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool pendingDemo: false
    property bool pendingCancelAfterDemo: false
    property bool pendingApplyAfterDemo: false
    property bool recoveryBusy: false
    property string route: "unknown"
    property var resumableSession: null
    property string pendingApplyVariant: ""
    property string pendingApplyName: ""
    property string sourceImage: ""
    property bool extraConfigsEnabled: false
    property var shellStyle: ({ surface: "flat", detail: "native" })
    property var desktopStyle: ({ borderStyle: "solid", shape: "native", spacing: "native", depth: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous" })
    property string errorMessage: ""

    readonly property string backendPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen")
            .toString()
            .replace("file://", "")
    )

    function normalizeShellStyle(value) {
        value = value || ({})
        var surface = value.surface || "flat"
        var detail = value.detail || "native"
        return {
            surface: surface,
            detail: detail
        }
    }
    function normalizeDesktopStyle(value) {
        value = value || ({})
        var border = value.borderStyle || value.border_style || "solid"
        if (border === "split") border = "split_top"
        return { borderStyle: border, shape: value.shape || "native", spacing: value.spacing || "native", depth: value.depth || "native" }
    }
    function normalizeBarStyle(value) { value = value || ({}); return { surface: value.surface || "native", density: value.density || "native", attention: value.attention || "semantic", form: value.form || "continuous" } }

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
            route = "workspace";
            return;
        }
        route = "loading";
        backend.checkBackend();
    }

    function close() {
        opened = false;
        settingsOpen = false;
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
        session.resume(resumableSession);
        sourceImage = resumableSession.source_image || "";
        shellStyle = normalizeShellStyle(resumableSession.shell_style || resumableSession.desktop_style);
        desktopStyle = normalizeDesktopStyle(resumableSession.desktop_style);
        barStyle = normalizeBarStyle(resumableSession.bar_style);
        extraConfigsEnabled = resumableSession.extra_configs === true;
        resumableSession = null;
        route = "workspace";
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

        errorMessage = "";
        sessionBusy = true;
        backend.beginSession(extraConfigsEnabled ? shellStyle : null, desktopStyle, barStyle);
    }

    function continueFromSetup() {
        if (extraConfigsEnabled) {
            route = "preview-config";
            errorMessage = "";
            return;
        }
        beginSession();
    }

    function selectVariant(variant) { if (!previewBusy && !cancelBusy && !demoBusy && !applyBusy) session.selectVariant(variant) }
    function testLive(variant) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy || applyBusy) return;
        errorMessage = ""; previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant);
    }
    function suggestedThemeName() {
        let filename = root.sourceImage || ""
        if (filename === "") return "Omagen Theme"
        filename = filename.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").trim()
        if (filename === "") return "Omagen Theme"
        return filename.split(/\s+/).map(function(word) { return word.length ? word.charAt(0).toUpperCase() + word.slice(1) : word }).join(" ")
    }
    function applyTheme(variant, name) {
        if (!session.workspaceReady || applyBusy || previewBusy || cancelBusy || demoBusy) return
        errorMessage = ""; applyBusy = true
        if (demoActive) {
            pendingApplyAfterDemo = true
            pendingApplyVariant = variant
            pendingApplyName = name
            demoBusy = true
            backend.closeDemo(session.sessionId)
            return
        }
        backend.applyTheme(session.sessionId, session.generationId, variant, name)
    }

    function demoVariant(variant) {
        if (demoActive || demoBusy || previewBusy || cancelBusy || applyBusy || !session.workspaceReady)
            return;

        errorMessage = "";
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
        demoBusy = false;
        pendingCancelAfterDemo = false;
        pendingDemo = false;
        pendingApplyAfterDemo = false;
        // The backend cancel command closes any demo, recovers an interrupted
        // Apply, restores the original theme/background, and removes the
        // session.  It is deliberately the single cleanup path for Quit and
        // Cancel, independent of which frontend operation was in flight.
        backend.cancelSession(session.sessionId);
    }

    function clearSession() {
        const shouldClose = closeAfterCancel;
        session.clear();
        sessionBusy = false;
        cancelBusy = false;
        closeAfterCancel = false;
        sourceImage = "";
        extraConfigsEnabled = false;
        shellStyle = ({ surface: "flat", detail: "native" });
        desktopStyle = ({ borderStyle: "solid", shape: "native", spacing: "native", depth: "native" });
        barStyle = ({ surface: "native", density: "native", attention: "semantic", form: "continuous" });
        errorMessage = "";
        opened = !shouldClose;
        generationBusy = false;
        describeBusy = false;
        previewBusy = false;
        demoBusy = false;
        demoActive = false;
        pendingDemo = false;
        pendingCancelAfterDemo = false;
        pendingApplyAfterDemo = false;
        pendingApplyVariant = "";
        pendingApplyName = "";
        applyBusy = false;
        route = "setup";
        resumableSession = null;
        recoveryBusy = false;
    }

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
                sessionId,
                originalTheme,
                backgroundKind,
                backgroundPath
            );
            root.shellStyle = root.normalizeShellStyle(backendShellStyle);
            root.desktopStyle = root.normalizeDesktopStyle(backendDesktopStyle);
            root.barStyle = root.normalizeBarStyle(backendBarStyle);
            root.extraConfigsEnabled = backendExtraConfigs;
            if (root.closeAfterCancel) {
                root.cancelSession();
                return;
            }
            root.route = "workspace";
            root.generationBusy = true;
            backend.generateTheme(sessionId, root.sourceImage);
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
            root.recoveryBusy = false;
            root.resumableSession = null;
            root.session.clear();
            root.sourceImage = "";
            root.closeAfterCancel = false;
            root.route = "setup";
            root.settingsOpen = false;
            root.opened = false;
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
            root.route = "workspace";
        }

        onGenerationCompleted: function(generationId) {
            if (root.closeAfterCancel)
                return;
            root.generationBusy = false;
            root.describeBusy = true;
            backend.describeGeneration(session.sessionId, generationId);
        }
        onGenerationFailed: function(message) { root.generationBusy=false; root.errorMessage=message }
        onGenerationDescribed: function(generationId, variants) {
            if (root.closeAfterCancel)
                return;
            root.describeBusy=false;
            session.setGeneration(generationId, variants);
        }
        onGenerationDescribeFailed: function(message) { root.describeBusy=false; root.errorMessage=message }
        onPreviewApplied: function(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return;
            root.previewBusy = false;
            if (sessionId!==session.sessionId || generationId!==session.generationId) { root.errorMessage="Backend previewed a different generation"; return }
            session.markPreviewed(variant);

            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.demoBusy = false;
                root.opened = false;
                return;
            }

            root.opened=false;
        }
        onPreviewApplyFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.previewBusy = false;
            root.errorMessage = message;
            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.demoBusy = false;
            }
        }
        onDemoOpened: function(sessionId, workspace, reused) {
            if (root.closeAfterCancel)
                return;
            if (sessionId !== session.sessionId) {
                root.demoBusy = false;
                root.errorMessage = "Backend opened a different demo session";
                root.opened = true;
                return;
            }
            root.demoActive = true;
            if (root.pendingDemo) {
                root.previewBusy = true;
                backend.applyPreview(session.sessionId, session.generationId, session.selectedVariant);
                return;
            }
            root.demoBusy = false;
            root.opened = false;
        }
        onDemoOpenFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            root.demoBusy = false;
            root.demoActive = false;
            root.pendingDemo = false;
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
            if (root.pendingCancelAfterDemo) {
                root.pendingCancelAfterDemo = false;
                backend.cancelSession(session.sessionId);
                return;
            }
            if (root.pendingApplyAfterDemo) {
                root.pendingApplyAfterDemo = false;
                const variant = root.pendingApplyVariant;
                const name = root.pendingApplyName;
                root.pendingApplyVariant = "";
                root.pendingApplyName = "";
                backend.applyTheme(
                    session.sessionId,
                    session.generationId,
                    variant,
                    name
                );
                return;
            }
        }
        onDemoCloseFailed: function(message) {
            root.demoBusy = false;
            root.errorMessage = message;
            if (root.pendingCancelAfterDemo) {
                root.pendingCancelAfterDemo = false;
            }
            // Never restore a theme while Demo windows may still be closing.
            // The user can retry Demo shutdown after Hyprland has caught up.
            // Permanent Apply intentionally remains pending for the same reason.
        }
        onThemeApplied: function(sessionId, generationId, variant, themeName) {
            if (root.closeAfterCancel)
                return;
            applyBusy = false
            if (sessionId !== session.sessionId || generationId !== session.generationId) { errorMessage = "Backend applied a different generation"; return }
            root.clearSession()
        }
        onThemeApplyFailed: function(message) {
            if (root.closeAfterCancel)
                return;
            applyBusy = false;
            errorMessage = message;
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
        sourceImage: root.sourceImage
        extraConfigsEnabled: root.extraConfigsEnabled
        errorMessage: root.errorMessage

        onChooseImageRequested: root.chooseImage()
        onSettingsRequested: root.openSettings()
        onExtraConfigsToggled: function(enabled) { root.extraConfigsEnabled = enabled }
        onContinueRequested: root.continueFromSetup()
        onHideRequested: root.close()
    }

    Views.PreviewConfigWindow {
        active: root.opened && root.route === "preview-config"
        busy: root.sessionBusy
        sourceImage: root.sourceImage
        shellStyle: root.shellStyle
        desktopStyle: root.desktopStyle
        onShellStyleSelected: function(style) { root.shellStyle = style }
        onDesktopStyleSelected: function(style) { root.desktopStyle = style }
        barStyle: root.barStyle
        onBarStyleSelected: function(style) { root.barStyle = style }
        onContinueRequested: root.beginSession()
        onBackRequested: root.route = "setup"
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

    Views.WorkspaceWindow {
        active: root.opened && root.route === "workspace" && session.active
        cancelBusy: root.cancelBusy
        sourceImage: root.sourceImage
        shellStyle: root.shellStyle
        sessionId: session.sessionId
        originalTheme: session.originalTheme
        originalBackgroundKind: session.originalBackgroundKind
        originalBackgroundPath: session.originalBackgroundPath
        generationBusy: root.generationBusy || root.describeBusy
        previewBusy: root.previewBusy
        applyBusy: root.applyBusy
        suggestedThemeName: root.suggestedThemeName()
        demoBusy: root.demoBusy
        demoActive: root.demoActive
        workspaceReady: session.workspaceReady
        generationId: session.generationId
        selectedVariant: session.selectedVariant
        previewVariant: session.previewVariant
        palettes: session.palettes
        errorMessage: root.errorMessage

        onVariantSelected: function(variant) { root.selectVariant(variant) }
        onTestLiveRequested: function(variant) { root.testLive(variant) }
        onDemoRequested: function(variant) {
            if (root.demoActive)
                root.dispatchDemo();
            else
                root.demoVariant(variant);
        }
        onHideRequested: root.close()
        onCancelRequested: root.cancelSession()
        onApplyRequested: function(variant, name) { root.applyTheme(variant, name) }
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
