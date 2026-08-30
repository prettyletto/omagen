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
    property bool catalogLoading: false
    property string catalogError: ""
    property bool resolveApplies: true
    property var catalog: []
    // Recipes are immutable backend data for the lifetime of the process. A
    // cache makes clicking between presets a local UI operation after the
    // catalog has been resolved once, instead of spawning one CLI request per
    // click.
    property var resolvedCache: ({})

    signal resolved(var composition, bool applies)
    signal errorRaised(string message)

    function list() {
        if (root.catalogLoading)
            return
        root.catalogLoading = true
        root.catalogError = ""
        root.backend.listLookFeel()
    }

    function requestPreset(preset) {
        if (root.busy || root.previewBusy || root.applyBusy || root.cancelBusy)
            return false
        if (root.resolvedCache[String(preset)]) {
            root.resolveApplies = true
            root.resolved(root.cloneComposition(root.resolvedCache[String(preset)]), true)
            return true
        }
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
        if (root.resolvedCache[String(preset)]) {
            root.resolveApplies = false
            root.resolved(root.cloneComposition(root.resolvedCache[String(preset)]), false)
            return true
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

    function cloneComposition(composition) {
        return JSON.parse(JSON.stringify(composition))
    }

    Connections {
        target: root.backend

        function onLookFeelCatalogLoaded(catalog) {
            root.catalogLoading = false
            root.catalogError = ""
            root.catalog = catalog
        }

        function onLookFeelCatalogFailed(message) {
            root.catalogLoading = false
            root.catalogError = message
            root.catalog = []
            root.errorRaised(message)
        }

        function onLookFeelResolved(composition) {
            const applies = root.resolveApplies
            root.busy = false
            if (composition && composition.preset)
                root.resolvedCache[String(composition.preset)] = root.cloneComposition(composition)
            root.resolved(composition, applies)
        }

        function onLookFeelResolveFailed(message) {
            root.busy = false
            root.errorRaised(message)
        }
    }
}
