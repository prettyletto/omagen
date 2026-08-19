import QtQuick

QtObject {
    property bool active: false

    property string sessionId: ""
    property string originalTheme: ""
    property string originalBackgroundKind: ""
    property string originalBackgroundPath: ""

    function activate(sessionId, originalTheme, backgroundKind, backgroundPath) {
        this.sessionId = sessionId;
        this.originalTheme = originalTheme;
        this.originalBackgroundKind = backgroundKind;
        this.originalBackgroundPath = backgroundPath;
        this.active = true;
    }

    function clear() {
        active = false;
        sessionId = "";
        originalTheme = "";
        originalBackgroundKind = "";
        originalBackgroundPath = "";
    }
}
