import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Additive decoration for the native Omarchy bar.  It owns no widgets and has
// an empty input region: the native bar remains responsible for all layout,
// drag/reorder behavior, click handling, and popouts.
PanelWindow {
    id: root

    required property QtObject bar
    required property Item anchorItem
    property int geometryTick: 0
    property string omagenBarForm: "continuous"
    property string omagenBarVisibility: "native"
    property bool metadataResolved: false
    property bool profileResolved: false
    property string profileVisibility: "always"
    property string profileReveal: "edge"
    property string profileExpansion: "none"
    property string profileWorkspace: "native"
    property bool specResolved: false
    property var specDocument: null
    property string compiledEngine: ""

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    // Quattro keeps the active theme under this fixed path, independently of
    // XDG_STATE_HOME used by Omagen's own session store.
    readonly property string metadataPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/omagen.bar.toml"
    readonly property string profilePath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/omagen.bar.json"
    readonly property string specPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/omagen.bar.spec.json"
    readonly property string specEngine: root.compiledEngine
    readonly property string specTopology: specDocument && specDocument.topology ? String(specDocument.topology) : ""
    readonly property var specSurface: specDocument && specDocument.surface ? specDocument.surface : ({})
    readonly property var specGeometry: specDocument && specDocument.geometry ? specDocument.geometry : ({})
    readonly property var specBehavior: specDocument && specDocument.behavior ? specDocument.behavior : ({})
    readonly property var specRegions: specDocument && specDocument.regions ? specDocument.regions : ({})
    readonly property bool specAdapter: root.specResolved && root.specEngine === "omagen"
    // Any Omagen compile result may carry adapter-only surface/geometry fields,
    // even when its topology is still continuous. Keep the decoration window
    // alive for those fields instead of silently dropping the staged values.
    readonly property bool specNeedsDecoration: root.specAdapter
    readonly property bool specIslands: root.specAdapter && ["sections", "islands", "split", "notch"].indexOf(root.specTopology) >= 0
    readonly property bool sectionedDecoration: root.specIslands || root.omagenBarVisibility === "islands"
    readonly property bool specAutoHide: root.specAdapter && root.specBehavior.visibility === "auto_hide"
    readonly property real specOpacity: root.specSurface.opacity !== undefined ? Math.max(0, Math.min(1, Number(root.specSurface.opacity))) : 1
    readonly property int specRadius: root.specGeometry.radius !== undefined ? Math.max(0, Number(root.specGeometry.radius)) : 0
    readonly property int specEdgeOffset: root.specGeometry.edge_offset !== undefined ? Math.max(0, Number(root.specGeometry.edge_offset)) : 0
    readonly property int specOuterMargin: root.specGeometry.outer_margin !== undefined ? Math.max(0, Number(root.specGeometry.outer_margin)) : 0
    // Keep already-generated Docked themes working while they migrate from
    // the old shell.bar.toml form key to Omagen-owned metadata.
    readonly property bool legacyDocked: String(Color.shellValues["bar.form"] || "").toLowerCase() === "docked"
    readonly property bool requestedDocked: root.specNeedsDecoration
        ? true
        : root.profileResolved || root.metadataResolved
        ? root.omagenBarForm === "docked"
        : root.legacyDocked
    readonly property bool geometrySupported: {
        return root.bar !== null
            && root.bar.moduleSlots !== undefined
            && typeof root.bar.targetWindow === "function"
            && root.bar.barSize !== undefined
            && root.bar.vertical !== undefined
    }
    readonly property bool docked: root.requestedDocked && root.geometrySupported
    readonly property bool fallbackContinuous: root.requestedDocked && !root.geometrySupported
    // Quattro keeps its PanelWindow alive and slides it off-screen when the
    // top-bar toggle is off. Mirror that public state so this separate
    // decoration window does not remain behind as orphaned islands.
    readonly property bool nativeBarVisible: root.bar && root.bar.barHidden !== true
    // Transparency is still owned by Quattro's native bar gesture/config.
    // Docked only mirrors that state so double-clicking the bar hides the
    // section surfaces exactly as it hides the continuous native surface.
    readonly property bool transparent: root.bar && root.bar.transparent === true
    // Native is the backwards-compatible policy: a transparent Quattro bar
    // also hides this decoration. Islands is an explicit additive opt-in and
    // never changes the native bar's widgets, layout, or input ownership.
    // A staged preset is the source of truth for the preview surface. Do not
    // let a stale native bar.transparent flag make every newly selected
    // preset start invisible; only an explicitly transparent spec hides it.
    readonly property bool showSurface: root.specResolved
        ? root.specOpacity > 0 && String(root.specSurface.role || "background") !== "transparent"
        : !root.transparent || root.omagenBarVisibility === "islands"
    readonly property color surface: {
        if (root.specResolved && root.specAdapter) {
            var role = String(root.specSurface.role || "background")
            if (role === "accent") return Color.accent
            if (role === "selection") return Color.selection
            if (role === "dark") return Qt.darker(Color.background, 1.12)
            if (role === "light") return Color.foreground
            if (role === "transparent") return Color.background
            return Color.background
        }
        var raw = Color.shellValues["bar.background"]
        return raw !== undefined && String(raw).length > 0
            ? Color.flatColor(String(raw), Color.background)
            : Color.background
    }
    readonly property color text: root.bar ? root.bar.barForeground : Color.bar.text
    readonly property color borderColor: root.specResolved && root.specSurface.border_role === "accent" ? Color.accent : root.text
    readonly property real borderOpacity: root.specResolved && root.specSurface.border_opacity !== undefined ? Math.max(0, Math.min(1, Number(root.specSurface.border_opacity))) : 0.28
    // BarSpec geometry is serialized in physical pixels; do not pass it
    // through Style.space, which is the shell's token scale and would magnify
    // a user-entered radius on compact themes.
    readonly property real islandRadius: root.specRadius > 0 ? root.specRadius : Math.max(Style.space(8), Style.cornerRadius)
    readonly property int islandPadding: Math.max(Style.space(5), 5)

    FileView {
        id: omagenBarMetadata
        path: root.metadataPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyMetadata(text())
        // A missing sidecar is not the same as an explicit Continuous value.
        // Keep the legacy shell.bar.toml fallback available for themes that
        // were generated before Omagen moved form metadata to its own file.
        onLoadFailed: {
            root.omagenBarForm = "continuous"
            root.omagenBarVisibility = "native"
            root.metadataResolved = false
        }
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    FileView {
        id: omagenBarSpec
        path: root.specPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applySpec(text())
        onLoadFailed: {
            root.specDocument = null
            root.compiledEngine = ""
            root.specResolved = false
        }
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    FileView {
        id: omagenBarProfile
        path: root.profilePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyProfile(text())
        onLoadFailed: root.profileResolved = false
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            omagenBarMetadata.reload()
            omagenBarProfile.reload()
            omagenBarSpec.reload()
        }
    }

    function applyProfile(raw) {
        try {
            var profile = JSON.parse(String(raw || "{}"))
            if (!profile || profile.schema_version !== 1)
                throw new Error("unsupported bar profile")
            if (String(profile.ownership || "inherit") === "inherit") {
                profileResolved = false
                return
            }
            var behavior = profile.behavior || ({})
            var form = String(behavior.form || "continuous")
            omagenBarForm = form === "continuous" ? "continuous" : "docked"
            omagenBarVisibility = behavior.islands === true || form === "islands" ? "islands" : "native"
            profileVisibility = String(behavior.visibility || "always")
            profileReveal = String(behavior.reveal || "edge")
            profileExpansion = String(behavior.expansion || "none")
            profileWorkspace = String(behavior.workspace || "native")
            profileResolved = true
        } catch (error) {
            profileResolved = false
        }
    }

    function applyMetadata(raw) {
        var text = String(raw || "")
        var formMatch = text.match(/^\s*form\s*=\s*["']([^"']+)["']\s*$/m)
        var visibilityMatch = text.match(/^\s*visibility\s*=\s*["']([^"']+)["']\s*$/m)
        omagenBarForm = formMatch && String(formMatch[1]).toLowerCase() === "docked" ? "docked" : "continuous"
        omagenBarVisibility = visibilityMatch && String(visibilityMatch[1]).toLowerCase() === "islands" ? "islands" : "native"
        metadataResolved = true
    }

    function applySpec(raw) {
        try {
            var compiled = JSON.parse(String(raw || "{}"))
            if (!compiled || !compiled.spec || !compiled.engine)
                throw new Error("unsupported bar spec")
            specDocument = compiled.spec
            compiledEngine = String(compiled.engine)
            specResolved = true
        } catch (error) {
            specDocument = null
            compiledEngine = ""
            specResolved = false
        }
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: (docked || fallbackContinuous)
        && nativeBarVisible
        && anchorWindow !== null
        && bar !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "pretty-omagen-docked-bar"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    anchors {
        top: bar && (bar.position === "top" || bar.vertical)
        bottom: bar && (bar.position === "bottom" || bar.vertical)
        left: bar && (bar.position === "left" || !bar.vertical)
        right: bar && (bar.position === "right" || !bar.vertical)
    }
    // The layer surface must include the edge offset. Otherwise a Floating
    // rectangle translated away from the edge is clipped at native barSize.
    implicitWidth: bar && bar.vertical ? bar.barSize + specEdgeOffset : 0
    implicitHeight: bar && !bar.vertical ? bar.barSize + specEdgeOffset : 0

    // Module geometry changes when widgets load, reveal tray content, move, or
    // switch monitors.  A small decoration-only poll avoids reaching into the
    // native bar's private section components while keeping the islands live.
    Timer {
        interval: 50
        repeat: true
        running: root.visible
        onTriggered: root.geometryTick++
    }

    function sectionBounds(region) {
        if (!root.geometrySupported)
            return root.fullBarBounds()

        var minAxis = Infinity
        var maxAxis = -Infinity
        var found = false
        var slots = root.bar.moduleSlots || []
        for (var i = 0; i < slots.length; i++) {
            var slot = slots[i]
            if (!slot || slot.region !== region || !slot.activeItem || !slot.visible || !slot.activeItem.visible)
                continue
            if (slot.width <= 0 || slot.height <= 0)
                continue

            var slotWindow = root.bar.targetWindow(slot.activeItem) || root.bar.targetWindow(slot)
            if (!slotWindow || slotWindow !== root.anchorWindow)
                continue

            var point = slot.mapToItem(root.anchorWindow.contentItem, 0, 0)
            var start = root.bar.vertical ? point.y : point.x
            var extent = root.bar.vertical ? slot.height : slot.width
            minAxis = Math.min(minAxis, start)
            maxAxis = Math.max(maxAxis, start + extent)
            found = true
        }

        if (!found || !root.screen)
            return { x: 0, y: 0, width: 0, height: 0 }

        var startWithPadding = Math.max(0, minAxis - root.islandPadding - root.specEdgeOffset - root.specOuterMargin)
        var endWithPadding = Math.min(
            root.bar.vertical ? root.screen.height : root.screen.width,
            maxAxis + root.islandPadding + root.specEdgeOffset + root.specOuterMargin
        )
        if (root.bar.vertical) {
            return { x: 0, y: startWithPadding, width: root.bar.barSize, height: Math.max(0, endWithPadding - startWithPadding) }
        }
        return { x: startWithPadding, y: 0, width: Math.max(0, endWithPadding - startWithPadding), height: root.bar.barSize }
    }

    function fullBarBounds() {
        if (!root.screen || !root.bar)
            return { x: 0, y: 0, width: 0, height: 0 }
        var margin = root.specOuterMargin
        var offset = root.specEdgeOffset
        var size = root.bar.barSize
        // Edge offset is the distance from the screen edge; it must move the
        // surface, not consume its thickness. Outer margin constrains the
        // cross-axis length. The previous implementation subtracted the edge
        // offset from barSize, producing a thin strip for Floating (and a
        // partially clipped vertical rail).
        if (root.bar.vertical) {
            // For a right rail the parent is anchored to the right edge; the
            // local x coordinate is therefore the same as for a left rail.
            return { x: offset, y: margin, width: size, height: Math.max(0, root.height - margin * 2) }
        }
        var horizontalY = offset
        return { x: margin, y: horizontalY, width: Math.max(0, root.width - margin * 2), height: size }
    }

    function regionMode(region) {
        var value = root.specRegions[region]
        return value && value.mode ? String(value.mode) : "native"
    }

    Repeater {
        model: root.fallbackContinuous || !root.sectionedDecoration ? ["all"] : ["left", "center", "right"]
        delegate: Rectangle {
            required property string modelData
            readonly property bool wholeBar: modelData === "all"
            readonly property string regionMode: wholeBar ? "native" : root.regionMode(modelData)
            readonly property var bounds: {
                root.geometryTick
                return wholeBar ? root.fullBarBounds() : root.sectionBounds(modelData)
            }

            visible: (root.docked || root.fallbackContinuous) && bounds.width > 0 && bounds.height > 0 && regionMode !== "hidden"
            x: bounds.x
            y: bounds.y
            width: bounds.width
            height: bounds.height
            radius: root.islandRadius
            color: root.showSurface ? Util.alpha(root.surface, (root.specResolved ? root.specOpacity : 1) * (regionMode === "quiet" ? 0.42 : 1)) : "transparent"
            border.width: !root.showSurface || (root.specResolved && root.specSurface.border_role === "none") ? 0 : (regionMode === "island" ? Math.max(1, root.specSurface.border_width !== undefined ? Number(root.specSurface.border_width) : 1) : (root.specSurface.border_width !== undefined ? Math.max(0, Number(root.specSurface.border_width)) : (wholeBar ? 0 : 1)))
            border.color: Util.alpha(root.borderColor, root.borderOpacity)
        }
    }
}
