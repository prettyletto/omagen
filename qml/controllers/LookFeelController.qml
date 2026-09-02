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
    property bool saving: false
    property bool catalogLoading: false
    property string catalogError: ""
    property bool resolveApplies: true
    property var catalog: []
    // Look & Feel resolution has one backend command in flight. Keep the
    // latest uncached preset intent so a fast sequence of card clicks is not
    // rejected or allowed to finish on an older recipe.
    property string requestedPreset: ""
    property string activePreset: ""
    property string pendingPreset: ""
    property bool pendingApplies: true
    property bool activeApplies: true
    // Recipes are immutable backend data for the lifetime of the process. A
    // cache makes clicking between presets a local UI operation after the
    // catalog has been resolved once, instead of spawning one CLI request per
    // click.
    property var resolvedCache: ({})

    signal resolved(var composition, bool applies)
    signal presetSaved(var entry)
    signal errorRaised(string message)

    function list() {
        if (root.catalogLoading)
            return
        root.catalogLoading = true
        root.catalogError = ""
        root.backend.listLookFeel()
    }

    function startResolve(preset, applies) {
        root.busy = true
        root.activePreset = String(preset)
        root.activeApplies = applies === true
        root.resolveApplies = root.activeApplies
        root.backend.resolveLookFeel(root.activePreset)
    }

    function requestPreset(preset) {
        if (root.applyBusy || root.cancelBusy)
            return false
        const requested = String(preset || "")
        if (requested === "")
            return false

        root.requestedPreset = requested
        if (root.resolvedCache[requested]) {
            // A cached recipe can be applied immediately even if an older
            // uncached resolver request is still finishing. The old response
            // is rejected below by its preset mismatch.
            root.pendingPreset = ""
            root.resolveApplies = true
            root.resolved(root.cloneComposition(root.resolvedCache[requested]), true)
            return true
        }

        if (root.busy) {
            root.pendingPreset = requested
            root.pendingApplies = true
            return true
        }

        root.startResolve(requested, true)
        return true
    }

    function loadRecipe(preset) {
        if (!preset || preset === "omarchy-native") {
            root.resolveApplies = false
            return false
        }
        const requested = String(preset)
        root.requestedPreset = requested
        if (root.resolvedCache[requested]) {
            root.pendingPreset = ""
            root.resolveApplies = false
            root.resolved(root.cloneComposition(root.resolvedCache[requested]), false)
            return true
        }

        if (root.busy) {
            root.pendingPreset = requested
            root.pendingApplies = false
            return true
        }

        root.startResolve(requested, false)
        return true
    }

    function cloneComposition(composition) {
        return JSON.parse(JSON.stringify(composition))
    }

    function savePreset(name, composition) {
        if (root.saving) {
            root.errorRaised("A Look & Feel preset save is already in progress")
            return false
        }
        if (root.busy || root.previewBusy || root.applyBusy || root.cancelBusy) {
            root.errorRaised("Finish the current Look & Feel operation before saving a preset")
            return false
        }
        var snapshot
        try {
            snapshot = root.cloneComposition(composition || ({}))
        } catch (error) {
            root.errorRaised("Could not prepare the Look & Feel preset for saving")
            return false
        }
        root.saving = true
        root.backend.saveLookFeelPreset(String(name || "").trim(), snapshot)
        return true
    }

    function reset() {
        root.saving = false
        root.busy = false
        root.resolveApplies = true
        root.requestedPreset = ""
        root.activePreset = ""
        root.pendingPreset = ""
        root.pendingApplies = true
        root.activeApplies = true
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
            const responsePreset = composition && composition.preset ? String(composition.preset) : ""
            const activePreset = root.activePreset
            const applies = root.activeApplies

            // BackendCommand does not add request ids to this established
            // signal. The resolved preset is the correlation key, so a stale
            // response cannot replace the latest card selection.
            if (responsePreset !== root.requestedPreset) {
                if (root.pendingPreset !== "") {
                    const nextPreset = root.pendingPreset
                    const nextApplies = root.pendingApplies
                    root.pendingPreset = ""
                    root.startResolve(nextPreset, nextApplies)
                } else {
                    root.busy = false
                    root.activePreset = ""
                }
                return
            }

            root.busy = false
            root.activePreset = ""
            if (composition && composition.preset)
                root.resolvedCache[String(composition.preset)] = root.cloneComposition(composition)
            root.resolved(composition, applies)

            if (root.pendingPreset !== "") {
                const nextPreset = root.pendingPreset
                const nextApplies = root.pendingApplies
                root.pendingPreset = ""
                if (nextPreset !== responsePreset)
                    root.startResolve(nextPreset, nextApplies)
            }
        }

        function onLookFeelResolveFailed(message) {
            const hadNewerIntent = root.pendingPreset !== ""
                    || (root.requestedPreset !== "" && root.requestedPreset !== root.activePreset)
            if (root.pendingPreset !== "") {
                const nextPreset = root.pendingPreset
                const nextApplies = root.pendingApplies
                root.pendingPreset = ""
                root.startResolve(nextPreset, nextApplies)
                return
            }
            root.busy = false
            root.activePreset = ""
            if (!hadNewerIntent)
                root.errorRaised(message)
        }

        function onLookFeelPresetSaved(entry) {
            root.saving = false
            root.presetSaved(entry)
        }

        function onLookFeelPresetSaveFailed(message) {
            root.saving = false
            root.errorRaised(message)
        }
    }
}
