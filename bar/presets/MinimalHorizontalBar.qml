import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    anchors.fill: parent

    Bar.IslandSurface {
        bar: bar
        id: minimalHorizontalSurface
        width: bar.minimalExpanded
            ? parent.width
            : Math.max(bar.barSize, minimalWorkspaceGroup.implicitWidth + Style.space(16))
        height: bar.barSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Bar.WidgetGroup {
            bar: bar
            id: minimalWorkspaceGroup
            region: "left"
            entries: bar.minimalWorkspaceEntries(bar.layoutConfig.left)
            visible: !bar.minimalExpanded
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Bar.WidgetGroup {
            bar: bar
            id: minimalExpandedLeftGroup
            region: "left"
            entries: bar.layoutConfig.left
            visible: bar.minimalExpanded
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Bar.CenterGestureGroup {
            bar: bar
            entries: bar.layoutConfig.center
            visible: bar.minimalExpanded
            anchors.centerIn: parent
        }

        Bar.WidgetGroup {
            bar: bar
            region: "right"
            entries: bar.layoutConfig.right
            visible: bar.minimalExpanded
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
