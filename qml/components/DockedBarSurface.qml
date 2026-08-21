import QtQuick
import Quickshell
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

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property bool docked: {
        var value = Color.shellValues["bar.form"]
        return String(value || "continuous").toLowerCase() === "docked"
    }
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

    screen: anchorWindow ? anchorWindow.screen : null
    visible: docked && anchorWindow !== null && bar !== null
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
        var minAxis = Infinity
        var maxAxis = -Infinity
        var found = false
        var slots = root.bar ? root.bar.moduleSlots : []
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

    Repeater {
        model: ["left", "center", "right"]
        delegate: Rectangle {
            required property string modelData
            readonly property var bounds: {
                root.geometryTick
                return root.sectionBounds(modelData)
            }

            visible: root.docked && bounds.width > 0 && bounds.height > 0
            x: bounds.x
            y: bounds.y
            width: bounds.width
            height: bounds.height
            radius: root.islandRadius
            color: root.transparent ? "transparent" : root.surface
            border.width: root.transparent ? 0 : 1
            border.color: Util.alpha(root.text, 0.28)
        }
    }
}
