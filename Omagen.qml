import QtQuick

import "qml/services" as Services
import "qml/state" as State
import "qml/views" as Views

Item {
    id: root

    property bool opened: false
    property bool sessionBusy: false
    property bool cancelBusy: false
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

    Views.SetupWindow {
        active: root.opened && !session.active
        busy: root.sessionBusy
        sourceImage: root.sourceImage
        errorMessage: root.errorMessage

        onChooseImageRequested: root.chooseImage()
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
}
