import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null
    id: compactHorizontalContent
    readonly property real zoneGap: Style.space(8)
    // Compact mode is a self-contained content flow. Each section
    // consumes only its measured width; the center is the middle
    // section in the flow rather than a full-width centered zone.
    readonly property real leftWidth: compactLeftGroup.width
    readonly property real centerWidth: compactCenterGroup.width
    readonly property real rightWidth: compactRightGroup.width
    implicitWidth: leftWidth + centerWidth + rightWidth + zoneGap * 2
    implicitHeight: Math.max(bar.barSize,
        Math.max(compactLeftGroup.height,
            Math.max(compactCenterGroup.height, compactRightGroup.height)))
    width: implicitWidth
    height: implicitHeight

    Bar.WidgetGroup {
        bar: bar
        id: compactLeftGroup
        region: "left"
        entries: bar.layoutConfig.left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        visible: compactLeftGroup.width > 0 && compactCenterGroup.width > 0
        x: compactLeftGroup.width + compactHorizontalContent.zoneGap / 2
        y: Math.round((parent.height - Style.space(16)) / 2)
        width: 1
        height: Style.space(16)
        color: Util.alpha(bar.barForeground, 0.24)
    }

    Bar.CenterGestureGroup {
        bar: bar
        id: compactCenterGroup
        entries: bar.layoutConfig.center
        width: implicitWidth
        height: implicitHeight
        x: compactLeftGroup.width + compactHorizontalContent.zoneGap
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        visible: compactCenterGroup.width > 0 && compactRightGroup.width > 0
        x: compactLeftGroup.width + compactCenterGroup.width
            + compactHorizontalContent.zoneGap * 1.5
        y: Math.round((parent.height - Style.space(16)) / 2)
        width: 1
        height: Style.space(16)
        color: Util.alpha(bar.barForeground, 0.24)
    }

    Bar.WidgetGroup {
        bar: bar
        id: compactRightGroup
        region: "right"
        entries: bar.entriesWithoutTray(bar.layoutConfig.right)
        x: compactLeftGroup.width + compactCenterGroup.width
            + compactHorizontalContent.zoneGap * 2
        anchors.verticalCenter: parent.verticalCenter
    }
}
