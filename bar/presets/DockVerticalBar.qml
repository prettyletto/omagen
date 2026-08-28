import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    id: dockVerticalContent
    implicitWidth: bar.dockThickness
    implicitHeight: dockVerticalExpandedColumn.implicitHeight + Style.space(20)

    BorderSurface {
        anchors.fill: parent
        color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
        radius: Math.min(width, height) / 2
        borderSpec: bar.transparent ? Border.none() : Border.flat(
            Util.alpha(bar.borderColor, Math.max(bar.borderOpacity, 0.25)),
            Math.max(1, bar.borderWidth)
        )
    }

    Text {
        visible: !bar.dockExpanded
        anchors.centerIn: parent
        text: "⋮"
        color: bar.barForeground
        font.family: bar.fontFamily
        font.pixelSize: Style.bar.iconFont
        font.bold: true
    }

    Column {
        id: dockVerticalExpandedColumn
        visible: bar.dockExpanded
        anchors.centerIn: parent
        spacing: Style.space(4)

        Bar.VerticalWidgetGroup {
            bar: bar
            region: "right"
            entries: bar.entriesWithoutTray(bar.layoutConfig.right)
            centerSlots: true
            width: bar.barSize
        }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(bar.barForeground, 0.24)
        }
        Bar.WidgetSlot {
            bar: bar
            entry: bar.trayEntry(bar.layoutConfig.right) || ({ id: "omarchy.tray" })
            region: "right"
            width: bar.barSize
            height: implicitHeight
        }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(bar.barForeground, 0.24)
        }
        Bar.CenterGestureGroup {
            bar: bar
            entries: bar.layoutConfig.center; width: bar.barSize }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(bar.barForeground, 0.24)
        }
        Bar.VerticalWidgetGroup {
            bar: bar
            region: "left"
            entries: bar.layoutConfig.left
            centerSlots: true
            width: bar.barSize
        }
    }
}
