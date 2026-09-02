import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar
import "../BarSizing.js" as BarSizing

Item {
    id: root

    property var bar: null
    property bool revealHeld: false

    readonly property bool popupActive: !!bar && bar.activePopout
        && (bar.activePopout.opened === undefined || bar.activePopout.opened === true)
        && (bar.activePopout.visible === undefined || bar.activePopout.visible === true)
    readonly property bool pointerActive: !!bar && (bar.barHovered || root.popupActive)
    readonly property bool expanded: revealHeld
    readonly property real groupGap: Style.space(6)
    readonly property real orbitPadding: Style.space(14)
    readonly property real barWidth: bar ? bar.barSize + Style.space(4) : Style.space(28)
    readonly property bool leadingMenu: bar && bottomEntries.length > 0
        && bar.entryId(bottomEntries[0]) === "omarchy.menu"
    readonly property real compactMenuExtent: leadingMenu
        ? (bar ? bar.barSize : Style.bar.iconSlot) : 0
    // Keep every widget mounted across hover transitions. Changing a
    // WidgetGroup model here would destroy and recreate the shell widgets on
    // every reveal, which is especially expensive for panel-owning modules.
    // Vertical Orbit mirrors the horizontal identity: the workspace arm stays
    // present below the center, while a small right-arm peek remains above it.
    readonly property real compactTopHeight: root.prefixExtent(rightGroup, 3, true)
    readonly property real topHeight: root.expanded
        ? rightGroup.implicitHeight
        : root.compactTopHeight
    readonly property real bottomHeight: root.expanded
        ? leftGroup.implicitHeight
        : Math.max(0, leftGroup.implicitHeight - root.compactMenuExtent)
    // Orbit is one composition, so its expanded top arm owns the tray.
    // The detached tray cap belongs only to the original Float preset.
    readonly property var topEntries: bar ? bar.layoutConfig.right : []
    readonly property var centerEntries: bar ? bar.layoutConfig.center : []
    readonly property var bottomEntries: bar ? bar.layoutConfig.left : []
    // Keep the complete asymmetric top/bottom construction inside the rail's
    // measured surface. The heavier arm otherwise leaves a gap on one end and
    // lets the opposite end escape the border.
    readonly property real armBalanceOffset: (bottomFrame.height - topFrame.height) / 2

    implicitWidth: barWidth
    implicitHeight: topHeight + centerOrbit.height + bottomHeight
        + groupGap * 2
    width: implicitWidth
    height: implicitHeight

    function syncReveal() {
        if (root.pointerActive) {
            revealCollapseTimer.stop()
            root.revealHeld = true
        } else {
            revealCollapseTimer.restart()
        }
    }

    function prefixExtent(group, count, vertical) {
        if (!group || !group.children) return 0
        var extent = 0
        var included = 0
        var children = group.children
        for (var i = 0; i < children.length; i++) {
            var child = children[i]
            if (!child || child.moduleName === undefined) continue
            var size = vertical ? Number(child.implicitHeight || child.height || 0)
                : Number(child.implicitWidth || child.width || 0)
            if (size <= 0) continue
            extent += size
            included++
            if (included >= count) break
        }
        return extent
    }

    onBarChanged: syncReveal()
    Component.onCompleted: syncReveal()

    Connections {
        target: root.bar
        function onBarHoveredChanged() { root.syncReveal() }
        function onActivePopoutChanged() { root.syncReveal() }
    }

    Timer {
        id: revealCollapseTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.pointerActive)
                root.revealHeld = false
        }
    }

    Timer {
        id: revealWatchdog
        interval: 250
        repeat: true
        running: root.revealHeld
        onTriggered: {
            if (root.pointerActive) {
                revealCollapseTimer.stop()
            } else if (!revealCollapseTimer.running) {
                revealCollapseTimer.start()
            }
        }
    }

    // Keep the center orbit fixed on the monitor's centerline. A natural
    // Column center would shift it toward whichever arm has more widgets.
    // The top and bottom arms instead construct outward from this anchor.
    Item {
        id: orbitColumn
        anchors.fill: parent

        Item {
            id: topFrame
            width: root.barWidth
            height: root.topHeight
            x: Math.round((parent.width - width) / 2)
            y: centerOrbit.y - height - root.groupGap
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Bar.VerticalWidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.topEntries
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                visible: true
                opacity: 1
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item {
            id: centerOrbit
            width: root.barWidth
            height: root.expanded
                ? Math.max(root.bar ? root.bar.barSize : 0,
                    centerGroup.implicitHeight + root.orbitPadding)
                : BarSizing.collapsedClockExtent(centerGroup.anchorHeight,
                    root.bar ? root.bar.barSize : 0, root.orbitPadding)
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2 - root.armBalanceOffset)
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: orbitMarkers
                anchors.fill: parent
                transformOrigin: Item.Center
                opacity: root.expanded ? 1 : 0.62

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                NumberAnimation on rotation {
                    running: root.expanded
                    from: 0
                    to: 360
                    duration: 900
                    loops: 1
                    easing.type: Easing.OutCubic
                }

                Rectangle {
                    width: Style.space(4)
                    height: width
                    x: Math.round((parent.width - width) / 2)
                    y: Style.space(3)
                    radius: width / 2
                    color: Color.accent
                }

                Rectangle {
                    width: Style.space(3)
                    height: width
                    x: Math.round((parent.width - width) / 2)
                    y: parent.height - height - Style.space(3)
                    radius: width / 2
                    color: Util.alpha(Color.accent, 0.58)
                }
            }

            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.centerEntries
                compactAnchorOnly: !root.expanded
                width: root.bar ? root.bar.barSize : 0
                height: parent.height
                anchors.centerIn: parent
            }
        }

        Item {
            id: bottomFrame
            width: root.barWidth
            height: root.bottomHeight
            x: Math.round((parent.width - width) / 2)
            y: centerOrbit.y + centerOrbit.height + root.groupGap
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Bar.VerticalWidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.bottomEntries
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                visible: true
                opacity: 1
                y: root.expanded ? 0 : -root.compactMenuExtent
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
