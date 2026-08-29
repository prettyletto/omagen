import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: minimalHorizontalContent
  property var bar: null
    anchors.fill: parent

    Bar.IslandSurface {
        bar: minimalHorizontalContent.bar
        id: minimalHorizontalSurface
        width: minimalHorizontalContent.bar.minimalExpanded
            ? parent.width
            : Math.max(minimalHorizontalContent.bar.barSize, minimalWorkspaceGroup.implicitWidth + Style.space(16))
        height: minimalHorizontalContent.bar.barSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Bar.WidgetGroup {
            bar: minimalHorizontalContent.bar
            id: minimalWorkspaceGroup
            region: "left"
            entries: minimalHorizontalContent.bar.minimalWorkspaceEntries(minimalHorizontalContent.bar.layoutConfig.left)
            visible: !minimalHorizontalContent.bar.minimalExpanded
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Bar.WidgetGroup {
            bar: minimalHorizontalContent.bar
            id: minimalExpandedLeftGroup
            region: "left"
            entries: minimalHorizontalContent.bar.layoutConfig.left
            visible: minimalHorizontalContent.bar.minimalExpanded
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Bar.CenterGestureGroup {
            bar: minimalHorizontalContent.bar
            entries: minimalHorizontalContent.bar.layoutConfig.center
            visible: minimalHorizontalContent.bar.minimalExpanded
            anchors.centerIn: parent
        }

        Bar.WidgetGroup {
            bar: minimalHorizontalContent.bar
            region: "right"
            entries: minimalHorizontalContent.bar.layoutConfig.right
            visible: minimalHorizontalContent.bar.minimalExpanded
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
