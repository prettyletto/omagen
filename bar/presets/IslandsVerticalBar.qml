import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    width: bar.islandThickness
    height: parent ? parent.height : 0

    Column {
        id: islandsVerticalColumn
        anchors.fill: parent
        spacing: 0
        readonly property real flexibleGap: Math.max(0,
            (height - islandsVerticalTray.height - islandsVerticalRight.height
                - islandsVerticalCenter.height - islandsVerticalLeft.height
                - Style.space(12)) / 2)

            Bar.IslandSurface {
                bar: bar
                id: islandsVerticalRight
                width: parent.width
                height: rightVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.VerticalWidgetGroup {
                    bar: bar
                    id: rightVerticalGroup
                    region: "right"
                    entries: bar.entriesWithoutTray(bar.layoutConfig.right)
                    centerSlots: true
                    width: bar.barSize
                    anchors.centerIn: parent
                }
            }

            Item {
                width: parent.width
                height: Style.space(12)
            }

            Bar.IslandSurface {
                bar: bar
                id: islandsVerticalTray
                x: (bar.islandThickness - width) / 2
                horizontalPadding: 0
                verticalPadding: 0
                implicitWidth: bar.barSize
                implicitHeight: Math.max(bar.barSize, traySlot.implicitHeight)
                Bar.WidgetSlot {
                    bar: bar
                    id: traySlot
                    entry: bar.trayEntry(bar.layoutConfig.right) || ({ id: "omarchy.tray" })
                    region: "right"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                }
            }

            Item {
                width: parent.width
                height: islandsVerticalColumn.flexibleGap
            }

            Bar.IslandSurface {
                bar: bar
                id: islandsVerticalCenter
                width: parent.width
                height: centerVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.CenterGestureGroup {
                    bar: bar
                    id: centerVerticalGroup
                    entries: bar.layoutConfig.center
                    width: bar.barSize
                    anchors.centerIn: parent
                }
            }

            Item {
                width: parent.width
                height: islandsVerticalColumn.flexibleGap
            }

            Bar.IslandSurface {
                bar: bar
                id: islandsVerticalLeft
                width: parent.width
                height: leftVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.VerticalWidgetGroup {
                    bar: bar
                    id: leftVerticalGroup
                    region: "left"
                    entries: bar.layoutConfig.left
                    centerSlots: true
                    width: bar.barSize
                    anchors.centerIn: parent
                }
            }
    }
}
