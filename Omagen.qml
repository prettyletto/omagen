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
    property string sourceImage: ""
    property string errorMessage: ""

    readonly property string backendPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen")
            .toString()
            .replace("file://", "")
    )

    function open(payload) {
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

    function saveSettings(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
        settingsBusy = true;
        settings.save(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
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

    function cancelSession() {
        if (!session.active || session.sessionId === "" || cancelBusy)
            return;

        errorMessage = "";
        cancelBusy = true;
        backend.cancelSession(session.sessionId);
    }

    function clearSession() {
        session.clear();
        sessionBusy = false;
        cancelBusy = false;
        sourceImage = "";
        errorMessage = "";
        opened = true;
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
    }

    State.SettingsState {
        id: settingsState
    }

    Services.SettingsService {
        id: settings
        executable: root.backendPath

        onLoaded: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
            settingsWindow.loadValues(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
        }

        onLoadFailed: function(message) {
            settingsBusy = false;
            errorMessage = message;
        }

        onSaved: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
            settingsWindow.loadValues(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
            settingsOpen = false;
        }

        onSaveFailed: function(message) {
            settingsBusy = false;
            errorMessage = message;
        }

        onResetCompleted: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
            settingsBusy = false;
            settingsState.load(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
            settingsWindow.loadValues(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
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
        errorMessage: root.errorMessage

        onHideRequested: root.close()
        onCancelRequested: root.cancelSession()
    }

    Views.SettingsWindow {
        id: settingsWindow
        active: root.settingsOpen
        busy: root.settingsBusy
        harmony: settingsState.harmony
        primaryText: settingsState.primaryText
        brightText: settingsState.brightText
        secondaryText: settingsState.secondaryText
        uiElement: settingsState.uiElement
        selectionText: settingsState.selectionText
        errorMessage: root.errorMessage

        onSaveRequested: function(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
            root.saveSettings(harmony, primaryText, brightText, secondaryText, uiElement, selectionText);
        }
        onResetRequested: root.resetSettings()
        onHideRequested: root.close()
    }
}
