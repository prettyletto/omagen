import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: islandsVerticalContent
  property var bar: null
    width: islandsVerticalContent.bar.islandThickness
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
                bar: islandsVerticalContent.bar
                id: islandsVerticalRight
                width: parent.width
                height: rightVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.VerticalWidgetGroup {
                    bar: islandsVerticalContent.bar
                    id: rightVerticalGroup
                    region: "right"
                    entries: islandsVerticalContent.bar.entriesWithoutTray(islandsVerticalContent.bar.layoutConfig.right)
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
                bar: islandsVerticalContent.bar
                id: islandsVerticalTray
                x: (islandsVerticalContent.bar.islandThickness - width) / 2
                horizontalPadding: 0
                verticalPadding: 0
                implicitWidth: islandsVerticalContent.bar.barSize
                implicitHeight: Math.max(islandsVerticalContent.bar.barSize, traySlot.implicitHeight)
                Bar.WidgetSlot {
                    bar: islandsVerticalContent.bar
                    id: traySlot
                    entry: islandsVerticalContent.bar.trayEntry(islandsVerticalContent.bar.layoutConfig.right) || ({ id: "omarchy.tray" })
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
                bar: islandsVerticalContent.bar
                id: islandsVerticalCenter
                width: parent.width
                height: centerVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.CenterGestureGroup {
                    bar: islandsVerticalContent.bar
                    id: centerVerticalGroup
                    entries: islandsVerticalContent.bar.layoutConfig.center
                    width: islandsVerticalContent.bar.barSize
                    anchors.centerIn: parent
                }
            }

            Item {
                width: parent.width
                height: islandsVerticalColumn.flexibleGap
            }

            Bar.IslandSurface {
                bar: islandsVerticalContent.bar
                id: islandsVerticalLeft
                width: parent.width
                height: leftVerticalGroup.implicitHeight + Style.space(12)
                horizontalPadding: 0
                verticalPadding: Style.space(6)
                Bar.VerticalWidgetGroup {
                    bar: islandsVerticalContent.bar
                    id: leftVerticalGroup
                    region: "left"
                    entries: islandsVerticalContent.bar.layoutConfig.left
                    centerSlots: true
                    width: islandsVerticalContent.bar.barSize
                    anchors.centerIn: parent
                }
            }
    }
}
