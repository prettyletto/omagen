import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root
    property var bar: null
    anchors.fill: parent
    implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

    CathedralFrame {
        id: barFrame
        bar: root.bar
        anchors.fill: parent
        anchors.leftMargin: Style.space(14)
        anchors.rightMargin: Style.space(14)
        // Let the single bar use nearly the full host height so the heavy
        // frame does not collapse into a compact strip.
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)

        Bar.WidgetGroup {
            id: leftGroup
            bar: root.bar
            region: "left"
            entries: root.bar ? root.bar.layoutConfig.left : []
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Bar.CenterGestureGroup {
            id: centerGroup
            bar: root.bar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            entries: root.bar ? root.bar.layoutConfig.center : []
        }

        Row {
            id: rightCluster
            // The native tray reveals its horizontal drawer inward from the
            // outer edge. Give it a dedicated slot after the other right
            // widgets so Gothic keeps the tray's complete hit area.
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Bar.WidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar ? root.bar.entriesWithoutTray(root.bar.layoutConfig.right) : []
                anchors.verticalCenter: parent.verticalCenter
            }

            Bar.WidgetSlot {
                bar: root.bar
                entry: root.bar ? (root.bar.trayEntry(root.bar.layoutConfig.right) || ({ id: "omarchy.tray" })) : ({ id: "omarchy.tray" })
                region: "right"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
