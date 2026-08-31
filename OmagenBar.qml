import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "bar/BarSizing.js" as BarSizing

// Shared Omagen bar runtime. Visual compositions live in bar/presets/*.qml;
 // this file owns the injected host contract, runtime readers, and shared
 // interaction state.
 // Full bar option for layouts that Quattro's native bar cannot express.
// The host owns only the surface/layout shell; every widget is still created
// from Quattro's injected BarWidgetRegistry and receives the same bar,
// moduleName, and settings contract as the built-in Bar.qml.
Item {
    id: root

    // Plugin bars are created by Quattro's Loader and receive these values in
    // its onLoaded injection pass. Defaults are intentional: QML required
    // properties are checked before that pass and would make a valid plugin
    // bar fail to instantiate.
    property string omarchyPath: ""
    property var barWidgetRegistry: ({})
    property var barConfig: ({})
    property var shell: null
    property var manifest: null

    property string home: Quickshell.env("HOME")
    property string omarchyConfigDir: root.home + "/.config/omarchy"
    property string stateHome: {
        var configured = Quickshell.env("XDG_STATE_HOME")
        return configured && configured.length > 0 ? configured : root.home + "/.local/state"
    }
    property var specDocument: ({})
    property var profileDocument: ({})
    property bool profileResolved: false
    property bool barHidden: false
    // Full replacement bars park their own surface for auto-hide. Quattro's
    // global bar-off marker remains reserved for the user's manual toggle.
    property bool autoHideHidden: false
    property int autoHideRevealHoverCount: 0
    property bool forceOpaqueAfterMove: false
    property int hoverCount: 0
    property bool barHovered: false
    property int glitchEpoch: 0
    property double lastGlitchAt: 0
    property var moduleSlots: []
    property var activePopout: null
    property var barDragSource: null
    property var barDragTarget: null
    property bool barDragAfter: false
    property real barDragSceneX: 0
    property real barDragSceneY: 0
    property bool barMoveActive: false
    property string barMoveCandidate: ""
    property var barMoveWindow: null
    property var barMoveScreen: null
    property color themeForeground: Color.bar.text
    property color themeContrastForeground: Color.background
    property color transparentForeground: Color.bar.text
    // Keep the legacy `bar.foreground` consumer contract contrast-aware in
    // replacement bars too. Quattro's native WidgetButton reads
    // `bar.barForeground`, but a few platform widgets (notably the tray)
    // still read `bar.foreground`; leaving this static would make those
    // widgets diverge only when a replacement surface is translucent.
    property color foreground: barForeground
    property color barForeground: useTransparentForeground ? transparentForeground : themeForeground
    property bool foregroundAnimationEnabled: true
    property color background: Color.bar.background
    property color urgent: Color.bar.active
    property string fontFamily: Style.font.family
    property bool transparent: false
    property bool requestedTransparent: false
    // shell.json may retain the last native-bar transparency choice. Do not
    // use that persisted value as the initial state of a newly loaded Omagen
    // bar; transparency is an explicit runtime double-click action.
    property bool transparencyInteractionActive: false
    property bool useTransparentForeground: false
    property bool centerHoverRevealSuppressed: false
    property bool centerSectionRevealHeld: false
    property int centerSectionHoverCount: 0
    property bool centerSectionHovered: false
    // Keep the same host contract as Quattro's native Bar.qml. WidgetButton
    // registers its real hit target here so a replacement slot can route
    // clicks and cursor shape without stealing the widget's own semantics.
    property var clickTargets: []
    property var tooltipTarget: null
    property var pendingTooltipTarget: null
    property string tooltipText: ""
    property string pendingTooltipText: ""
    property bool tooltipShown: false
    property int tooltipRequest: 0
    // Lets the Omagen bar widget avoid mounting its old additive surface when
    // it is hosted inside this replacement bar.
    readonly property bool replacementHost: true

    readonly property string position: root.normalizePosition(barConfig && barConfig.position)
    readonly property bool vertical: position === "left" || position === "right"
    // Quattro keeps the configured center anchor (normally the clock) fixed
    // at the monitor midpoint and lays the other center widgets around it.
    // Preserve that contract in the Default/continuous replacement instead
    // of centering a single row whose visual midpoint moves with content.
    readonly property string centerAnchor: root.entryId(barConfig && barConfig.centerAnchor
        ? barConfig.centerAnchor : "omarchy.clock")
    // All bar presets share the full edge-span interaction host used by drag:
    // the complete top/bottom strip or left/right rail is the hover and click
    // zone, even when the visual surface is currently compact.
    readonly property var layoutConfig: root.normalizedLayout(barConfig && barConfig.layout)
    readonly property var spec: root.specDocument && root.specDocument.spec ? root.specDocument.spec : ({})
    readonly property var workspaceSpec: root.spec.workspace && typeof root.spec.workspace === "object"
        ? root.spec.workspace : ({})
    readonly property string workspaceMode: String(root.workspaceSpec.mode || "native")
    readonly property var clockSpec: root.spec.clock && typeof root.spec.clock === "object"
        ? root.spec.clock : ({})
    readonly property string clockStyle: root.normalizeClockStyle(root.clockSpec.style)
    readonly property var dockSpec: root.spec.dock && typeof root.spec.dock === "object"
        ? root.spec.dock : ({})
    readonly property string dockClosedContent: root.normalizeDockClosedContent(root.dockSpec.closed)
    readonly property string dockClosedGlyph: root.normalizeDockGlyph(root.dockSpec.glyph)
    // The replacement bar always renders Omagen's workspace widget. Its
    // `native` mode is a faithful clone of Quattro's normal presentation, while
    // the other modes change labels only; Hyprland still owns state and
    // dispatch in every case.
    readonly property bool workspacePresentationActive: true
    readonly property bool cyberpunkSignalEnabled: String(root.spec.motion && root.spec.motion.preset || "") === "cyberpunk"
    readonly property string topology: String(root.spec.topology || "continuous")
    readonly property bool floatingExpanded: root.topology === "floating" && String(root.spec.preset || "") === "float-expanded"
    readonly property bool dock: root.topology === "dock"
    // Keep the Dock expanded after a widget click hands ownership to its
    // QML popup. Hover can end while the popup is open, but the bar must stay
    // visible beneath that panel until the popup coordinator releases it.
    readonly property bool dockExpanded: root.dock
        && (root.barHovered || (root.activePopout !== null && root.activePopout !== undefined))
    // Minimal uses the same popup ownership contract as Dock. Keep its full
    // widget row visible while a popup is open even after the pointer moves
    // into that popup or the application surface.
    readonly property bool minimalExpanded: root.topology === "minimal"
        && (root.barHovered || (root.activePopout !== null && root.activePopout !== undefined))
    readonly property int dockCollapsedExtent: Math.max(root.barSize, Style.space(48))
    // Dock has its own visual cross-axis padding, but it must still preserve
    // the user's Compact/Default/Comfortable size choice. A fixed minimum
    // erased those differences because every preset was below 44px.
    readonly property int dockThickness: root.barSize + Style.space(16)
    readonly property var geometrySpec: root.spec.geometry && typeof root.spec.geometry === "object" ? root.spec.geometry : ({})
    readonly property var surfaceSpec: root.spec.surface && typeof root.spec.surface === "object" ? root.spec.surface : ({})
    readonly property var behaviorSpec: root.spec.behavior && typeof root.spec.behavior === "object" ? root.spec.behavior : ({})
    readonly property var regionsSpec: root.spec.regions && typeof root.spec.regions === "object" ? root.spec.regions : ({})
    readonly property var motionSpec: root.spec.motion && typeof root.spec.motion === "object" ? root.spec.motion : ({})
    readonly property string density: String(root.geometrySpec.density || "native")
    readonly property int barSize: {
        return BarSizing.resolvedBaseSize(
            root.spec,
            Style.bar.sizeHorizontal,
            Style.bar.sizeVertical,
            Style.barScaleWithFont,
            Style.fontScale
        )
    }
    // Islands need a little breathing room around the native vertical slot
    // width. The slot itself remains barSize-wide so widget contracts and
    // drag hit regions stay unchanged.
    readonly property int islandThickness: root.barSize + Style.space(16)
    // Float Compact stays content-sized on every edge. Horizontal and
    // vertical are two orientations of the same compact preset.
    readonly property bool floatingCompact: root.topology === "floating" && root.density === "compact"
    readonly property string alignment: String(root.spec.geometry && root.spec.geometry.alignment || "center")
    readonly property string visibility: String(root.spec.behavior && root.spec.behavior.visibility || "always")
    readonly property bool autoHide: root.visibility === "auto_hide"
    readonly property int autoHideDelayMs: 5000
    readonly property bool autoHideRevealHovered: root.autoHideRevealHoverCount > 0
    readonly property bool autoHidePopupOpen: root.behaviorSpec.keep_visible_while_popup_open !== false
        && root.activePopout !== null && root.activePopout !== undefined
    // The Default workspace clone is deliberately narrow: when the surface,
    // geometry, and behavior are native, render the actual Quattro Bar.qml
    // source and override only omarchy.workspaces plus the optional Omagen
    // clock face. This keeps the platform's surface, spacing, tray drawer,
    // drag/reorder, popups, and center-anchor behavior aligned with native.
    readonly property bool nativeDefaultClone: root.topology === "continuous"
        && root.position === "top"
        && String(root.surfaceSpec.role || "native") === "native"
        && Number(root.surfaceSpec.opacity !== undefined ? root.surfaceSpec.opacity : 1) === 1
        && Number(root.surfaceSpec.blur || 0) === 0
        && String(root.surfaceSpec.border_role || "none") === "none"
        && Number(root.surfaceSpec.border_opacity || 0) === 0
        && Number(root.surfaceSpec.border_width || 0) === 0
        && String(root.surfaceSpec.shadow || "none") === "none"
        && root.density === "native"
        && Number(root.geometrySpec.thickness || 0) === 0
        && Number(root.geometrySpec.edge_offset || 0) === 0
        && Number(root.geometrySpec.outer_margin || 0) === 0
        && Number(root.geometrySpec.inner_padding || 0) === 0
        && Number(root.geometrySpec.section_gap !== undefined ? root.geometrySpec.section_gap : 8) === 8
        && Number(root.geometrySpec.widget_gap || 0) === 0
        && Number(root.geometrySpec.radius || 0) === 0
        && String(root.geometrySpec.length_mode || "full") === "full"
        && Number(root.geometrySpec.length_value || 0) === 0
        && String(root.geometrySpec.alignment || "center") === "center"
        && String(root.behaviorSpec.visibility || "always") === "always"
        && String(root.behaviorSpec.exclusive_zone || "reserve") === "reserve"
        && root.behaviorSpec.hover_expand !== true
        && (!root.regionsSpec.left || String(root.regionsSpec.left.mode || "native") === "native")
        && (!root.regionsSpec.center || String(root.regionsSpec.center.mode || "native") === "native")
        && (!root.regionsSpec.right || String(root.regionsSpec.right.mode || "native") === "native")
        && String(root.motionSpec.preset || "native") === "native"
        && Number(root.motionSpec.duration_ms !== undefined ? root.motionSpec.duration_ms : 180) === 180
        && String(root.motionSpec.easing || "out_cubic") === "out_cubic"
    readonly property bool replacementGeometry: ["floating", "sections", "islands", "dock", "split", "notch", "rail"].indexOf(root.topology) >= 0
    readonly property bool contentSized: !root.floatingExpanded && (["floating", "dock", "islands", "split", "notch"].indexOf(root.topology) >= 0 || String(root.spec.geometry && root.spec.geometry.length_mode || "full") === "content")
    readonly property int edgeOffset: Math.max(0, Number(root.spec.geometry && root.spec.geometry.edge_offset || 0))
    readonly property int outerMargin: Math.max(0, Number(root.spec.geometry && root.spec.geometry.outer_margin || 0))
    readonly property int radius: Math.max(0, Number(root.spec.geometry && root.spec.geometry.radius || 0))
    readonly property string surfaceTreatment: String(root.spec.surface && root.spec.surface.treatment || "preset")
    // Preset and explicit opaque bars are solid surfaces. Glass/clear/metal
    // remain available as intentional translucent choices, but the normal
    // Test Live preset must not inherit the old 0.9 alpha and show the desktop
    // through the bar.
    readonly property real surfaceOpacity: root.surfaceTreatment === "preset" || root.surfaceTreatment === "opaque"
        ? 1
        : (root.spec.surface && root.spec.surface.opacity !== undefined ? Math.max(0, Math.min(1, Number(root.spec.surface.opacity))) : 1)
    readonly property string rawBarBackground: String(Color.shellValues["bar.background"] || "")
    // The native host is intentionally hidden with bar.background-alpha while
    // a replacement is active. Read the raw compiled colour here so Omagen's
    // visible surface still receives the staged Bar colour without inheriting
    // that native-host alpha suppression.
    readonly property color surfaceColor: root.rawBarBackground !== ""
        ? Color.flatColor(root.rawBarBackground, Color.background)
        : root.surfaceFor(String(root.spec.surface && root.spec.surface.role || "native"))
    // Non-native bars intentionally set the native shell bar alpha to zero so
    // the old host does not paint underneath them. A replacement island still
    // needs an opaque fill when its surface role is "native".
    readonly property color replacementSurfaceColor: root.surfaceColor
    readonly property color borderColor: String(root.spec.surface && root.spec.surface.border_role || "none") === "accent" ? Color.accent : Color.foreground
    readonly property real borderOpacity: root.spec.surface && root.spec.surface.border_opacity !== undefined ? Math.max(0, Math.min(1, Number(root.spec.surface.border_opacity))) : 0
    readonly property int borderWidth: root.spec.surface && root.spec.surface.border_width !== undefined ? Math.max(0, Number(root.spec.surface.border_width)) : 0

    Behavior on barForeground {
        enabled: root.foregroundAnimationEnabled
        ColorAnimation { duration: 420; easing.type: Easing.InOutCubic }
    }

    signal barConfigChangedExternally()

    onBarConfigChanged: root.syncRequestedTransparency()
    onForceOpaqueAfterMoveChanged: root.syncRequestedTransparency()
    onRequestedTransparentChanged: root.scheduleTransparentForegroundRefresh()
    onPositionChanged: root.scheduleTransparentForegroundRefresh()
    onBarSizeChanged: root.scheduleTransparentForegroundRefresh()
    onThemeForegroundChanged: root.scheduleTransparentForegroundRefresh()
    onThemeContrastForegroundChanged: root.scheduleTransparentForegroundRefresh()
    onBarHiddenChanged: root.syncAutoHide()
    onBarHoveredChanged: {
        root.syncAutoHide()
        // Indicator clicks can move an item from the inactive block into the
        // active block while the center row is being rebuilt. Keep the
        // center reveal held for the whole bar-hover lifetime so that active
        // items such as coffee remain in the click path during that move.
        root.centerSectionRevealHeld = root.barHovered
    }
    onActivePopoutChanged: root.syncAutoHide()
    onVisibilityChanged: root.syncAutoHide()
    Component.onCompleted: {
        root.syncRequestedTransparency()
        root.syncAutoHide()
    }

    function triggerCyberpunkSignal(eventName) {
        if (!root.cyberpunkSignalEnabled)
            return
        const now = Date.now()
        // A window opening produces an immediate focus event too. Render one
        // deliberate signal rather than two jittery ones.
        if (now - root.lastGlitchAt < 520)
            return
        root.lastGlitchAt = now
        root.glitchEpoch += 1
    }

    // Match Quattro's center-indicator ownership. The indicators widget
    // reveals inactive entries (recording, coffee/stay-awake, night light,
    // etc.) while the pointer is in the center section. Keep that reveal held
    // while the row widens so the newly exposed item cannot move away before
    // its click is delivered.
    function setCenterSectionHovered(hovered) {
        root.centerSectionHoverCount = Math.max(0,
            root.centerSectionHoverCount + (hovered ? 1 : -1))
        root.centerSectionHovered = root.centerSectionHoverCount > 0
        if (root.centerSectionHovered) {
            centerSectionRevealTimer.stop()
            root.centerSectionRevealHeld = true
        } else {
            centerSectionRevealTimer.restart()
        }
    }

    Timer {
        id: centerSectionRevealTimer
        interval: 120
        onTriggered: {
            if (!root.centerSectionHovered && !root.barHovered)
                root.centerSectionRevealHeld = false
        }
    }

    function showAutoHideBar() {
        root.autoHideHidden = false
    }

    function hideAutoHideBar() {
        if (!root.autoHide || root.barHidden || root.autoHideHidden || root.barHovered || root.autoHideRevealHovered || root.autoHidePopupOpen)
            return
        root.autoHideHidden = true
    }

    function syncAutoHide() {
        if (!root.autoHide) {
            autoHideTimer.stop()
            root.showAutoHideBar()
            return
        }
        if (root.barHidden || root.autoHideHidden || root.barHovered || root.autoHideRevealHovered || root.autoHidePopupOpen) {
            autoHideTimer.stop()
            return
        }
        autoHideTimer.restart()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = String(event.name || "")
            if (name === "openwindow" || name === "closewindow" || name === "urgent"
                    || name === "workspace" || name === "workspacev2")
                root.triggerCyberpunkSignal(name)
        }
    }

    function normalizePosition(value) {
        var next = String(value || "top")
        return ["top", "bottom", "left", "right"].indexOf(next) >= 0 ? next : "top"
    }

    function normalizeClockStyle(value) {
        var next = String(value || "native").toLowerCase()
        return ["native", "neon", "matrix", "lcd", "classical", "gothic"].indexOf(next) >= 0 ? next : "native"
    }

    function normalizeDockClosedContent(value) {
        var next = String(value || "ellipsis").toLowerCase()
        return ["workspace", "ellipsis", "clock", "glyph"].indexOf(next) >= 0 ? next : "ellipsis"
    }

    function normalizeDockGlyph(value) {
        var glyph = Array.from(String(value || "✦")).slice(0, 4).join("")
        return glyph.length > 0 ? glyph : "✦"
    }

    function normalizedLayout(layout) {
        var source = layout && typeof layout === "object" ? layout : ({})
        return {
            left: Array.isArray(source.left) ? source.left : [],
            center: Array.isArray(source.center) ? source.center : [],
            right: root.topology === "continuous"
                ? (Array.isArray(source.right) ? source.right : [])
                : root.placeTrayAtOuterEdge(Array.isArray(source.right) ? source.right : [], "right")
        }
    }

    // The replacement bar keeps the tray at the outside edge of the right
    // section. The native bar pins it to the inner edge because its drawer is
    // designed to reveal inward; in this host the user-facing contract is a
    // far-right tray, so put the complete tray block after the other widgets.
    function placeTrayAtOuterEdge(entries, section) {
        var trayEntry = null
        var result = []
        var values = Array.isArray(entries) ? entries : []
        for (var i = 0; i < values.length; i++) {
            if (root.entryId(values[i]) === "omarchy.tray") trayEntry = values[i]
            else result.push(values[i])
        }
        if (trayEntry) result.push(trayEntry)
        return result
    }

    function entryId(entry) {
        if (typeof entry === "string") return entry
        return entry && entry.id !== undefined ? String(entry.id) : ""
    }

    function entryIndex(entries, name) {
        var values = Array.isArray(entries) ? entries : []
        var target = String(name || "")
        for (var i = 0; i < values.length; i++)
            if (root.entryId(values[i]) === target) return i
        return -1
    }

    function entriesBefore(entries, name) {
        var values = Array.isArray(entries) ? entries : []
        var index = root.entryIndex(values, name)
        return index < 0 ? [] : values.slice(0, index)
    }

    function entriesAfter(entries, name) {
        var values = Array.isArray(entries) ? entries : []
        var index = root.entryIndex(values, name)
        return index < 0 ? [] : values.slice(index + 1)
    }

    function entryNamed(entries, name) {
        var values = Array.isArray(entries) ? entries : []
        var index = root.entryIndex(values, name)
        return index < 0 ? null : values[index]
    }

    function entrySettings(entry) {
        var result = ({})
        if (!entry || typeof entry !== "object") return result
        for (var key in entry) if (key !== "id") result[key] = entry[key]

        // The native clock falls back to a date-plus-time label. Omagen's bar
        // contract starts compact and exposes the date label only through the
        // clock's explicit right-click toggle. Supply both orientations so the
        // same contract survives a vertical bar.
        if (root.entryId(entry) === "omarchy.clock") {
            if (result.format === undefined || result.format === null || String(result.format) === "")
                result.format = "HH:mm"
            if (result.formatAlt === undefined || result.formatAlt === null || String(result.formatAlt) === "")
                result.formatAlt = "dddd HH:mm"
            if (result.verticalFormat === undefined || result.verticalFormat === null || String(result.verticalFormat) === "")
                result.verticalFormat = "HH\n—\nmm"
            if (result.verticalFormatAlt === undefined || result.verticalFormatAlt === null || String(result.verticalFormatAlt) === "")
                result.verticalFormatAlt = "dd\nMMM\n'W'ww\n''yy"
        }
        return result
    }

    function trayEntry(entries) {
        var values = Array.isArray(entries) ? entries : []
        for (var i = 0; i < values.length; i++)
            if (root.entryId(values[i]) === "omarchy.tray") return values[i]
        return null
    }

    function entriesWithTrayFirst(entries) {
        var values = Array.isArray(entries) ? entries : []
        var tray = root.trayEntry(values)
        if (!tray) return values
        var result = [tray]
        for (var i = 0; i < values.length; i++)
            if (values[i] !== tray) result.push(values[i])
        return result
    }

    function entriesWithoutTray(entries) {
        var values = Array.isArray(entries) ? entries : []
        return values.filter(function(entry) { return root.entryId(entry) !== "omarchy.tray" })
    }

    function minimalWorkspaceEntries(entries) {
        var values = Array.isArray(entries) ? entries : []
        return values.filter(function(entry) { return root.entryId(entry) === "omarchy.workspaces" })
    }

    function expandPath(value) {
        var path = String(value || "")
        if (path.indexOf("~/") === 0) return root.home + path.substring(1)
        if (path.indexOf("$HOME/") === 0) return root.home + path.substring(5)
        return path
    }

    function customModuleType(entry) {
        var settings = root.entrySettings(entry)
        var type = String(settings.type || "")
        if (type) return type
        if (settings.exec) return "command"
        if (settings.source) return "qml"
        return ""
    }

    function customModuleSource(entry) {
        var settings = root.entrySettings(entry)
        var name = root.entryId(entry)
        var source = settings.source ? root.expandPath(settings.source) : ""
        if (!source && name && name.indexOf("..") === -1 && name[0] !== "/")
            source = root.omarchyConfigDir + "/bar/modules/" + name + ".qml"
        return source
    }

    function runProcess(process) { if (process) process.running = true }

    function widgetComponent(id) {
        var widgets = root.barWidgetRegistry && root.barWidgetRegistry.widgets ? root.barWidgetRegistry.widgets : ({})
        var key = String(id || "")
        var canonical = typeof Util.canonicalWidgetId === "function" ? Util.canonicalWidgetId(key) : key
        return widgets[canonical] ? widgets[canonical].component : null
    }

    function surfaceFor(role) {
        if (role === "accent") return Color.accent
        if (role === "selection") return Color.lock.selection
        if (role === "dark") return Qt.darker(Color.background, 1.12)
        if (role === "light") return Color.foreground
        if (role === "transparent") return Color.background
        if (role === "background") return Color.background
        return Color.bar.background
    }

    function registerModuleSlot(slot) {
        if (!slot || root.moduleSlots.indexOf(slot) !== -1) return
        var next = root.moduleSlots.slice()
        next.push(slot)
        root.moduleSlots = next
    }

    function unregisterModuleSlot(slot) {
        root.moduleSlots = root.moduleSlots.filter(function(item) { return item !== slot })
    }

    function registerClickTarget(target) {
        if (!target || root.clickTargets.indexOf(target) !== -1) return
        var next = root.clickTargets.slice()
        next.push(target)
        root.clickTargets = next
    }

    function unregisterClickTarget(target) {
        root.clickTargets = root.clickTargets.filter(function(item) { return item !== target })
    }

    function nativeCloneItem() {
        return nativeDefaultCloneLoader && nativeDefaultCloneLoader.item ? nativeDefaultCloneLoader.item : null
    }

    function moduleWidgets(id) {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.moduleWidgets === "function") return clone.moduleWidgets(id)
        return root.moduleSlots.filter(function(slot) { return slot && slot.moduleName === String(id) && slot.activeItem })
            .map(function(slot) { return slot.activeItem })
    }

    function slotWindow(slot) {
        if (!slot) return null
        return root.targetWindow(slot.activeItem) || root.targetWindow(slot)
    }

    function sameWindow(left, right) {
        if (!left || !right) return false
        if (left === right) return true
        return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name
            && left.screen.name === right.screen.name
    }

    function slotScreenName(slot) {
        var window = root.slotWindow(slot)
        return window && window.screen ? String(window.screen.name || "") : ""
    }

    function focusedScreenName() {
        var monitor = Hyprland.focusedMonitor
        return monitor ? String(monitor.name || "") : ""
    }

    function panelNavigationSlots(region, window) {
        var entries = Array.isArray(root.layoutConfig[region]) ? root.layoutConfig[region] : []
        var slots = []
        for (var i = 0; i < entries.length; i++) {
            var id = root.entryId(entries[i])
            for (var j = 0; j < root.moduleSlots.length; j++) {
                var slot = root.moduleSlots[j]
                if (!slot || slot.region !== region || slot.moduleName !== id) continue
                if (window && !root.sameWindow(root.slotWindow(slot), window)) continue
                var item = slot.activeItem
                if (!item || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
                if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
                slots.push(slot)
                break
            }
        }
        return slots
    }

    function panelWidgetIdAt(region, index) {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.panelWidgetIdAt === "function") return clone.panelWidgetIdAt(region, index)
        var slots = root.panelNavigationSlots(String(region || ""), null)
        var slot = slots[Math.round(Number(index)) - 1]
        return slot ? String(slot.moduleName || "") : ""
    }

    function switchPanelFrom(owner, direction) {
        if (!owner) return false
        var currentSlot = null
        for (var i = 0; i < root.moduleSlots.length; i++) {
            var candidate = root.moduleSlots[i]
            if (candidate && candidate.activeItem === owner) {
                currentSlot = candidate
                break
            }
        }
        if (!currentSlot) return false

        var slots = root.panelNavigationSlots(currentSlot.region, root.slotWindow(currentSlot))
        if (slots.length < 2) return false
        var currentIndex = slots.indexOf(currentSlot)
        if (currentIndex < 0) return false
        var step = Number(direction) < 0 ? -1 : 1
        var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
        if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false
        nextSlot.activeItem.open()
        return true
    }

    function findPanelWidget(id) {
        var candidates = []
        var targetId = String(id || "")
        var focused = root.focusedScreenName()
        for (var i = 0; i < root.moduleSlots.length; i++) {
            var slot = root.moduleSlots[i]
            var item = slot ? slot.activeItem : null
            if (!slot || !item || slot.moduleName !== targetId) continue
            if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
            candidates.push({slot: slot, screen: root.slotScreenName(slot), opened: item.opened === true})
        }
        var open = candidates.filter(function(row) { return row.opened })
        var pool = open.length > 0 ? open : candidates
        if (focused) {
            var onFocused = pool.filter(function(row) { return row.screen === focused })
            if (onFocused.length > 0) pool = onFocused
        }
        return pool.length > 0 ? pool[0].slot.activeItem : null
    }

    function toggleTransparency() {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.toggleTransparency === "function") {
            clone.toggleTransparency()
            return
        }
        root.forceOpaqueAfterMove = false
        root.transparencyInteractionActive = true
        var nextTransparent = !(root.requestedTransparent === true)
        root.setRequestedTransparency(nextTransparent)
        if (root.shell && typeof root.shell.mutateShellConfig === "function") {
            root.shell.mutateShellConfig(function(config) {
                if (!config.bar || typeof config.bar !== "object") config.bar = {}
                config.bar.transparent = nextTransparent
            })
        }
    }

    function colorHex(colorValue) {
        var c = colorValue
        if (typeof c === "string") c = Qt.color(c)
        function hexChannel(value) {
            var result = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
            return result.length < 2 ? "0" + result : result
        }
        return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
    }

    function syncRequestedTransparency() {
        root.setRequestedTransparency(root.transparencyInteractionActive
            && root.barConfig
            && root.barConfig.transparent === true
            && !root.forceOpaqueAfterMove)
    }

    function setRequestedTransparency(value) {
        var nextTransparent = value === true
        root.requestedTransparent = nextTransparent
        if (!nextTransparent) {
            root.foregroundAnimationEnabled = false
            root.useTransparentForeground = false
            root.transparent = false
            root.transparentForeground = root.themeForeground
            root.restoreForegroundAnimation()
            return
        }
        root.scheduleTransparentForegroundRefresh()
    }

    function restoreForegroundAnimation() {
        Qt.callLater(function() {
            Qt.callLater(function() { root.foregroundAnimationEnabled = true })
        })
    }

    function scheduleTransparentForegroundRefresh() {
        if (!root.requestedTransparent) {
            root.transparentForeground = root.themeForeground
            return
        }
        transparentForegroundTimer.restart()
    }

    function refreshTransparentForeground() {
        if (!root.requestedTransparent || transparentForegroundProc.running) return
        transparentForegroundProc.command = [
            "omarchy-bar-text-color",
            root.position,
            String(root.barSize),
            root.colorHex(root.themeForeground),
            root.colorHex(root.themeContrastForeground)
        ]
        transparentForegroundProc.running = true
    }

    function rawLayoutSection(config, region) {
        if (!config.bar || typeof config.bar !== "object") config.bar = {}
        if (!config.bar.layout || typeof config.bar.layout !== "object") config.bar.layout = {}
        if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []
        return config.bar.layout[region]
    }

    function rawEntryIndex(entries, name) {
        for (var i = 0; i < entries.length; i++)
            if (root.entryId(entries[i]) === name) return i
        return -1
    }

    function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
        var fromEntries = root.rawLayoutSection(config, fromRegion)
        var toEntries = root.rawLayoutSection(config, toRegion)
        var fromIndex = root.rawEntryIndex(fromEntries, fromName)
        if (fromIndex < 0) return false

        var toIndex = beforeName ? root.rawEntryIndex(toEntries, beforeName) : toEntries.length
        if (toIndex < 0) toIndex = toEntries.length
        var movedEntry = fromEntries[fromIndex]
        fromEntries.splice(fromIndex, 1)
        if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
        toIndex = Math.max(0, Math.min(toIndex, toEntries.length))
        if (fromRegion === toRegion && fromIndex === toIndex) {
            fromEntries.splice(fromIndex, 0, movedEntry)
            return false
        }
        toEntries.splice(toIndex, 0, movedEntry)
        return true
    }

    function dropBarModule(source, target, afterTarget) {
        if (!source || !target || !source.region || !source.moduleName || !target.region) return false
        if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

        var beforeName = ""
        if (!afterTarget) {
            beforeName = target.moduleName
        } else {
            var entries = root.layoutConfig[target.region]
            var targetIndex = root.rawEntryIndex(entries, target.moduleName)
            for (var i = targetIndex + 1; i < entries.length; i++) {
                var candidate = root.entryId(entries[i])
                if (candidate && root.visibleSlot(target.region, candidate, source)) {
                    beforeName = candidate
                    break
                }
            }
        }

        var changed = false
        root.shell.mutateShellConfig(function(config) {
            changed = root.moveModuleInConfig(config, source.region, source.moduleName, target.region, beforeName)
        })
        return changed
    }

    function visibleSlot(region, name, source) {
        var sourceWindow = root.targetWindow(source)
        for (var i = 0; i < root.moduleSlots.length; i++) {
            var slot = root.moduleSlots[i]
            if (!slot || slot === source || slot.region !== region || slot.moduleName !== name || !slot.visible || slot.width <= 0) continue
            if (sourceWindow && root.targetWindow(slot) !== sourceWindow) continue
            return slot
        }
        return null
    }

    function nearestDropTarget(point, source) {
        var sourceWindow = root.targetWindow(source)
        var best = null
        var bestDistance = Number.MAX_VALUE
        for (var i = 0; i < root.moduleSlots.length; i++) {
            var slot = root.moduleSlots[i]
            if (!slot || slot === source || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
            if (sourceWindow && root.targetWindow(slot) !== sourceWindow) continue
            var slotPoint = slot.mapToItem(null, 0, 0)
            var axis = root.vertical ? point.y : point.x
            var start = root.vertical ? slotPoint.y : slotPoint.x
            var extent = root.vertical ? slot.height : slot.width
            var distance = Math.abs(axis - (start + extent / 2))
            if (distance < bestDistance) {
                bestDistance = distance
                best = { slot: slot, after: axis > start + extent / 2 }
            }
        }
        return best
    }

    function clearBarDrag() {
        root.barDragSource = null
        root.barDragTarget = null
        root.barDragAfter = false
        root.barDragSceneX = 0
        root.barDragSceneY = 0
    }

    function nearestScreenEdge(point, screen) {
        var nx = screen && screen.width > 0 ? Math.max(0, Math.min(1, point.x / screen.width)) : 0.5
        var ny = screen && screen.height > 0 ? Math.max(0, Math.min(1, point.y / screen.height)) : 0.5
        var edge = "top"
        var best = ny
        if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
        if (nx < best) { edge = "left"; best = nx }
        if (1 - nx < best) { edge = "right"; best = 1 - nx }
        return edge
    }

    function windowScreenPoint(scenePoint, window) {
        var x = scenePoint ? scenePoint.x : 0
        var y = scenePoint ? scenePoint.y : 0
        if (!window || !window.screen) return { x: x, y: y }
        if (root.position === "bottom") y += Math.max(0, window.screen.height - window.height)
        else if (root.position === "right") x += Math.max(0, window.screen.width - window.width)
        return { x: x, y: y }
    }

    function beginBarMove(window) {
        root.barMoveWindow = window
        root.barMoveScreen = window ? window.screen : null
        root.barMoveCandidate = root.position
        root.barMoveActive = true
    }

    function updateBarMove(screenPoint) {
        if (!root.barMoveActive || !root.barMoveScreen) return
        root.barMoveCandidate = root.nearestScreenEdge(screenPoint, root.barMoveScreen)
    }

    function clearBarMove() {
        root.barMoveActive = false
        root.barMoveCandidate = ""
        root.barMoveWindow = null
        root.barMoveScreen = null
    }

    function finishBarMove() {
        var edge = root.barMoveCandidate
        if (!root.barMoveActive || !edge || edge === root.position) {
            root.clearBarMove()
            return
        }
        root.clearBarMove()
        var next = root.normalizePosition(edge)
        if (root.shell && typeof root.shell.mutateShellConfig === "function") {
            root.shell.mutateShellConfig(function(config) {
                if (!config.bar || typeof config.bar !== "object") config.bar = {}
                config.bar.position = next
                // A compact vertical rail has no broad visible hit target.
                // Moving the bar must therefore recover it from a previously
                // toggled transparent state instead of stranding the user
                // with an invisible 24px surface.
                config.bar.transparent = false
            })
            root.forceOpaqueAfterMove = true
        }
    }

    function targetWindow(target) {
        return target && target.QsWindow ? target.QsWindow.window : null
    }

    function targetBelongsToWindow(target, window) {
        return !!target && !!window && root.targetWindow(target) === window
    }

    function targetTooltipHovered(target) {
        return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
    }

    function clearTooltip() {
        tooltipTimer.stop()
        root.pendingTooltipTarget = null
        root.pendingTooltipText = ""
        root.tooltipTarget = null
        root.tooltipText = ""
        root.tooltipShown = false
    }

    function run(command) { if (command) Util.execDetached(command) }

    function showTooltip(target, text) {
        root.clearTooltip()
        if (!root.targetTooltipHovered(target) || !text) {
            root.tooltipRequest += 1
            return
        }

        var request = root.tooltipRequest + 1
        root.tooltipRequest = request
        root.pendingTooltipTarget = target
        root.pendingTooltipText = String(text)
        Qt.callLater(function() {
            if (request !== root.tooltipRequest) return
            if (!root.targetTooltipHovered(root.pendingTooltipTarget)) {
                root.clearTooltip()
                return
            }
            root.tooltipTarget = root.pendingTooltipTarget
            root.tooltipText = root.pendingTooltipText
            root.pendingTooltipTarget = null
            root.pendingTooltipText = ""
            tooltipTimer.restart()
        })
    }

    function hideTooltip(target) {
        if (root.tooltipTarget !== target && root.pendingTooltipTarget !== target) return
        root.tooltipRequest += 1
        root.clearTooltip()
    }

    Timer {
        id: tooltipTimer
        interval: 400
        onTriggered: {
            if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
            else root.clearTooltip()
        }
    }

    Timer {
        interval: 100
        running: root.tooltipShown
        repeat: true
        onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
    }

    function moduleTargetClickable(target) {
        return target && target.visible !== false && target.opacity !== 0
            && target.interactive !== false && target.pressable !== false
            && target.concealed !== true && typeof target.triggerPress === "function"
    }

    function moduleClickTargetAt(slot, localX, localY) {
        for (var i = root.clickTargets.length - 1; i >= 0; i--) {
            var target = root.clickTargets[i]
            if (!root.moduleTargetClickable(target)) continue
            var point = {x: localX, y: localY}
            try {
                point = slot.mapToItem(target, localX, localY)
            } catch (error) {
                continue
            }
            if (point.x >= 0 && point.x <= target.width && point.y >= 0 && point.y <= target.height)
                return target
        }
        return root.moduleTargetClickable(slot.activeItem) ? slot.activeItem : null
    }

    function pressModuleClickTarget(slot, button, localX, localY) {
        var target = root.moduleClickTargetAt(slot, localX, localY)
        if (!target) return false
        target.triggerPress(button)
        return true
    }
    function requestPopout(owner) {
        if (root.activePopout === owner) return
        if (root.activePopout && typeof root.activePopout.closeForPopoutSwitch === "function") root.activePopout.closeForPopoutSwitch()
        else if (root.activePopout && typeof root.activePopout.close === "function") root.activePopout.close()
        root.activePopout = owner
    }
    function releasePopout(owner) { if (root.activePopout === owner) root.activePopout = null }
    function summonBarWidget(id) {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.summonBarWidget === "function") return clone.summonBarWidget(id)
        var item = root.findPanelWidget(id)
        if (!item || typeof item.open !== "function") return false
        item.open()
        return true
    }
    function hideBarWidget(id) {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.hideBarWidget === "function") return clone.hideBarWidget(id)
        var item = root.findPanelWidget(id)
        if (!item || typeof item.close !== "function") return false
        item.close()
        return true
    }
    function isBarWidgetOpen(id) {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.isBarWidgetOpen === "function") return clone.isBarWidgetOpen(id)
        var item = root.findPanelWidget(id)
        return !!item && item.opened === true
    }

    function debugBarGeometry() {
        var clone = root.nativeCloneItem()
        if (clone && typeof clone.debugBarGeometry === "function") return clone.debugBarGeometry()
        return root.moduleSlots.filter(function(slot) { return slot && slot.activeItem }).map(function(slot) {
            var point = { x: slot.x, y: slot.y }
            var group = slot.parent
            var owner = group ? group.parent : null
            try { point = slot.mapToItem(null, 0, 0) } catch (error) { }
            return {
                id: slot.moduleName,
                section: slot.region,
                x: Math.round(point.x),
                y: Math.round(point.y),
                width: Math.round(slot.width),
                height: Math.round(slot.height),
                groupX: group ? Math.round(group.x) : 0,
                groupWidth: group ? Math.round(group.width) : 0,
                ownerWidth: owner ? Math.round(owner.width) : 0
            }
        })
    }

    function loadSpec(raw) {
        try {
            var value = JSON.parse(String(raw || "{}"))
            root.specDocument = value && value.spec ? value : ({})
        } catch (error) {
            root.specDocument = ({})
        }
    }

    function restoreNativeForUnmarkedTheme() {
        if (!root.profileResolved || String(root.profileDocument && root.profileDocument.implementation || "") === "replacement"
                || !root.shell || !root.manifest
                || typeof root.shell.mutateShellConfig !== "function") return
        var selected = root.barConfig && root.barConfig.id ? String(root.barConfig.id) : ""
        if (selected !== String(root.manifest.id || "pretty.omagen.bar")
                || String(root.barConfig.omagenOwnedBy || "") !== "pretty.omagen") return
        root.shell.mutateShellConfig(function(copy) {
            if (copy.bar && typeof copy.bar === "object"
                    && String(copy.bar.id || "") === String(root.manifest.id || "pretty.omagen.bar")
                    && String(copy.bar.omagenOwnedBy || "") === "pretty.omagen") {
                delete copy.bar.id
                delete copy.bar.omagenOwnedBy
            }
        })
    }

    FileView {
        id: specFile
        path: root.stateHome + "/omarchy/current/theme/omagen.bar.spec.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.loadSpec(text())
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.specDocument = ({})
        }
        Component.onCompleted: reload()
    }

    FileView {
        id: profileFile
        path: root.stateHome + "/omarchy/current/theme/omagen.bar.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            profileMissingTimer.stop()
            try { root.profileDocument = JSON.parse(String(text() || "{}")) } catch (error) { root.profileDocument = ({}) }
            root.profileResolved = true
            root.restoreNativeForUnmarkedTheme()
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.profileDocument = ({})
            root.profileResolved = false
            profileMissingTimer.restart()
        }
        Component.onCompleted: reload()
    }

    Timer {
        id: profileMissingTimer
        interval: 280
        repeat: false
        onTriggered: {
            root.profileResolved = true
            root.restoreNativeForUnmarkedTheme()
        }
    }

    // Keep the replacement plugin's Default path native-owned. NativeBarClone
    // is a checked-in copy of Quattro's installed Bar.qml with one explicit
    // extension point for omarchy.workspaces; every other widget and surface
    // remains on the platform implementation.
    Component {
        id: nativeDefaultCloneComponent
        NativeBarClone {
            omarchyPath: root.omarchyPath
            barWidgetRegistry: root.barWidgetRegistry
            barConfig: root.barConfig
            shell: root.shell
            manifest: root.manifest
            workspaceOverrideEnabled: root.workspaceMode !== "native"
            workspaceSpecOverride: root.workspaceSpec
            clockStyle: root.clockStyle
        }
    }

    Loader {
        id: nativeDefaultCloneLoader
        active: root.nativeDefaultClone
        sourceComponent: nativeDefaultCloneComponent
    }

    // Inline components retain the Omagen host root when Quickshell creates
    // one delegate per monitor. A `property var bar: root` declaration inside
    // the delegate is evaluated in the delegate's dynamic scope and can be
    // null during the asynchronous plugin injection pass; this mirrors the
    // native bar's own component pattern and keeps the host contract stable.
    component OmagenBarSurface: BarSurface {
        bar: root
    }

    component OmagenBarMoveGhostPanel: BarMoveGhostPanel {
        bar: root
    }

    Timer {
        id: transparentForegroundTimer
        interval: 120
        repeat: false
        onTriggered: root.refreshTransparentForeground()
    }

    Timer {
        id: themeStateRefreshTimer
        interval: 80
        repeat: false
        onTriggered: {
            specFile.reload()
            profileFile.reload()
            root.scheduleTransparentForegroundRefresh()
        }
    }

    Process {
        id: transparentForegroundProc
        stdout: SplitParser {
            onRead: function(line) {
                var value = String(line || "").trim()
                if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

                root.foregroundAnimationEnabled = false
                root.transparentForeground = value
                if (root.requestedTransparent) {
                    root.useTransparentForeground = true
                    root.transparent = true
                }
                root.restoreForegroundAnimation()
            }
        }
    }

    Timer {
        id: autoHideTimer
        interval: root.autoHideDelayMs
        repeat: false
        onTriggered: root.hideAutoHideBar()
    }

    component OmagenBarRevealEdge: PanelWindow {
        id: revealEdgePanel
        property var bar: root
        property bool edgeHovered: false

        screen: null
        visible: bar.autoHide && bar.autoHideHidden
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "pretty-omagen-bar-reveal"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: bar.position === "top" || bar.vertical
            bottom: bar.position === "bottom" || bar.vertical
            left: bar.position === "left" || !bar.vertical
            right: bar.position === "right" || !bar.vertical
        }
        implicitWidth: bar.vertical ? bar.barSize : 0
        implicitHeight: bar.vertical ? 0 : Style.space(4)

        HoverHandler {
            onHoveredChanged: {
                revealEdgePanel.edgeHovered = hovered
                if (hovered) {
                    bar.autoHideRevealHoverCount++
                    bar.showAutoHideBar()
                } else {
                    bar.autoHideRevealHoverCount = Math.max(0, bar.autoHideRevealHoverCount - 1)
                    bar.syncAutoHide()
                }
            }
            Component.onDestruction: {
                if (!revealEdgePanel.edgeHovered)
                    return
                bar.autoHideRevealHoverCount = Math.max(0, bar.autoHideRevealHoverCount - 1)
                bar.syncAutoHide()
            }
        }
    }

    FileView {
        path: root.stateHome + "/omarchy/current"
        watchChanges: true
        printErrors: false
        // Theme activation atomically replaces entries below `current` while
        // the bar plugin instance and its ID may stay unchanged. Watch the
        // stable directory so spec/profile readers do not remain attached to
        // the previous theme inode after Test Live or Apply.
        onFileChanged: themeStateRefreshTimer.restart()
    }

    Process {
        id: hiddenProbe
        command: ["/usr/bin/test", "-f", root.stateHome + "/omarchy/toggles/bar-off"]
        running: true
        onExited: function(code) { root.barHidden = code === 0 }
    }

    FileView {
        path: root.stateHome + "/omarchy/toggles"
        watchChanges: true
        printErrors: false
        onFileChanged: hiddenProbe.running = true
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            OmagenBarSurface {
                required property var modelData
                screen: modelData
                visible: !root.nativeDefaultClone
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            OmagenBarRevealEdge {
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            OmagenBarMoveGhostPanel {
                required property var modelData
                screen: modelData
                ghostScreen: modelData
            }
        }
    }

}
