import QtQuick

import "../gateways" as Gateways

Item {
    id: root

    property string executable: ""

    signal sessionBegan(
        string sessionId,
        string originalTheme,
        string backgroundKind,
        string backgroundPath,
        var shellStyle,
        bool extraConfigs,
        var desktopStyle,
        var barStyle,
        var animationsStyle,
        var lookFeel,
        var terminalTranslucency
    )
    signal sessionBeginFailed(string message)
    signal sessionCancelled(string sessionId)
    signal sessionCancelFailed(string message)
    signal sessionResumeChecked(var result)
    signal sessionResumeCheckFailed(string message)
    signal backendReady()
    signal backendUnavailable(string message)
    signal lookFeelCatalogLoaded(var catalog)
    signal lookFeelCatalogFailed(string message)
    signal lookFeelResolved(var composition)
    signal lookFeelResolveFailed(string message)

    signal themeCatalogLoaded(var themes)
    signal themeCatalogFailed(string message)
    signal themeEditOpened(var result)
    signal themeEditOpenFailed(string message)
    signal runtimeStatusLoaded(var status)
    signal runtimeStatusFailed(string message)
    signal runtimeInstalled(string hookPath)
    signal runtimeInstallFailed(string message)
    signal runtimePromptDismissed()
    signal runtimePromptDismissFailed(string message)
    signal sessionRecovered()
    signal sessionRecoverFailed(string message)
    signal generationCompleted(string sessionId, string generationId)
    signal generationFailed(string sessionId, string message)
    signal generationDescribed(string sessionId, string generationId, var variants)
    signal generationDescribeFailed(string sessionId, string message)
    signal generationDiscarded(string sessionId, string generationId)
    signal generationDiscardFailed(string sessionId, string message)
    signal previewApplied(string sessionId, string generationId, string variant, string themeName)
    signal previewApplyFailed(string message)
    signal themeApplied(string sessionId, string generationId, string variant, string themeName)
    signal themeApplyFailed(string message)
    signal demoOpened(string sessionId, string workspace, string monitor, bool reused)
    signal demoOpenFailed(string message)
    signal windowDemoOpened(string sessionId, string workspace, string monitor, bool reused)
    signal windowDemoOpenFailed(string message)
    signal demoReflowed(string sessionId)
    signal demoReflowFailed(string message)
    signal demoClosed(string sessionId, bool closed)
    signal demoCloseFailed(string message)
    signal demoCaptured(string sessionId, string previewPath)
    signal demoCaptureFailed(string message)

    function beginSession(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        sessionGateway.beginSession(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
    }

    function cancelSession(sessionId) {
        sessionGateway.cancelSession(sessionId)
    }
    function checkResumeSession() { sessionGateway.checkResumeSession() }
    function checkBackend() { pingCommand.exec([root.executable, "ping"]) }
    function listLookFeel() { lookFeelGateway.list() }
    function resolveLookFeel(preset) { lookFeelGateway.resolve(preset) }
    function listThemes() { themeGateway.list() }
    function openThemeForEdit(themeId) { themeGateway.openForEdit(themeId) }
    function checkRuntime() { runtimeGateway.check() }
    function installRuntime() { runtimeGateway.install() }
    function dismissRuntimePrompt() { runtimeGateway.dismiss() }
    function recoverSession() { sessionGateway.recoverSession() }

    function generateTheme(sessionId, imagePath, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        generationGateway.generateTheme(sessionId, imagePath, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
    }
    function describeGeneration(sessionId, generationId) {
        generationGateway.describeGeneration(sessionId, generationId)
    }
    function discardGeneration(sessionId, generationId) {
        generationGateway.discardGeneration(sessionId, generationId)
    }
    function applyPreview(sessionId, generationId, variant, colorOverrides, styles) {
        previewGateway.apply(sessionId, generationId, variant, colorOverrides, styles)
    }
    function applyTheme(sessionId, generationId, variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPresetName) {
        applyGateway.apply(sessionId, generationId, variant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPresetName)
    }
    function openDemo(sessionId) { demoGateway.open(sessionId) }
    function openWindowDemo(sessionId) { demoGateway.openWindow(sessionId) }
    function reflowDemo(sessionId) { demoGateway.reflow(sessionId) }
    function closeDemo(sessionId) { demoGateway.close(sessionId) }
    function captureDemoPreview(sessionId) { demoGateway.capture(sessionId) }

    Gateways.BackendCommand {
        id: pingCommand
        failureFallback: "Omagen backend is unavailable"
        invalidJsonFallback: "Backend returned invalid ping JSON"
        onCompleted: function(result) { root.backendReady() }
        onFailed: function(message) { root.backendUnavailable(message) }
    }

    Gateways.SessionGateway {
        id: sessionGateway
        executable: root.executable

        onSessionBegan: function(sessionId, originalTheme, backgroundKind, backgroundPath, shellStyle, extraConfigs, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
            root.sessionBegan(sessionId, originalTheme, backgroundKind, backgroundPath, shellStyle, extraConfigs, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
        }
        onSessionBeginFailed: function(message) { root.sessionBeginFailed(message) }
        onSessionCancelled: function(sessionId) { root.sessionCancelled(sessionId) }
        onSessionCancelFailed: function(message) { root.sessionCancelFailed(message) }
        onSessionResumeChecked: function(result) { root.sessionResumeChecked(result) }
        onSessionResumeCheckFailed: function(message) { root.sessionResumeCheckFailed(message) }
        onSessionRecovered: root.sessionRecovered()
        onSessionRecoverFailed: function(message) { root.sessionRecoverFailed(message) }
    }

    Gateways.GenerationGateway {
        id: generationGateway
        executable: root.executable

        onGenerationCompleted: function(sessionId, generationId) { root.generationCompleted(sessionId, generationId) }
        onGenerationFailed: function(sessionId, message) { root.generationFailed(sessionId, message) }
        onGenerationDescribed: function(sessionId, generationId, variants) { root.generationDescribed(sessionId, generationId, variants) }
        onGenerationDescribeFailed: function(sessionId, message) { root.generationDescribeFailed(sessionId, message) }
        onGenerationDiscarded: function(sessionId, generationId) { root.generationDiscarded(sessionId, generationId) }
        onGenerationDiscardFailed: function(sessionId, message) { root.generationDiscardFailed(sessionId, message) }
    }

    Gateways.LookFeelGateway {
        id: lookFeelGateway
        executable: root.executable

        onCatalogLoaded: function(catalog) { root.lookFeelCatalogLoaded(catalog) }
        onCatalogFailed: function(message) { root.lookFeelCatalogFailed(message) }
        onResolved: function(composition) { root.lookFeelResolved(composition) }
        onResolveFailed: function(message) { root.lookFeelResolveFailed(message) }
    }

    Gateways.ThemeGateway {
        id: themeGateway
        executable: root.executable
        onCatalogLoaded: function(themes) { root.themeCatalogLoaded(themes) }
        onCatalogFailed: function(message) { root.themeCatalogFailed(message) }
        onEditOpened: function(result) { root.themeEditOpened(result) }
        onEditOpenFailed: function(message) { root.themeEditOpenFailed(message) }
    }

    Gateways.RuntimeGateway {
        id: runtimeGateway
        executable: root.executable

        onStatusLoaded: function(status) { root.runtimeStatusLoaded(status) }
        onStatusFailed: function(message) { root.runtimeStatusFailed(message) }
        onInstalled: function(hookPath) { root.runtimeInstalled(hookPath) }
        onInstallFailed: function(message) { root.runtimeInstallFailed(message) }
        onPromptDismissed: root.runtimePromptDismissed()
        onPromptDismissFailed: function(message) { root.runtimePromptDismissFailed(message) }
    }

    Gateways.PreviewGateway {
        id: previewGateway
        executable: root.executable
        onApplied: function(sessionId, generationId, variant, themeName) { root.previewApplied(sessionId, generationId, variant, themeName) }
        onApplyFailed: function(message) { root.previewApplyFailed(message) }
    }

    Gateways.ApplyGateway {
        id: applyGateway
        executable: root.executable
        onApplied: function(sessionId, generationId, variant, themeName) { root.themeApplied(sessionId, generationId, variant, themeName) }
        onApplyFailed: function(message) { root.themeApplyFailed(message) }
    }

    Gateways.DemoGateway {
        id: demoGateway
        executable: root.executable
        onOpened: function(sessionId, workspace, monitor, reused) { root.demoOpened(sessionId, workspace, monitor, reused) }
        onOpenFailed: function(message) { root.demoOpenFailed(message) }
        onWindowOpened: function(sessionId, workspace, monitor, reused) { root.windowDemoOpened(sessionId, workspace, monitor, reused) }
        onWindowOpenFailed: function(message) { root.windowDemoOpenFailed(message) }
        onReflowed: function(sessionId) { root.demoReflowed(sessionId) }
        onReflowFailed: function(message) { root.demoReflowFailed(message) }
        onClosed: function(sessionId, wasClosed) { root.demoClosed(sessionId, wasClosed) }
        onCloseFailed: function(message) { root.demoCloseFailed(message) }
        onCaptured: function(sessionId, previewPath) { root.demoCaptured(sessionId, previewPath) }
        onCaptureFailed: function(message) { root.demoCaptureFailed(message) }
    }

}
