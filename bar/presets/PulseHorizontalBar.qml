import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    anchors.fill: parent
    implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(5)
        anchors.bottomMargin: Style.space(5)
        color: root.bar && root.bar.transparent ? "transparent" : Util.alpha(
            root.bar ? root.bar.surfaceColor : Color.bar.background,
            root.bar ? root.bar.surfaceOpacity : 1)
        radius: Style.space(6)
        border.color: root.bar && root.bar.transparent ? "transparent" : Util.alpha(
            root.bar ? root.bar.borderColor : Color.accent,
            root.bar ? Math.max(root.bar.borderOpacity, 0.45) : 0.45)
        border.width: root.bar ? Math.max(1, root.bar.borderWidth) : 1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(18)
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Util.alpha(Color.accent, 0.32)
    }

    Bar.WidgetGroup {
        id: leftGroup
        bar: root.bar
        region: "left"
        entries: root.bar ? root.bar.layoutConfig.left : []
        anchors.left: parent.left
        anchors.leftMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        id: centerCore
        anchors.centerIn: parent
        width: Math.max(Style.space(110), centerGroup.implicitWidth + Style.space(28))
        height: Math.max(root.bar ? root.bar.barSize - Style.space(10) : Style.space(24), Style.space(24))
        Rectangle {
            anchors.fill: parent
            color: Util.alpha(Color.accent, 0.08)
            radius: Style.space(4)
            border.color: Util.alpha(Color.accent, 0.7)
            border.width: 1
        }
        PulseTrace { bar: root.bar; anchors.fill: parent }
        Bar.CenterGestureGroup {
            id: centerGroup
            bar: root.bar
            entries: root.bar ? root.bar.layoutConfig.center : []
            anchors.centerIn: parent
        }
    }

    Bar.WidgetGroup {
        id: rightGroup
        bar: root.bar
        region: "right"
        entries: root.bar ? root.bar.entriesWithoutTray(root.bar.layoutConfig.right) : []
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
    }

    Bar.WidgetSlot {
        bar: root.bar
        entry: root.bar ? (root.bar.trayEntry(root.bar.layoutConfig.right) || ({ id: "omarchy.tray" })) : ({ id: "omarchy.tray" })
        region: "right"
        anchors.right: parent.right
        anchors.rightMargin: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
    }
}
