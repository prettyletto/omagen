import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

// Compact Float has its own vertical composition. The generic vertical bar
// stretches across the available rail and distributes its regions over the
// monitor; a floating compact bar must instead measure its content and keep
// the three semantic regions in a small, coherent pill.
Item {
    id: floatingVerticalRoot

    property var bar: null

    readonly property real edgePadding: Style.space(8)
    readonly property real regionGap: Style.space(8)
    readonly property real separatorWidth: Style.space(14)
    readonly property color separatorColor: bar
        ? Util.alpha(bar.barForeground, 0.24) : "transparent"

    readonly property bool hasRightWidgets: rightGroup.implicitHeight > 0
    readonly property bool hasTopRegion: rightRegionHeight > 0
    readonly property bool hasCenter: centerGroup.implicitHeight > 0
    readonly property bool hasLeft: leftGroup.implicitHeight > 0

    // The root's implicit height intentionally excludes edgePadding. The
    // BarSurface host adds the same 8px top/bottom budget when it sizes a
    // content bar, and this content column consumes that budget below.
    readonly property real rightRegionHeight: rightGroup.implicitHeight
    readonly property real topCenterSeparatorHeight: hasTopRegion && hasCenter
        ? regionGap : 0
    readonly property real centerBottomSeparatorHeight: hasCenter && hasLeft
        ? regionGap : 0
    readonly property real naturalHeight: rightRegionHeight
        + topCenterSeparatorHeight
        + centerGroup.implicitHeight
        + centerBottomSeparatorHeight
        + leftGroup.implicitHeight

    implicitWidth: bar && bar.floatingCompact
        ? bar.barSize + Style.space(4) : (bar ? bar.barSize : 0)
    implicitHeight: naturalHeight
    width: implicitWidth
    height: implicitHeight
    clip: true

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: floatingVerticalRoot.edgePadding
        anchors.bottomMargin: floatingVerticalRoot.edgePadding
        spacing: 0

        Item {
            id: topRegion
            width: parent.width
            height: floatingVerticalRoot.rightRegionHeight

            Bar.VerticalWidgetGroup {
                id: rightGroup
                bar: floatingVerticalRoot.bar
                region: "right"
                entries: floatingVerticalRoot.bar
                    ? floatingVerticalRoot.bar.entriesWithoutTray(floatingVerticalRoot.bar.layoutConfig.right)
                    : []
                centerSlots: true
                width: parent.width
                height: implicitHeight
                anchors.top: parent.top
            }

        }

        Item {
            width: parent.width
            height: floatingVerticalRoot.topCenterSeparatorHeight

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, floatingVerticalRoot.separatorWidth)
                height: 1
                color: floatingVerticalRoot.separatorColor
            }
        }

        Item {
            id: centerRegion
            width: parent.width
            height: centerGroup.implicitHeight

            Bar.CenterGestureGroup {
                id: centerGroup
                bar: floatingVerticalRoot.bar
                entries: floatingVerticalRoot.bar ? floatingVerticalRoot.bar.layoutConfig.center : []
                width: parent.width
                height: implicitHeight
            }
        }

        Item {
            width: parent.width
            height: floatingVerticalRoot.centerBottomSeparatorHeight

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, floatingVerticalRoot.separatorWidth)
                height: 1
                color: floatingVerticalRoot.separatorColor
            }
        }

        Item {
            id: bottomRegion
            width: parent.width
            height: leftGroup.implicitHeight

            Bar.VerticalWidgetGroup {
                id: leftGroup
                bar: floatingVerticalRoot.bar
                region: "left"
                entries: floatingVerticalRoot.bar ? floatingVerticalRoot.bar.layoutConfig.left : []
                centerSlots: true
                width: parent.width
                height: implicitHeight
                anchors.bottom: parent.bottom
            }
        }
    }
}
