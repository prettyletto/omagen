import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Compatibility decoration for themes generated before Docked became a
// native Omarchy bar form. New themes never activate this separate layer:
// unsupported shells stay continuous and retain every real module.
PanelWindow {
    id: root

    required property QtObject bar
    required property Item anchorItem
    property int geometryTick: 0
    property string omagenBarForm: "continuous"
    property bool metadataResolved: false

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    // Quattro keeps the active theme under this fixed path, independently of
    // XDG_STATE_HOME used by Omagen's own session store.
    readonly property string metadataPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/omagen.bar.toml"
    // Keep already-generated Docked themes working while they migrate from
    // the old shell.bar.toml form key to Omagen-owned metadata.
    readonly property bool legacyDocked: String(Color.shellValues["bar.form"] || "").toLowerCase() === "docked"
    readonly property bool requestedDocked: root.metadataResolved
        ? root.omagenBarForm === "docked"
        : root.legacyDocked
    readonly property bool nativeDockedSupported: root.bar && root.bar.supportsDockedSurface === true
    // Older generated themes made the native bar transparent and therefore
    // still need this renderer. New themes only write `form = "docked"`;
    // old shells ignore that key and safely retain their continuous bar.
    readonly property bool legacyTransparentTheme: Number(Color.shellValues["bar.background-alpha"]) === 0
    readonly property bool legacyDecorationActive: root.requestedDocked
        && root.legacyTransparentTheme
        && !root.nativeDockedSupported
    readonly property bool geometrySupported: {
        return root.bar !== null
            && root.bar.moduleSlots !== undefined
            && typeof root.bar.targetWindow === "function"
            && root.bar.barSize !== undefined
            && root.bar.vertical !== undefined
    }
    readonly property bool docked: root.legacyDecorationActive && root.geometrySupported
    readonly property bool fallbackContinuous: root.legacyDecorationActive && !root.geometrySupported
    // Transparency is still owned by Quattro's native bar gesture/config.
    // Docked only mirrors that state so double-clicking the bar hides the
    // section surfaces exactly as it hides the continuous native surface.
    readonly property bool transparent: root.bar && root.bar.transparent === true
    readonly property color surface: {
        var raw = Color.shellValues["bar.background"]
        return raw !== undefined && String(raw).length > 0
            ? Color.flatColor(String(raw), Color.background)
            : Color.background
    }
    readonly property color text: root.bar ? root.bar.barForeground : Color.bar.text
    readonly property real islandRadius: Math.max(Style.space(8), Style.cornerRadius)
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
            root.metadataResolved = false
        }
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: omagenBarMetadata.reload()
    }

    function applyMetadata(raw) {
        var match = String(raw || "").match(/^\s*form\s*=\s*["']([^"']+)["']\s*$/m)
        omagenBarForm = match && String(match[1]).toLowerCase() === "docked" ? "docked" : "continuous"
        metadataResolved = true
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: (docked || fallbackContinuous) && anchorWindow !== null && bar !== null
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
    implicitWidth: bar && bar.vertical ? bar.barSize : 0
    implicitHeight: bar && !bar.vertical ? bar.barSize : 0

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

        var startWithPadding = Math.max(0, minAxis - root.islandPadding)
        var endWithPadding = Math.min(
            root.bar.vertical ? root.screen.height : root.screen.width,
            maxAxis + root.islandPadding
        )
        if (root.bar.vertical) {
            return { x: 0, y: startWithPadding, width: root.bar.barSize, height: Math.max(0, endWithPadding - startWithPadding) }
        }
        return { x: startWithPadding, y: 0, width: Math.max(0, endWithPadding - startWithPadding), height: root.bar.barSize }
    }

    function fullBarBounds() {
        if (!root.screen || !root.bar)
            return { x: 0, y: 0, width: 0, height: 0 }
        if (root.bar.vertical)
            return { x: 0, y: 0, width: root.bar.barSize, height: root.screen.height }
        return { x: 0, y: 0, width: root.screen.width, height: root.bar.barSize }
    }

    Repeater {
        model: root.fallbackContinuous ? ["all"] : ["left", "center", "right"]
        delegate: Rectangle {
            required property string modelData
            readonly property bool wholeBar: modelData === "all"
            readonly property var bounds: {
                root.geometryTick
                return wholeBar ? root.fullBarBounds() : root.sectionBounds(modelData)
            }

            visible: (root.docked || root.fallbackContinuous) && bounds.width > 0 && bounds.height > 0
            x: bounds.x
            y: bounds.y
            width: bounds.width
            height: bounds.height
            radius: wholeBar ? 0 : root.islandRadius
            color: root.transparent ? "transparent" : root.surface
            border.width: wholeBar || root.transparent ? 0 : 1
            border.color: Util.alpha(root.text, 0.28)
        }
    }
}
