import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    anchors.fill: parent

    // The host spans the monitor, but each semantic region keeps its
    // own island surface. The right cluster is anchored to the edge so
    // the tray grows left without moving the system island.
    Bar.IslandSurface {
        bar: bar
        id: islandsLeft
        implicitWidth: leftGroup.implicitWidth + Style.space(16)
        implicitHeight: bar.barSize
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        Bar.WidgetGroup {
            bar: bar
            id: leftGroup
            region: "left"
            entries: bar.layoutConfig.left
            anchors.centerIn: parent
        }
    }

    Bar.IslandSurface {
        bar: bar
        id: islandsCenter
        implicitWidth: centerGroup.implicitWidth + Style.space(16)
        implicitHeight: bar.barSize
        anchors.centerIn: parent
        Bar.CenterGestureGroup {
            bar: bar
            id: centerGroup
            entries: bar.layoutConfig.center
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
            bar: bar
            id: islandsTray
            horizontalPadding: 0
            verticalPadding: 0
            implicitWidth: Math.max(bar.barSize, traySlot.implicitWidth)
            implicitHeight: bar.barSize
            Bar.WidgetSlot {
                bar: bar
                id: traySlot
                entry: bar.trayEntry(bar.layoutConfig.right) || ({ id: "omarchy.tray" })
                region: "right"
                anchors.centerIn: parent
            }
        }

        Bar.IslandSurface {
            bar: bar
            id: islandsRight
            implicitWidth: rightGroup.implicitWidth + Style.space(16)
            implicitHeight: bar.barSize
            Bar.WidgetGroup {
                bar: bar
                id: rightGroup
                region: "right"
                entries: bar.entriesWithoutTray(bar.layoutConfig.right)
                anchors.centerIn: parent
            }
        }
    }
}
