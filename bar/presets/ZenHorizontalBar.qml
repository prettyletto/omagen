import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    anchors.fill: parent
    implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

    Bar.IslandSurface {
        id: leftIsland
        bar: root.bar
        horizontalPadding: Style.space(12)
        implicitWidth: leftGroup.implicitWidth + Style.space(24)
        implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
        anchors.left: parent.left
        anchors.leftMargin: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        Bar.WidgetGroup {
            id: leftGroup
            bar: root.bar
            region: "left"
            entries: root.bar ? root.bar.layoutConfig.left : []
            anchors.centerIn: parent
        }
    }

    Bar.IslandSurface {
        id: centerIsland
        bar: root.bar
        horizontalPadding: Style.space(18)
        implicitWidth: Math.max(Style.space(104), centerGroup.implicitWidth + Style.space(36))
        implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
        anchors.centerIn: parent
        Bar.CenterGestureGroup {
            id: centerGroup
            bar: root.bar
            entries: root.bar ? root.bar.layoutConfig.center : []
            anchors.centerIn: parent
        }
    }

    Row {
        id: rightCluster
        anchors.right: parent.right
        anchors.rightMargin: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Bar.IslandSurface {
            bar: root.bar
            horizontalPadding: 0
            verticalPadding: 0
            implicitWidth: Math.max(root.bar ? root.bar.barSize : Style.bar.sizeHorizontal, traySlot.implicitWidth)
            implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
            Bar.WidgetSlot {
                id: traySlot
                bar: root.bar
                entry: root.bar ? (root.bar.trayEntry(root.bar.layoutConfig.right) || ({ id: "omarchy.tray" })) : ({ id: "omarchy.tray" })
                region: "right"
                anchors.centerIn: parent
            }
        }

        Bar.IslandSurface {
            bar: root.bar
            implicitWidth: rightGroup.implicitWidth + Style.space(24)
            implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
            Bar.WidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar ? root.bar.entriesWithoutTray(root.bar.layoutConfig.right) : []
                anchors.centerIn: parent
            }
        }
    }

    Rectangle {
        anchors.left: leftIsland.right
        anchors.right: centerIsland.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        height: 1
        color: Util.alpha(root.bar ? root.bar.borderColor : Color.foreground, 0.14)
    }
}
