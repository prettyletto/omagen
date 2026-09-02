import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: islandsHorizontalContent
  property var bar: null
    anchors.fill: parent

    // The host spans the monitor, but each semantic region keeps its
    // own island surface. The right cluster is anchored to the edge so
    // the tray grows left without moving the system island.
    Bar.IslandSurface {
        bar: islandsHorizontalContent.bar
        id: islandsLeft
        implicitWidth: leftGroup.implicitWidth + Style.space(16)
        implicitHeight: islandsHorizontalContent.bar.barSize
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        Bar.WidgetGroup {
            bar: islandsHorizontalContent.bar
            id: leftGroup
            region: "left"
            entries: islandsHorizontalContent.bar.layoutConfig.left
            anchors.centerIn: parent
        }
    }

    Bar.IslandSurface {
        bar: islandsHorizontalContent.bar
        id: islandsCenter
        implicitWidth: centerGroup.implicitWidth + Style.space(16)
        implicitHeight: islandsHorizontalContent.bar.barSize
        anchors.centerIn: parent
        Bar.CenterGestureGroup {
            bar: islandsHorizontalContent.bar
            id: centerGroup
            entries: islandsHorizontalContent.bar.layoutConfig.center
            anchors.centerIn: parent
        }
    }

    Row {
        id: islandsRightCluster
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(12)

        Bar.IslandSurface {
            bar: islandsHorizontalContent.bar
            id: islandsTray
            horizontalPadding: 0
            verticalPadding: 0
            implicitWidth: Math.max(islandsHorizontalContent.bar.barSize, traySlot.implicitWidth)
            implicitHeight: islandsHorizontalContent.bar.barSize
            Bar.WidgetSlot {
                bar: islandsHorizontalContent.bar
                id: traySlot
                entry: islandsHorizontalContent.bar.trayEntry(islandsHorizontalContent.bar.layoutConfig.right) || ({ id: "omarchy.tray" })
                region: "right"
                anchors.centerIn: parent
            }
        }

        Bar.IslandSurface {
            bar: islandsHorizontalContent.bar
            id: islandsRight
            implicitWidth: rightGroup.implicitWidth + Style.space(16)
            implicitHeight: bar.barSize
        Bar.WidgetGroup {
                bar: islandsHorizontalContent.bar
                id: rightGroup
                region: "right"
                entries: islandsHorizontalContent.bar.entriesWithoutTray(islandsHorizontalContent.bar.layoutConfig.right)
                anchors.centerIn: parent
            }
        }
    }
}
