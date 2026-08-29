import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui
import "." as Bar

Item {
    id: slot
    property var bar: null
    required property var entry
    property bool active: true
    property string region: ""
    readonly property string moduleName: bar ? bar.entryId(entry) : ""
    readonly property var settings: bar ? bar.entrySettings(entry) : ({})
    readonly property string customType: bar ? bar.customModuleType(entry) : ""
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool compactTray: !!bar && moduleName === "omarchy.tray"
        && (bar.topology === "islands"
            || bar.topology === "dock"
            || (bar.topology === "floating" && bar.density === "compact"
                && String(bar.spec && bar.spec.preset || "") === "float")
            || (bar.topology === "minimal" && bar.vertical))
    // Keep the native clock mounted as the active item. StyledClockWidget is
    // presentation-only and paints above it, so the native calendar, IPC,
    // format cycling, timezone action, and popout identity remain untouched.
    readonly property bool styledClock: !!bar && moduleName === "omarchy.clock"
        && bar.clockStyle !== "native"
    readonly property bool clockSlot: !!bar && moduleName === "omarchy.clock"
    readonly property bool workspacePresentation: !!bar && moduleName === "omarchy.workspaces"
        && bar.workspacePresentationActive
    readonly property bool dragSource: !!bar && bar.barDragSource === slot
    readonly property bool panelOpen: !!bar && bar.activePopout === slot.activeItem
    // Match the native bar's indicator contract. Panel widgets can supply
    // a painted extent (clock/weather use a smaller vertical mark); using
    // the whole slot makes the indicator look like a line through the
    // icon instead of a pointer to the active module.
    readonly property real panelIndicatorExtent: {
        if (!bar) return 0
        var key = bar.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
        var hint = activeItem && key in activeItem ? activeItem[key] : undefined
        if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
        return Math.max(Style.space(10), Math.round((bar.vertical ? slot.height : slot.width) * 0.55))
    }
    // Read the registry map directly so installing, enabling, or removing
    // a bar plugin invalidates this binding. Calling widgetComponent()
    // alone would hide that dependency from QML's binding tracker and
    // could leave a stale component mounted until a full shell restart.
    readonly property var registryComponent: {
        var widgets = bar && bar.barWidgetRegistry && bar.barWidgetRegistry.widgets
            ? bar.barWidgetRegistry.widgets : ({})
        if (qmlCustom || commandCustom) return null
        if (compactTray) return compactTrayWidgetComponent
        if (workspacePresentation) return null
        var canonical = typeof Util.canonicalWidgetId === "function"
            ? Util.canonicalWidgetId(moduleName) : moduleName
        return widgets[canonical] && widgets[canonical].component
            ? widgets[canonical].component : null
    }
    // A replacement bar can be constructed one turn before Quattro finishes
    // registering its first-party widgets. Keep the native clock available in
    // that window so the bar never degrades to a background-only strip. Once
    // the registry publishes the real component this fallback is unloaded and
    // the normal registry-owned clock resumes.
    readonly property bool nativeClockFallback: !qmlCustom && !commandCustom
        && !compactTray && !workspacePresentation
        && moduleName === "omarchy.clock" && !registryComponent
    readonly property var activeItem: workspacePresentation ? workspaceLoader.item : qmlCustom ? qmlLoader.item : commandCustom ? commandLoader.item : nativeClockFallback ? nativeClockLoader.item : loader.item
    // Native vertical ModuleSlot fixes every widget to the rail width;
    // allowing a widget's horizontal implicit width here clips text and
    // icons into the fragments seen in the live screenshot.
    implicitWidth: !slot.active || !bar ? 0 : bar.vertical
        ? bar.barSize
        : (activeItem && activeItem.visible !== false ? activeItem.implicitWidth : 0)
    implicitHeight: !slot.active || !bar
        ? 0
        : (activeItem && activeItem.visible !== false ? activeItem.implicitHeight : 0)
    width: implicitWidth
    height: implicitHeight
    // Third-party widgets may paint a horizontal label or badge even
    // after receiving a vertical bar. Keep that drawing contained in its
    // compact rail slot so it cannot overlap adjacent modules.
    clip: bar ? bar.vertical : false

    property bool registered: false

    function registerIfReady() {
        if (bar && !registered) {
            bar.registerModuleSlot(slot)
            registered = true
        }
    }

    function unregisterIfReady() {
        if (bar && registered) {
            bar.unregisterModuleSlot(slot)
            registered = false
        }
    }

    function injectProps(target) {
        if (!target) return
        if ("bar" in target) target.bar = bar
        if ("moduleName" in target) target.moduleName = slot.moduleName
        if ("settings" in target) target.settings = slot.settings
    }

    function injectActiveProps() {
        injectProps(loader.item)
        injectProps(nativeClockLoader.item)
    }

    // The registry can finish loading after the bar receives shell.json, and
    // shell.json can refresh inline settings without rebuilding slots. Reapply
    // the values in both cases so the clock never renders its native
    // date-plus-time fallback just because it mounted one turn too early.
    onBarChanged: {
        registerIfReady()
        injectActiveProps()
    }
    onSettingsChanged: injectActiveProps()
    Component.onCompleted: registerIfReady()
    Component.onDestruction: unregisterIfReady()

    function toggleClockFormat() {
        if (!clockSlot || !bar || !activeItem || !("settings" in activeItem)) return false

        var source = activeItem.settings && typeof activeItem.settings === "object"
            ? activeItem.settings : slot.settings
        var next = ({})
        for (var key in source) if (key !== "id") next[key] = source[key]

        var formatKey = bar.vertical ? "verticalFormat" : "format"
        var altKey = bar.vertical ? "verticalFormatAlt" : "formatAlt"
        var timeOnly = bar.vertical ? "HH\n—\nmm" : "HH:mm"
        var dateAndTime = bar.vertical ? "dd\nMMM\n'W'ww\n''yy" : "dddd HH:mm"
        var current = String(next[formatKey] || timeOnly)
        next[formatKey] = current === timeOnly ? dateAndTime : timeOnly
        next[altKey] = dateAndTime

        var entry = { id: slot.moduleName }
        for (var setting in next) entry[setting] = next[setting]
        activeItem.settings = entry
        if (bar.shell && typeof bar.shell.updateEntryInline === "function")
            bar.shell.updateEntryInline(slot.moduleName, entry)
        return true
    }

    BorderSurface {
        visible: slot.dragSource
        anchors.fill: parent
        anchors.margins: Style.space(1)
        color: "transparent"
        borderSpec: Border.flat(bar ? bar.barForeground : "transparent", 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: bar && bar.transparent ? 0.32 : 0.7
    }

    Rectangle {
        visible: !!bar && bar.barDragSource !== null && bar.barDragTarget === slot
        color: bar ? bar.urgent : "transparent"
        radius: Math.min(width, height) / 2
        width: bar && bar.vertical ? slot.width : Style.space(2)
        height: bar && bar.vertical ? Style.space(2) : slot.height
        x: bar && bar.vertical ? 0 : (bar && bar.barDragAfter ? slot.width - width : 0)
        y: bar && bar.vertical ? (bar.barDragAfter ? slot.height - height : 0) : 0
        z: 20
    }

    Rectangle {
        id: openPanelIndicator
        readonly property int inset: Style.space(2)
        visible: opacity > 0
        opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
        color: Color.accent
        radius: Math.min(width, height) / 2
        width: bar && bar.vertical ? Style.space(2) : slot.panelIndicatorExtent
        height: bar && bar.vertical ? slot.panelIndicatorExtent : Style.space(2)
        x: bar && bar.vertical
            ? (bar.position === "left" ? parent.width - width - inset : inset)
            : Math.round((parent.width - width) / 2)
        y: bar && bar.vertical
            ? Math.round((parent.height - height) / 2)
            : (bar && bar.position === "top" ? parent.height - height - inset : inset)
        z: 50

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    Loader {
        id: loader
        active: slot.active && !slot.qmlCustom && !slot.commandCustom && !slot.workspacePresentation && !slot.nativeClockFallback
        anchors.fill: parent
        // Do not destroy or replace the native clock item. It owns the
        // calendar panel and remains the click/popup target even while its
        // visual label is covered by the selected Omagen face.
        opacity: slot.styledClock ? 0 : (slot.dragSource ? 0.25 : 1)
        sourceComponent: slot.registryComponent
        onLoaded: {
            if (!item) return
            slot.injectProps(item)
            if (styledClockLoader.item && "clock" in styledClockLoader.item) styledClockLoader.item.clock = item
        }
    }

    Loader {
        id: nativeClockLoader
        active: slot.active && slot.nativeClockFallback
        anchors.fill: parent
        opacity: slot.dragSource ? 0.25 : 1
        source: slot.nativeClockFallback && bar && bar.omarchyPath
            ? bar.omarchyPath + "/shell/plugins/panels/clock/BarWidget.qml" : ""
        onLoaded: {
            if (!item) return
            slot.injectProps(item)
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("native clock fallback failed", errorString())
    }

    Loader {
        id: styledClockLoader
        active: slot.active && slot.styledClock
        anchors.fill: parent
        opacity: slot.dragSource ? 0.25 : 1
        source: slot.styledClock ? Qt.resolvedUrl("ClockStyleWidget.qml") : ""
        onLoaded: {
            if (!item) return
            if ("bar" in item) item.bar = bar
            if ("clock" in item) item.clock = loader.item
        }
    }

    Loader {
        id: workspaceLoader
        active: slot.active && slot.workspacePresentation
        anchors.fill: parent
        opacity: slot.dragSource ? 0.25 : 1
        source: Qt.resolvedUrl("../WorkspacePresentation.qml")
        onLoaded: {
            if (!item) return
            if ("bar" in item) item.bar = bar
            if ("workspaceSpecOverride" in item) item.workspaceSpecOverride = bar.workspaceSpec
            if ("moduleName" in item) item.moduleName = slot.moduleName
            if ("settings" in item) item.settings = slot.settings
        }
    }

    Loader {
        id: qmlLoader
        active: slot.active && slot.qmlCustom
        anchors.fill: parent
        opacity: slot.dragSource ? 0.25 : 1
        source: slot.qmlCustom ? bar.customModuleSource(slot.entry) : ""
        onLoaded: {
            if (!item) return
            if ("bar" in item) item.bar = bar
            if ("moduleName" in item) item.moduleName = slot.moduleName
            if ("settings" in item) item.settings = slot.settings
        }
    }

    Loader {
        id: commandLoader
        active: slot.active && slot.commandCustom
        anchors.fill: parent
        opacity: slot.dragSource ? 0.25 : 1
        sourceComponent: slot.commandCustom ? commandModuleComponent : null
        onLoaded: if (item) { item.bar = bar; item.entry = slot.entry }
    }

    Component {
        id: compactTrayWidgetComponent
        Bar.CompactTrayWidget {}
    }

    Component {
        id: commandModuleComponent
        Bar.CustomCommandModule { entry: slot.entry; bar: slot.bar }
    }

    MouseArea {
        id: modulePointer
        property bool dragging: false
        property bool suppressClick: false
        property real pressedX: 0
        property real pressedY: 0
        readonly property real dragThreshold: Style.space(4)

        anchors.fill: parent
        acceptedButtons: slot.clockSlot ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
        enabled: !!bar && !slot.compactTray && slot.visible && slot.width > 0 && slot.height > 0
        propagateComposedEvents: true
        cursorShape: dragging ? Qt.ClosedHandCursor
            : (bar && bar.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor)

        onPressed: function(mouse) {
            dragging = false
            suppressClick = false
            pressedX = mouse.x
            pressedY = mouse.y
            bar.clearBarDrag()
        }

        onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
            if (!dragging && distance >= dragThreshold) {
                dragging = true
                bar.barDragSource = slot
            }
            if (!dragging) return

            var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
            bar.barDragSceneX = scenePoint.x
            bar.barDragSceneY = scenePoint.y
            var drop = bar.nearestDropTarget(scenePoint, slot)
            bar.barDragTarget = drop ? drop.slot : null
            bar.barDragAfter = drop ? drop.after : false
        }

        onReleased: function(mouse) {
            var wasDragging = dragging
            var target = bar.barDragTarget
            var after = bar.barDragAfter
            dragging = false
            if (wasDragging) suppressClick = true
            bar.clearBarDrag()
            if (wasDragging && target) {
                bar.dropBarModule(slot, target, after)
                mouse.accepted = true
            } else if (!wasDragging) {
                mouse.accepted = false
            }
        }

        onCanceled: {
            dragging = false
            suppressClick = false
            bar.clearBarDrag()
        }

        onClicked: function(mouse) {
            if (suppressClick) {
                suppressClick = false
                mouse.accepted = true
                return
            }
            if (mouse.button === Qt.RightButton && slot.toggleClockFormat()) {
                mouse.accepted = true
                return
            }
            if (bar.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) {
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }

    }
}
