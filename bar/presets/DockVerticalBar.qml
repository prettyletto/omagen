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
        color: dockVerticalContent.bar.transparent ? "transparent" : Util.alpha(dockVerticalContent.bar.surfaceColor, dockVerticalContent.bar.surfaceOpacity)
        radius: Math.min(width, height) / 2
        borderSpec: bar.transparent ? Border.none() : Border.flat(
            Util.alpha(dockVerticalContent.bar.borderColor, Math.max(dockVerticalContent.bar.borderOpacity, 0.25)),
            Math.max(1, dockVerticalContent.bar.borderWidth)
        )
    }

    Bar.DockClosedContent {
        visible: !dockVerticalContent.bar.dockExpanded
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        bar: dockVerticalContent.bar
    }

    Column {
        id: dockVerticalExpandedColumn
        visible: dockVerticalContent.bar.dockExpanded
        anchors.centerIn: parent
        spacing: Style.space(4)

        Bar.VerticalWidgetGroup {
            bar: dockVerticalContent.bar
            region: "right"
            entries: dockVerticalContent.bar.entriesWithoutTray(dockVerticalContent.bar.layoutConfig.right)
            centerSlots: true
            width: dockVerticalContent.bar.barSize
        }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(dockVerticalContent.bar.barForeground, 0.24)
        }
        Bar.WidgetSlot {
            bar: dockVerticalContent.bar
            entry: dockVerticalContent.bar.trayEntry(dockVerticalContent.bar.layoutConfig.right) || ({ id: "omarchy.tray" })
            region: "right"
            width: dockVerticalContent.bar.barSize
            height: implicitHeight
        }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(dockVerticalContent.bar.barForeground, 0.24)
        }
        Bar.CenterGestureGroup {
            bar: dockVerticalContent.bar
            entries: dockVerticalContent.bar.layoutConfig.center; width: dockVerticalContent.bar.barSize }
        Rectangle {
            width: Style.space(16)
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Util.alpha(dockVerticalContent.bar.barForeground, 0.24)
        }
        Bar.VerticalWidgetGroup {
            bar: dockVerticalContent.bar
            region: "left"
            entries: dockVerticalContent.bar.layoutConfig.left
            centerSlots: true
            width: dockVerticalContent.bar.barSize
        }
    }
}
