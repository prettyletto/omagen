import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    width: bar ? bar.barSize + Style.space(16) : Style.bar.sizeVertical
    height: parent ? parent.height : 0

    Column {
        anchors.fill: parent
        anchors.topMargin: Style.space(12)
        anchors.bottomMargin: Style.space(12)
        spacing: Style.space(10)

        CathedralFrame {
            id: topFrame
            bar: root.bar
            width: parent.width
            height: Math.max(root.bar ? root.bar.barSize : Style.bar.sizeVertical,
                rightGroup.implicitHeight + Style.space(16))
            Bar.VerticalWidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar ? root.bar.entriesWithTrayFirst(root.bar.layoutConfig.right) : []
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { width: parent.width; height: Math.max(0, (parent.height - topFrame.height - bottomFrame.height - centerFrame.height - Style.space(16)) / 2) }

        CathedralFrame {
            id: centerFrame
            bar: root.bar
            width: parent.width
            height: Math.max(root.bar ? root.bar.barSize : Style.bar.sizeVertical,
                centerGroup.implicitHeight + Style.space(16))
            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Item { width: parent.width; height: Math.max(0, (parent.height - topFrame.height - bottomFrame.height - centerFrame.height - Style.space(16)) / 2) }

        CathedralFrame {
            id: bottomFrame
            bar: root.bar
            width: parent.width
            height: Math.max(root.bar ? root.bar.barSize : Style.bar.sizeVertical,
                leftGroup.implicitHeight + Style.space(16))
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
}
