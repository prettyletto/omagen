import QtQuick
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
    id: root

    property var bar: null

    readonly property real segmentGap: Style.space(2)
    readonly property real segmentPadding: Style.space(12)

    anchors.fill: parent
    implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

    Row {
        id: ribbonRow
        anchors.fill: parent
        spacing: root.segmentGap

        Item {
            id: leftSegment
            width: Math.max(Style.space(40),
                leftGroup.implicitWidth + root.segmentPadding)
            height: parent.height

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
                radius: Math.min(Style.cornerRadius, height / 2)
            }

            Bar.WidgetGroup {
                id: leftGroup
                bar: root.bar
                region: "left"
                entries: root.bar ? root.bar.layoutConfig.left : []
                anchors.centerIn: parent
            }
        }

        Item {
            id: centerSegment
            width: Math.max(0, ribbonRow.width - leftSegment.width
                - rightSegment.width - root.segmentGap * 2)
            height: parent.height

            BorderSurface {
                anchors.fill: parent
                color: root.bar && root.bar.transparent
                    ? "transparent"
                    : Util.alpha(Color.accent, 0.08)
                borderSpec: root.bar && root.bar.transparent
                    ? Border.none()
                    : Border.flat(Util.alpha(Color.accent, 0.48), 1)
                radius: Math.min(Style.cornerRadius, height / 2)
            }

            Bar.CenterGestureGroup {
                id: centerGroup
                bar: root.bar
                entries: root.bar ? root.bar.layoutConfig.center : []
                anchors.centerIn: parent
            }
        }

        Item {
            id: rightSegment
            width: Math.max(Style.space(40),
                rightGroup.implicitWidth + root.segmentPadding)
            height: parent.height

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
                radius: Math.min(Style.cornerRadius, height / 2)
            }

            Bar.WidgetGroup {
                id: rightGroup
                bar: root.bar
                region: "right"
                // Sections keep the tray in the right semantic region; unlike
                // Orbit it is intentionally part of the ribbon's last band.
                entries: root.bar ? root.bar.layoutConfig.right : []
                anchors.centerIn: parent
            }
        }
    }
}
