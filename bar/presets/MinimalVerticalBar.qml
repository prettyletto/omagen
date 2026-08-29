import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: minimalVerticalContent
  property var bar: null
    anchors.fill: parent

    Bar.IslandSurface {
        bar: minimalVerticalContent.bar
        id: minimalVerticalSurface
        width: minimalVerticalContent.bar.barSize
        height: minimalVerticalContent.bar.minimalExpanded
            ? parent.height
            : Math.max(minimalVerticalContent.bar.barSize, minimalVerticalWorkspaceGroup.implicitHeight + Style.space(12))
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
            height: Math.max(minimalVerticalContent.bar.barSize,
                minimalVerticalRightGroup.implicitHeight
                    + minimalVerticalContent.bar.barSize + Style.space(12))
            anchors.top: parent.top

            Bar.VerticalWidgetGroup {
                bar: minimalVerticalContent.bar
                id: minimalVerticalRightGroup
                region: "right"
                entries: minimalVerticalContent.bar.entriesWithoutTray(minimalVerticalContent.bar.layoutConfig.right)
                centerSlots: true
                width: parent.width
                anchors.top: parent.top
                visible: minimalVerticalContent.bar.minimalExpanded
            }

            Bar.WidgetSlot {
                bar: minimalVerticalContent.bar
                id: minimalVerticalTraySlot
                entry: minimalVerticalContent.bar.trayEntry(minimalVerticalContent.bar.layoutConfig.right) || ({ id: "omarchy.tray" })
                region: "right"
                width: minimalVerticalContent.bar.barSize
                x: (parent.width - width) / 2
                // Keep the tray's top edge fixed at the lower edge of
                // the top section while its custom drawer grows down.
                y: minimalVerticalRightGroup.implicitHeight + Style.space(12)
                visible: minimalVerticalContent.bar.minimalExpanded
                z: 10
            }
        }

        Bar.CenterGestureGroup {
            bar: minimalVerticalContent.bar
            id: minimalVerticalCenterGroup
            entries: minimalVerticalContent.bar.layoutConfig.center
            width: parent.width
            visible: minimalVerticalContent.bar.minimalExpanded
            anchors.centerIn: parent
        }

        Bar.VerticalWidgetGroup {
            bar: minimalVerticalContent.bar
            id: minimalVerticalWorkspaceGroup
            region: "left"
            entries: minimalVerticalContent.bar.minimalWorkspaceEntries(minimalVerticalContent.bar.layoutConfig.left)
            centerSlots: true
            width: parent.width
            visible: !minimalVerticalContent.bar.minimalExpanded
            anchors.bottom: parent.bottom
        }

        Bar.VerticalWidgetGroup {
            bar: minimalVerticalContent.bar
            region: "right"
            entries: minimalVerticalContent.bar.layoutConfig.left
            centerSlots: true
            width: parent.width
            visible: minimalVerticalContent.bar.minimalExpanded
            anchors.bottom: parent.bottom
        }
    }
}
