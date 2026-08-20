import QtQuick

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views

Item {
    id: root

    property bool opened: false
    property bool sessionBusy: false
    property bool cancelBusy: false
    property bool settingsOpen: false
    property bool settingsBusy: false
    property bool generationBusy: false
    property bool describeBusy: false
    property bool previewBusy: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool pendingDemo: false
    property bool pendingCancelAfterDemo: false
    property bool pendingApplyAfterDemo: false
    property string sourceImage: ""
    property string errorMessage: ""

    readonly property string backendPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen")
            .toString()
            .replace("file://", "")
    )

    function open(payload) {
        root.errorMessage = "";
        opened = true;
    }

    function close() {
        opened = false;
        settingsOpen = false;
    }

    function openSettings() {
        if (sessionBusy || cancelBusy)
            return;

        errorMessage = "";
        settingsOpen = true;
        settingsBusy = true;
        settings.get();
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
        backend.beginSession();
    }

    function selectVariant(variant) { if (!previewBusy && !cancelBusy && !demoBusy) session.selectVariant(variant) }
    function testLive(variant) {
        if (!session.workspaceReady || previewBusy || cancelBusy || demoBusy) return;
        errorMessage = ""; previewBusy = true;
        backend.applyPreview(session.sessionId, session.generationId, variant);
    }

    function demoVariant(variant) {
        if (demoActive || demoBusy || previewBusy || cancelBusy || !session.workspaceReady)
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
        if (!session.active || session.sessionId === "" || cancelBusy || demoBusy)
            return;

        errorMessage = "";
        cancelBusy = true;
        demoBusy = true;
        pendingCancelAfterDemo = true;
        backend.closeDemo(session.sessionId);
    }

    function clearSession() {
        session.clear();
        sessionBusy = false;
        cancelBusy = false;
        sourceImage = "";
        errorMessage = "";
        opened = true;
        generationBusy = false;
        describeBusy = false;
        previewBusy = false;
        demoBusy = false;
        demoActive = false;
        pendingDemo = false;
        pendingCancelAfterDemo = false;
        pendingApplyAfterDemo = false;
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
            backgroundPath
        ) {
            root.sessionBusy = false;
            session.activate(
                sessionId,
                originalTheme,
                backgroundKind,
                backgroundPath
            );
            root.generationBusy = true;
            backend.generateTheme(sessionId, root.sourceImage);
        }

        onSessionBeginFailed: function(message) {
            root.sessionBusy = false;
            root.errorMessage = message;
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
            root.errorMessage = message;
        }

        onGenerationCompleted: function(generationId) {
            root.generationBusy = false;
            root.describeBusy = true;
            backend.describeGeneration(session.sessionId, generationId);
        }
        onGenerationFailed: function(message) { root.generationBusy=false; root.errorMessage=message }
        onGenerationDescribed: function(generationId, variants) { root.describeBusy=false; session.setGeneration(generationId, variants) }
        onGenerationDescribeFailed: function(message) { root.describeBusy=false; root.errorMessage=message }
        onPreviewApplied: function(sessionId, generationId, variant, themeName) {
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
            root.previewBusy = false;
            root.errorMessage = message;
            if (root.pendingDemo) {
                root.pendingDemo = false;
                root.demoBusy = false;
            }
        }
        onDemoOpened: function(sessionId, workspace, reused) {
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
                root.commitSelectedVariant();
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
            settingsOpen = false;
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
        active: root.opened && !session.active && !root.settingsOpen
        busy: root.sessionBusy
        sourceImage: root.sourceImage
        errorMessage: root.errorMessage

        onChooseImageRequested: root.chooseImage()
        onSettingsRequested: root.openSettings()
        onContinueRequested: root.beginSession()
        onHideRequested: root.close()
    }

    Views.WorkspaceWindow {
        active: root.opened && session.active
        cancelBusy: root.cancelBusy
        sourceImage: root.sourceImage
        sessionId: session.sessionId
        originalTheme: session.originalTheme
        originalBackgroundKind: session.originalBackgroundKind
        originalBackgroundPath: session.originalBackgroundPath
        generationBusy: root.generationBusy || root.describeBusy
        previewBusy: root.previewBusy
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
    }

    Views.SettingsWindow {
        id: settingsWindow
        active: root.opened && !session.active && root.settingsOpen
        busy: root.settingsBusy
        errorMessage: root.errorMessage

        onSaveRequested: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
            root.saveSettings(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi);
        }
        onResetRequested: root.resetSettings()
        onCloseRequested: {
            if (root.settingsBusy)
                return;
            root.settingsOpen = false;
            root.errorMessage = "";
        }
    }
}
