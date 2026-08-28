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
        text: "···"
        color: bar.barForeground
        font.family: bar.fontFamily
        font.pixelSize: Style.bar.iconFont
        font.bold: true
    }

    Row {
        id: dockHorizontalExpandedRow
        visible: bar.dockExpanded
        anchors.centerIn: parent
        spacing: Style.space(4)

        Bar.WidgetGroup {
            bar: bar
            region: "left"; entries: bar.layoutConfig.left }
        Rectangle {
            width: 1
            height: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(bar.barForeground, 0.24)
        }
        Bar.CenterGestureGroup {
            bar: bar
            entries: bar.layoutConfig.center }
        Rectangle {
            width: 1
            height: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(bar.barForeground, 0.24)
        }
        Bar.WidgetGroup {
            bar: bar
            region: "right"; entries: bar.layoutConfig.right }
    }
}
