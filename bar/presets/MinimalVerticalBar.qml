import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    anchors.fill: parent

    Bar.IslandSurface {
        bar: bar
        id: minimalVerticalSurface
        width: bar.barSize
        height: bar.minimalExpanded
            ? parent.height
            : Math.max(bar.barSize, minimalVerticalWorkspaceGroup.implicitHeight + Style.space(12))
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        Behavior on height {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // The upper section ends immediately before the center group.
        // The tray is pinned to that lower edge, so its drawer grows
        // down into the center instead of opening upward out of rail.
        Item {
            id: minimalVerticalTopRegion
            width: parent.width
            height: Math.max(bar.barSize,
                minimalVerticalRightGroup.implicitHeight
                    + bar.barSize + Style.space(12))
            anchors.top: parent.top

            Bar.VerticalWidgetGroup {
                bar: bar
                id: minimalVerticalRightGroup
                region: "right"
                entries: bar.entriesWithoutTray(bar.layoutConfig.right)
                centerSlots: true
                width: parent.width
                anchors.top: parent.top
                visible: bar.minimalExpanded
            }

            Bar.WidgetSlot {
                bar: bar
                id: minimalVerticalTraySlot
                entry: bar.trayEntry(bar.layoutConfig.right) || ({ id: "omarchy.tray" })
                region: "right"
                width: bar.barSize
                x: (parent.width - width) / 2
                // Keep the tray's top edge fixed at the lower edge of
                // the top section while its custom drawer grows down.
                y: minimalVerticalRightGroup.implicitHeight + Style.space(12)
                visible: bar.minimalExpanded
                z: 10
            }
        }

        Bar.CenterGestureGroup {
            bar: bar
            id: minimalVerticalCenterGroup
            entries: bar.layoutConfig.center
            width: parent.width
            visible: bar.minimalExpanded
            anchors.centerIn: parent
        }

        Bar.VerticalWidgetGroup {
            bar: bar
            id: minimalVerticalWorkspaceGroup
            region: "left"
            entries: bar.minimalWorkspaceEntries(bar.layoutConfig.left)
            centerSlots: true
            width: parent.width
            visible: !bar.minimalExpanded
            anchors.bottom: parent.bottom
        }

        Bar.VerticalWidgetGroup {
            bar: bar
            region: "right"
            entries: bar.layoutConfig.left
            centerSlots: true
            width: parent.width
            visible: bar.minimalExpanded
            anchors.bottom: parent.bottom
        }
    }
}
