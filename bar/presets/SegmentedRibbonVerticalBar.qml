import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root

    property var bar: null

    readonly property real segmentGap: Style.space(2)
    readonly property real segmentPadding: Style.space(8)
    readonly property real topHeight: Math.max(
        root.bar ? root.bar.barSize : Style.bar.sizeVertical,
        rightGroup.implicitHeight + root.segmentPadding)
    readonly property real bottomHeight: Math.max(
        root.bar ? root.bar.barSize : Style.bar.sizeVertical,
        leftGroup.implicitHeight + root.segmentPadding)

    anchors.fill: parent
    implicitWidth: bar ? bar.barSize : Style.bar.sizeVertical

    Column {
        id: ribbonColumn
        anchors.fill: parent
        spacing: root.segmentGap

        Item {
            id: topSegment
            width: parent.width
            height: root.topHeight

            BorderSurface {
                anchors.fill: parent
                color: root.bar && root.bar.transparent
                    ? "transparent"
                    : Util.alpha(root.bar ? root.bar.surfaceColor : Color.bar.background,
                        root.bar ? root.bar.surfaceOpacity : 1)
                borderSpec: root.bar && root.bar.transparent
                    ? Border.none()
                    : Border.flat(Util.alpha(
                        root.bar ? root.bar.borderColor : Color.foreground,
                        root.bar ? Math.max(root.bar.borderOpacity, 0.25) : 0.25),
                        root.bar ? Math.max(1, root.bar.borderWidth) : 1)
                radius: Math.min(Style.cornerRadius, width / 2)
            }

            Bar.VerticalWidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                entries: root.bar
                    ? root.bar.entriesWithTrayFirst(root.bar.layoutConfig.right)
                    : []
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
            }
        }

        Item {
            id: centerSegment
            width: parent.width
            height: Math.max(0, parent.height - root.topHeight
                - root.bottomHeight - root.segmentGap * 2)

            BorderSurface {
                anchors.fill: parent
                color: root.bar && root.bar.transparent
                    ? "transparent"
                    : Util.alpha(Color.accent, 0.08)
                borderSpec: root.bar && root.bar.transparent
                    ? Border.none()
                    : Border.flat(Util.alpha(Color.accent, 0.48), 1)
                radius: Math.min(Style.cornerRadius, width / 2)
            }

            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                width: root.bar ? root.bar.barSize : 0
                anchors.centerIn: parent
            }
        }

        Item {
            id: bottomSegment
            width: parent.width
            height: root.bottomHeight

            BorderSurface {
                anchors.fill: parent
                color: root.bar && root.bar.transparent
                    ? "transparent"
                    : Util.alpha(root.bar ? root.bar.surfaceColor : Color.bar.background,
                        root.bar ? root.bar.surfaceOpacity : 1)
                borderSpec: root.bar && root.bar.transparent
                    ? Border.none()
                    : Border.flat(Util.alpha(
                        root.bar ? root.bar.borderColor : Color.foreground,
                        root.bar ? Math.max(root.bar.borderOpacity, 0.25) : 0.25),
                        root.bar ? Math.max(1, root.bar.borderWidth) : 1)
                radius: Math.min(Style.cornerRadius, width / 2)
            }

            Bar.VerticalWidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.bar ? root.bar.layoutConfig.left : []
                centerSlots: true
                width: root.bar ? root.bar.barSize : 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
            }
        }
    }
}
