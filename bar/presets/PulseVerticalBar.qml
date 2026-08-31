import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    width: bar ? bar.barSize + Style.space(12) : Style.bar.sizeVertical
    height: parent ? parent.height : 0

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.space(8)
        anchors.bottomMargin: Style.space(8)
        color: root.bar && root.bar.transparent ? "transparent" : Util.alpha(
            root.bar ? root.bar.surfaceColor : Color.bar.background,
            root.bar ? root.bar.surfaceOpacity : 1)
        radius: Style.space(6)
        border.color: root.bar && root.bar.transparent ? "transparent" : Util.alpha(
            root.bar ? root.bar.borderColor : Color.accent,
            root.bar ? Math.max(root.bar.borderOpacity, 0.45) : 0.45)
        border.width: root.bar ? Math.max(1, root.bar.borderWidth) : 1
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: Style.space(16)
        anchors.bottomMargin: Style.space(16)
        spacing: Style.space(8)

        Bar.VerticalWidgetGroup {
            id: rightGroup
            bar: root.bar
            region: "right"
            entries: root.bar ? root.bar.entriesWithTrayFirst(root.bar.layoutConfig.right) : []
            centerSlots: true
            width: root.bar ? root.bar.barSize : 0
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item { width: parent.width; height: Math.max(Style.space(10), (parent.height - rightGroup.height - leftGroup.height - centerCore.height - Style.space(16)) / 2) }

        Item {
            id: centerCore
            width: parent.width
            height: Math.max(Style.space(72), centerGroup.implicitHeight + Style.space(24))
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                color: Util.alpha(Color.accent, 0.08)
                radius: Style.space(4)
                border.color: Util.alpha(Color.accent, 0.7)
                border.width: 1
            }
            PulseTrace { bar: root.bar; vertical: true; anchors.fill: parent }
            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                width: root.bar ? root.bar.barSize : 0
                anchors.centerIn: parent
            }
        }

        Item { width: parent.width; height: Math.max(Style.space(10), (parent.height - rightGroup.height - leftGroup.height - centerCore.height - Style.space(16)) / 2) }

        Bar.VerticalWidgetGroup {
            id: leftGroup
            bar: root.bar
            region: "left"
            entries: root.bar ? root.bar.layoutConfig.left : []
            centerSlots: true
            width: root.bar ? root.bar.barSize : 0
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
