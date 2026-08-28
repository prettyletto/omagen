import QtQuick

// Owns Look & Feel catalog/resolution requests. The composition root still
// merges the resolved recipe with customized Window/Shell/Bar/Animation and
// Terminal documents because that is a cross-domain document operation.
Item {
    id: root

    property var backend: null
    property bool extraConfigsEnabled: false
    property bool previewBusy: false
    property bool applyBusy: false
    property bool cancelBusy: false

    property bool busy: false
    property bool resolveApplies: true
    property var catalog: []

    signal resolved(var composition, bool applies)
    signal errorRaised(string message)

    function list() {
        root.backend.listLookFeel()
    }

    function requestPreset(preset) {
        if (root.busy || root.previewBusy || root.applyBusy || root.cancelBusy)
            return false
        root.busy = true
        root.resolveApplies = true
        root.backend.resolveLookFeel(preset)
        return true
    }

    function loadRecipe(preset) {
        if (!preset || preset === "omarchy-native") {
            root.resolveApplies = false
            return false
        }
        root.resolveApplies = false
        root.busy = true
        root.backend.resolveLookFeel(preset)
        return true
    }

    function reset() {
        root.busy = false
        root.resolveApplies = true
    }

    Connections {
        target: root.backend

        function onLookFeelCatalogLoaded(catalog) {
            root.catalog = catalog
        }

        function onLookFeelCatalogFailed(message) {
            root.catalog = []
            if (root.extraConfigsEnabled)
                root.errorRaised(message)
        }

        function onLookFeelResolved(composition) {
            const applies = root.resolveApplies
            root.busy = false
            root.resolved(composition, applies)
        }

        function onLookFeelResolveFailed(message) {
            root.busy = false
            root.errorRaised(message)
        }
    }
}
