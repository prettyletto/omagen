import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "bar" as Bar

PanelWindow {
    id: panel
    property var bar: null
    readonly property bool topEdge: bar.position === "top"
    readonly property bool bottomEdge: bar.position === "bottom"
    readonly property bool leftEdge: bar.position === "left"
    readonly property bool rightEdge: bar.position === "right"
    readonly property bool fullWidth: !bar.contentSized && bar.topology !== "dock"
    readonly property bool islandsFullLength: bar.topology === "islands"
    readonly property int compactIntrinsicWidth: presetLoader.item
        ? Math.ceil(presetLoader.item.implicitWidth || presetLoader.implicitWidth)
        : Math.ceil(presetLoader.implicitWidth)
    // Float Compact wraps the measured three-zone content. There is no
    // monitor-percentage width target: the main pill grows only as much as
    // the left, center, and right groups require.
    readonly property int compactContentWidth: compactIntrinsicWidth
    // Float Compact's dedicated tray surface is mounted separately below,
    // so its hit targets and drawer do not change the pill's width.
    readonly property int contentWidth: (bar.floatingCompact
        ? compactContentWidth
        : presetLoader.implicitWidth) + Style.space(16)
    readonly property int contentHeight: Math.max(bar.barSize,
        Math.ceil(presetLoader.item ? (presetLoader.item.implicitHeight || presetLoader.implicitHeight) : presetLoader.implicitHeight)
            + Style.space(16))
    readonly property int compactVerticalWidth: bar.floatingCompact && bar.vertical
        ? bar.barSize + Style.space(4) : bar.barSize
    readonly property int surfaceWidth: bar.vertical
        ? (bar.topology === "islands" ? bar.islandThickness : bar.dock ? bar.dockThickness : compactVerticalWidth)
        : (fullWidth || islandsFullLength ? 0 : contentWidth)
    readonly property int surfaceHeight: bar.vertical
        ? (fullWidth || islandsFullLength ? 0 : contentHeight)
        : bar.barSize
    readonly property bool compactTrayEnabled: bar.floatingCompact && !bar.vertical
    readonly property bool compactVerticalTrayEnabled: bar.floatingCompact && bar.vertical
    readonly property int compactTrayCollapsedWidth: compactTraySlot.activeItem
        && "collapsedWidth" in compactTraySlot.activeItem
        ? compactTraySlot.activeItem.collapsedWidth
        : Style.bar.iconSlot
    readonly property int compactVerticalTrayCollapsedHeight: compactVerticalTraySlot.activeItem
        && "collapsedWidth" in compactVerticalTraySlot.activeItem
        ? compactVerticalTraySlot.activeItem.collapsedWidth
        : Style.bar.iconSlot
    readonly property int compactTrayGap: Style.space(8)

    visible: !remapGuard.remapping
    color: "transparent"
    surfaceFormat.opaque: false
    // A replacement bar still occupies the native bar's exclusive zone.
    // Ignoring the zone for floating/content-sized surfaces lets tiled
    // windows render underneath the painted bar, which is the overlap seen
    // in the live desktop. Auto mirrors Quattro's native BarPanel contract;
    // only an explicitly hidden bar gives the space back.
    exclusionMode: bar.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
    WlrLayershell.namespace: "pretty-omagen-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: topEdge || bar.vertical
        bottom: bottomEdge || bar.vertical
        // Keep one monitor-wide, click-through layer for centered/content
        // bars; the painted frame below is sized and centered independently
        // so a floating/dock surface does not stretch across the screen.
        left: !bar.vertical || leftEdge
        right: !bar.vertical || rightEdge
    }
    margins {
        top: topEdge ? (bar.barHidden ? -(bar.barSize + bar.edgeOffset) : bar.edgeOffset) : 0
        bottom: bottomEdge ? (bar.barHidden ? -(bar.barSize + bar.edgeOffset) : bar.edgeOffset) : 0
        left: leftEdge ? (bar.barHidden ? -(bar.barSize + bar.edgeOffset) : bar.edgeOffset) : bar.outerMargin
        right: rightEdge ? (bar.barHidden ? -(bar.barSize + bar.edgeOffset) : bar.edgeOffset) : bar.outerMargin
    }
    implicitWidth: bar.vertical
        ? (bar.topology === "islands" ? bar.islandThickness : bar.dock ? bar.dockThickness : compactVerticalWidth)
        : surfaceWidth
    implicitHeight: bar.vertical ? surfaceHeight : bar.dock ? bar.dockThickness : bar.barSize

    ScreenMoveRemap { id: remapGuard; window: panel }

    HoverHandler {
        onHoveredChanged: {
            bar.hoverCount = Math.max(0, bar.hoverCount + (hovered ? 1 : -1))
            bar.barHovered = bar.hoverCount > 0
        }
        Component.onDestruction: {
            if (!hovered) return
            bar.hoverCount = Math.max(0, bar.hoverCount - 1)
            bar.barHovered = bar.hoverCount > 0
        }
    }

    // Tooltips belong to the bar host, not to the replacement widget
    // instance. This is the same per-monitor PopupWindow contract as the
    // native bar, so tooltips continue to anchor correctly on every edge
    // and never require a widget to invent its own surface.
    PopupWindow {
        id: tooltipWindow
        visible: bar.tooltipShown && bar.tooltipTarget !== null
            && bar.tooltipText !== ""
            && bar.targetBelongsToWindow(bar.tooltipTarget, panel)
        color: "transparent"
        implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
        implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

        anchor {
            id: tooltipAnchor
            window: panel
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                var target = bar.tooltipTarget
                if (!bar.targetBelongsToWindow(target, panel)) return

                var popupWidth = tooltipWindow.implicitWidth
                var popupHeight = tooltipWindow.implicitHeight
                var localX = target.width / 2 - popupWidth / 2
                var localY = target.height + 6
                if (bar.position === "bottom") {
                    localY = -popupHeight - 6
                } else if (bar.position === "left") {
                    localX = target.width + 6
                    localY = target.height / 2 - popupHeight / 2
                } else if (bar.position === "right") {
                    localX = -popupWidth - 6
                    localY = target.height / 2 - popupHeight / 2
                }

                var point = panel.contentItem.mapFromItem(target, localX, localY)
                tooltipAnchor.rect.x = Math.round(point.x)
                tooltipAnchor.rect.y = Math.round(point.y)
            }
        }

        BorderSurface {
            id: tooltipBubble
            implicitWidth: tooltipLabel.implicitWidth + Style.space(20)
            implicitHeight: tooltipLabel.implicitHeight + Style.space(14)
            color: Color.tooltip.background
            borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
            radius: Style.cornerRadius

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: bar.tooltipText
                color: Color.tooltip.text
                font.family: bar.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // The complete edge-span panel is the drag host. Keep it beneath the
    // painted surface so widget clicks remain owned by their slots, while
    // empty space across the whole bar can still move the bar.
    MouseArea {
        id: hostGesture
        anchors.fill: parent
        z: 0
        property bool dragging: false
        property bool suppressClick: false
        property real pressedX: 0
        property real pressedY: 0
        readonly property real dragThreshold: Style.space(4)
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            dragging = false
            suppressClick = false
            pressedX = mouse.x
            pressedY = mouse.y
        }
        onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
            if (!dragging && distance >= dragThreshold) {
                dragging = true
                bar.beginBarMove(bar.targetWindow(hostGesture))
            }
            if (!dragging) return
            var scenePoint = hostGesture.mapToItem(null, mouse.x, mouse.y)
            bar.updateBarMove(bar.windowScreenPoint(scenePoint, bar.barMoveWindow))
        }
        onReleased: function(mouse) {
            if (!dragging) {
                mouse.accepted = false
                return
            }
            dragging = false
            suppressClick = true
            bar.finishBarMove()
            mouse.accepted = true
        }
        onCanceled: {
            dragging = false
            suppressClick = false
            bar.clearBarMove()
        }
        onClicked: function(mouse) {
            if (suppressClick) {
                suppressClick = false
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
        onDoubleClicked: function(mouse) {
            if (suppressClick) {
                suppressClick = false
                return
            }
            if (mouse.button === Qt.LeftButton) {
                bar.toggleTransparency()
                mouse.accepted = true
            }
        }
    }

    Item {
        id: surfaceFrame
        z: 1
        // PanelWindow remains monitor-edge sized for placement and input.
        // Paint the compact surface from the panel's actual geometry,
        // rather than the transient content item's initial 0×0 size.
        // The measured compact content is centered on the monitor. The tray
        // is a separate sibling surface, offset to the right like Quattro's
        // detached tray affordance.
        x: Math.round((panel.width - width) / 2)
        y: Math.round((panel.height - height) / 2)
        width: bar.vertical
            ? (bar.topology === "islands" ? bar.islandThickness : bar.dock ? bar.dockThickness : compactVerticalWidth)
            : (panel.islandsFullLength
            ? panel.width
            : bar.dock
            ? (bar.dockExpanded ? Math.min(panel.width, panel.contentWidth) : bar.dockCollapsedExtent)
            : bar.contentSized
            ? Math.min(panel.width, bar.floatingCompact ? compactContentWidth + Style.space(16) : contentWidth)
            : panel.width)
        height: bar.vertical
            ? (panel.islandsFullLength ? panel.height
                : bar.dock
                ? (bar.dockExpanded ? Math.min(panel.height, panel.contentHeight) : bar.dockCollapsedExtent)
                : (bar.contentSized ? Math.min(panel.height, contentHeight) : panel.height))
            : bar.dock ? bar.dockThickness : bar.barSize

        Behavior on width {
            enabled: bar.dock
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: bar.dock
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        BorderSurface {
            // Dock paints its own rounded surface inside this frame. The
            // generic outer border would sit over the widget row and read
            // as a line cutting through the icons.
            visible: bar.topology !== "islands" && bar.topology !== "minimal" && !bar.dock
            anchors.fill: parent
            color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
            radius: bar.radius > 0 ? bar.radius : Style.cornerRadius
            borderSpec: !bar.transparent && bar.borderWidth > 0
                ? Border.flat(Util.alpha(bar.borderColor, bar.borderOpacity), bar.borderWidth)
                : Border.none()
        }

        Loader {
            id: presetLoader
            anchors.fill: parent
            active: bar !== null
            source: bar ? Qt.resolvedUrl("bar/BarPresetRouter.qml") : ""
            onLoaded: if (item && "bar" in item) item.bar = bar
        }

        // Float Compact keeps the tray outside the main pill. Its left edge
        // stays fixed while the drawer expands rightward, so expanding the
        // tray never moves the main surface or changes its measured width.
        Item {
            id: compactTrayFrame
            z: 2
            visible: panel.compactTrayEnabled
            width: Math.max(compactTraySlot.implicitWidth, panel.compactTrayCollapsedWidth)
            height: bar.barSize
            x: Math.round(Math.min(panel.width - surfaceFrame.x - width - bar.outerMargin,
                surfaceFrame.width + panel.compactTrayGap))
            y: 0

            BorderSurface {
                anchors.fill: parent
                color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
                radius: bar.radius > 0 ? bar.radius : Style.cornerRadius
                borderSpec: !bar.transparent && bar.borderWidth > 0
                    ? Border.flat(Util.alpha(bar.borderColor, bar.borderOpacity), bar.borderWidth)
                    : Border.none()
            }

            Bar.WidgetSlot {
                id: compactTraySlot
                bar: panel.bar
                active: panel.compactTrayEnabled
                entry: panel.bar
                    ? (panel.bar.trayEntry(panel.bar.layoutConfig.right) || ({ id: "omarchy.tray" }))
                    : ({ id: "omarchy.tray" })
                region: "right"
                width: Math.max(implicitWidth, panel.compactTrayCollapsedWidth)
                height: implicitHeight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        CyberpunkBarSignal {
            anchors.fill: parent
            z: 20
            enabled: bar.cyberpunkSignalEnabled && !bar.transparent
            triggerEpoch: bar.glitchEpoch
            primaryColor: Color.accent
            secondaryColor: bar.barForeground
            fontFamily: bar.fontFamily
        }

        // Float Compact's vertical tray is a separate cap above the rail.
        // Keep its lower edge fixed beside the main surface so the drawer
        // reveals upward without changing the rail's measured body.
        Item {
            id: compactVerticalTrayFrame
            z: 2
            visible: panel.compactVerticalTrayEnabled
            width: surfaceFrame.width
            height: Math.max(compactVerticalTraySlot.implicitHeight,
                panel.compactVerticalTrayCollapsedHeight)
            x: 0
            y: -height - panel.compactTrayGap

            BorderSurface {
                anchors.fill: parent
                color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
                radius: bar.radius > 0 ? bar.radius : Style.cornerRadius
                borderSpec: !bar.transparent && bar.borderWidth > 0
                    ? Border.flat(Util.alpha(bar.borderColor, bar.borderOpacity), bar.borderWidth)
                    : Border.none()
            }

            Bar.WidgetSlot {
                id: compactVerticalTraySlot
                bar: panel.bar
                active: panel.compactVerticalTrayEnabled
                entry: panel.bar
                    ? (panel.bar.trayEntry(panel.bar.layoutConfig.right) || ({ id: "omarchy.tray" }))
                    : ({ id: "omarchy.tray" })
                region: "right"
                width: parent.width
                height: Math.max(implicitHeight, panel.compactVerticalTrayCollapsedHeight)
                anchors.bottom: parent.bottom
            }
        }
    }
}
