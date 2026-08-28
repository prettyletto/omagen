import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    anchors.fill: parent

    Bar.WidgetGroup {
        bar: bar
        region: "left"
        entries: bar.layoutConfig.left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }
    Bar.CenterGestureGroup {
        bar: bar
        region: "center"
        entries: bar.layoutConfig.center
        anchors.centerIn: parent
    }
    Bar.WidgetGroup {
        bar: bar
        region: "right"
        entries: bar.layoutConfig.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
