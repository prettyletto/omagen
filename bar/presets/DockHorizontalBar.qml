import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    id: dockHorizontalContent
    implicitWidth: dockHorizontalExpandedRow.implicitWidth + Style.space(20)
    implicitHeight: bar.dockThickness

    BorderSurface {
        anchors.fill: parent
        color: dockHorizontalContent.bar.transparent ? "transparent" : Util.alpha(dockHorizontalContent.bar.surfaceColor, dockHorizontalContent.bar.surfaceOpacity)
        radius: Math.min(width, height) / 2
        borderSpec: bar.transparent ? Border.none() : Border.flat(
            Util.alpha(dockHorizontalContent.bar.borderColor, Math.max(dockHorizontalContent.bar.borderOpacity, 0.25)),
            Math.max(1, dockHorizontalContent.bar.borderWidth)
        )
    }

    Bar.DockClosedContent {
        visible: !dockHorizontalContent.bar.dockExpanded
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        bar: dockHorizontalContent.bar
    }

    Row {
        id: dockHorizontalExpandedRow
        visible: dockHorizontalContent.bar.dockExpanded
        anchors.centerIn: parent
        spacing: Style.space(4)

        Bar.WidgetGroup {
            bar: dockHorizontalContent.bar
            region: "left"; entries: dockHorizontalContent.bar.layoutConfig.left }
        Rectangle {
            width: 1
            height: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(dockHorizontalContent.bar.barForeground, 0.24)
        }
        Bar.CenterGestureGroup {
            bar: dockHorizontalContent.bar
            entries: dockHorizontalContent.bar.layoutConfig.center
            compactFlow: true }
        Rectangle {
            width: 1
            height: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(dockHorizontalContent.bar.barForeground, 0.24)
        }
        Bar.WidgetGroup {
            bar: dockHorizontalContent.bar
            region: "right"; entries: dockHorizontalContent.bar.layoutConfig.right }
    }
}
