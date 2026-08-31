import QtQuick

// Coordinates installed-theme discovery and adoption. The backend owns the
// snapshot and session transaction; this controller only owns UI busy state.
Item {
    id: root
    property var backend: null
    property bool catalogLoading: false
    property bool opening: false
    property int operationEpoch: 0
    property int openingOperationEpoch: 0
    property var themes: []

    signal opened(var result)
    signal errorRaised(string message)

    function list() {
        if (root.catalogLoading || root.opening)
            return
        root.catalogLoading = true
        root.backend.listThemes()
    }

    function open(themeId) {
        if (root.catalogLoading || root.opening || !themeId)
            return
        root.operationEpoch += 1
        root.openingOperationEpoch = root.operationEpoch
        root.opening = true
        root.backend.openThemeForEdit(String(themeId))
    }

    function reset() {
        root.operationEpoch += 1
        root.catalogLoading = false
        root.opening = false
    }

    Connections {
        target: root.backend

        function onThemeCatalogLoaded(themes) {
            root.catalogLoading = false
            root.themes = themes
        }
        function onThemeCatalogFailed(message) {
            root.catalogLoading = false
            root.errorRaised(message)
        }
        function onThemeEditOpened(result) {
            if (!root.opening || root.openingOperationEpoch !== root.operationEpoch)
                return
            root.opening = false
            root.opened(result)
        }
        function onThemeEditOpenFailed(message) {
            if (!root.opening || root.openingOperationEpoch !== root.operationEpoch)
                return
            root.opening = false
            root.errorRaised(message)
        }
    }
}
