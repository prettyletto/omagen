import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    anchors.fill: parent
    implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

    Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(8)

        CathedralFrame {
            id: leftFrame
            bar: root.bar
            implicitWidth: leftGroup.implicitWidth + Style.space(20)
            implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
            anchors.verticalCenter: parent.verticalCenter
            Bar.WidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.bar ? root.bar.layoutConfig.left : []
                anchors.centerIn: parent
            }
        }

        CathedralFrame {
            id: centerFrame
            bar: root.bar
            implicitWidth: Math.max(Style.space(120), centerGroup.implicitWidth + Style.space(28))
            implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
            anchors.verticalCenter: parent.verticalCenter
            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                anchors.centerIn: parent
            }
        }

        Item {
            width: Math.max(0, parent.width - leftFrame.width - centerFrame.width - rightFrame.width - Style.space(16))
            height: 1
        }

        CathedralFrame {
            id: rightFrame
            bar: root.bar
            implicitWidth: rightGroup.implicitWidth + Style.space(20)
            implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
            anchors.verticalCenter: parent.verticalCenter
            Bar.WidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar ? root.bar.entriesWithoutTray(root.bar.layoutConfig.right) : []
                anchors.centerIn: parent
            }
        }
    }
}
