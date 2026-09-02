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
    readonly property real barHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
    readonly property bool leadingMenu: bar && leftEntries.length > 0
        && bar.entryId(leftEntries[0]) === "omarchy.menu"
    readonly property real compactMenuExtent: leadingMenu ? Style.bar.iconSlot : 0
    readonly property real compactRightWidth: root.prefixExtent(rightGroup, 3, false)
    // The right arm is normally heavier than the workspace arm. If the
    // center anchor is centered in the measured capsule, that imbalance makes
    // the left edge look empty and lets the right edge paint past the border.
    // Bias the construction origin by half the arm difference so the full
    // composition, including the asymmetric arms, stays inside its surface.
    readonly property real armBalanceOffset: (rightFrame.width - leftFrame.width) / 2
    // The compact Orbit is intentionally asymmetric: the workspace arm stays
    // readable, the center anchor stays centered, and three right-side slots
    // remain visible as the cue that more bar is waiting to be constructed.
    // Keep every widget mounted across hover transitions. Changing a
    // WidgetGroup model here would destroy and recreate the shell widgets on
    // every reveal, which is especially expensive for panel-owning modules.
    readonly property var leftEntries: bar ? bar.layoutConfig.left : []
    readonly property var centerEntries: bar ? bar.layoutConfig.center : []
    // Orbit is one composition, so its expanded right arm owns the tray.
    // The detached tray cap belongs only to the original Float preset.
    readonly property var rightEntries: bar ? bar.layoutConfig.right : []

    implicitWidth: leftFrame.width + centerOrbit.width + rightFrame.width
        + groupGap * 2
    implicitHeight: barHeight
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

    // Count the first three mounted right-side slots by their actual measured
    // extents. This keeps a wide status module intact without leaking a fourth
    // icon into the compact entrance.
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

    // A layer-surface leave can be missed while the shell is being rescanned
    // or while a widget hands off to a popup. Poll only while revealed so a
    // stale hover count cannot leave Orbit expanded indefinitely.
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

    // Do not use a Row's natural center for Orbit. The left and right arms
    // are intentionally asymmetric, so a centered Row would move the clock
    // toward the heavier arm. The orbit itself is the fixed center; the arms
    // are positioned around it and grow outward during construction.
    Item {
        id: orbitRow
        anchors.fill: parent

        Item {
            id: leftFrame
            // The workspace arm is Orbit's identity in its resting state.
            // Keep it mounted and visible while the other arms are revealed.
            width: root.expanded
                ? leftGroup.implicitWidth
                : Math.max(0, leftGroup.implicitWidth - root.compactMenuExtent)
            height: root.barHeight
            x: centerOrbit.x - width - root.groupGap
            y: Math.round((parent.height - height) / 2)
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Bar.WidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.leftEntries
                visible: true
                opacity: 1
                x: root.expanded ? 0 : -root.compactMenuExtent
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            id: centerOrbit
            width: root.expanded
                ? Math.max(root.barHeight, centerGroup.implicitWidth + root.orbitPadding)
                : BarSizing.collapsedClockExtent(centerGroup.anchorWidth,
                    root.barHeight, root.orbitPadding)
            height: root.barHeight
            x: Math.round((parent.width - width) / 2 - root.armBalanceOffset)
            y: Math.round((parent.height - height) / 2)
            clip: true

            // This is the construction motion. The surface itself remains a
            // stable full-width layer; only the already-mounted content frame
            // grows to expose the center modules.
            Behavior on width {
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
                    x: parent.width - width - Style.space(3)
                    y: Math.round((parent.height - height) / 2)
                    radius: width / 2
                    color: Color.accent
                }

                Rectangle {
                    width: Style.space(3)
                    height: width
                    x: Style.space(3)
                    y: Math.round((parent.height - height) / 2)
                    radius: width / 2
                    color: Util.alpha(Color.accent, 0.58)
                }
            }

            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.centerEntries
                compactAnchorOnly: !root.expanded
                anchors.fill: parent
            }
        }

        Item {
            id: rightFrame
            // Leave a small right-side peek in the compact capsule. As Orbit
            // expands, the clip opens and reveals the complete right arm.
            width: root.expanded ? rightGroup.implicitWidth : root.compactRightWidth
            height: root.barHeight
            x: centerOrbit.x + centerOrbit.width + root.groupGap
            y: Math.round((parent.height - height) / 2)
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Bar.WidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.rightEntries
                visible: true
                opacity: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
