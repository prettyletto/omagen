import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    width: bar ? bar.islandThickness : Style.bar.sizeVertical + Style.space(16)
    height: parent ? parent.height : 0

    Column {
        anchors.fill: parent
        anchors.topMargin: Style.space(14)
        anchors.bottomMargin: Style.space(14)
        spacing: Style.space(8)
        readonly property real flexibleGap: Math.max(Style.space(12),
            (height - topIsland.height - centerIsland.height - bottomIsland.height - trayIsland.height - Style.space(24)) / 2)

        Bar.IslandSurface {
            id: topIsland
            bar: root.bar
            width: parent.width
            implicitHeight: rightGroup.implicitHeight + Style.space(16)
            horizontalPadding: 0
            Bar.VerticalWidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar ? root.bar.entriesWithoutTray(root.bar.layoutConfig.right) : []
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Bar.IslandSurface {
            id: trayIsland
            bar: root.bar
            width: parent.width
            implicitHeight: Math.max(root.bar ? root.bar.barSize : Style.bar.sizeVertical, traySlot.implicitHeight)
            horizontalPadding: 0
            verticalPadding: 0
            Bar.WidgetSlot {
                id: traySlot
                bar: root.bar
                entry: root.bar ? (root.bar.trayEntry(root.bar.layoutConfig.right) || ({ id: "omarchy.tray" })) : ({ id: "omarchy.tray" })
                region: "right"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { width: parent.width; height: parent.flexibleGap }

        Bar.IslandSurface {
            id: centerIsland
            bar: root.bar
            width: parent.width
            implicitHeight: centerGroup.implicitHeight + Style.space(20)
            horizontalPadding: 0
            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { width: parent.width; height: parent.flexibleGap }

        Bar.IslandSurface {
            id: bottomIsland
            bar: root.bar
            width: parent.width
            implicitHeight: leftGroup.implicitHeight + Style.space(16)
            horizontalPadding: 0
            Bar.VerticalWidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.bar ? root.bar.layoutConfig.left : []
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
