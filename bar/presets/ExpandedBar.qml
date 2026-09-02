import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: expandedBarContent
  property var bar: null
    anchors.fill: parent

    Bar.WidgetGroup {
        bar: expandedBarContent.bar
        region: "left"
        entries: expandedBarContent.bar.layoutConfig.left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }
    Bar.CenterGestureGroup {
        bar: expandedBarContent.bar
        region: "center"
        entries: expandedBarContent.bar.layoutConfig.center
        anchors.centerIn: parent
    }
    Bar.WidgetGroup {
        bar: expandedBarContent.bar
        region: "right"
        entries: expandedBarContent.bar.layoutConfig.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
