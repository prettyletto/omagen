import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root
    property var bar: null
    default property alias contentData: content.data
    property real horizontalPadding: Style.space(10)
    property real verticalPadding: Style.space(5)
    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: content.implicitHeight + verticalPadding * 2

    BorderSurface {
        anchors.fill: parent
        color: root.bar && root.bar.transparent ? "transparent"
            : Util.alpha(root.bar ? root.bar.surfaceColor : Color.bar.background,
                root.bar ? root.bar.surfaceOpacity : 1)
        borderSpec: root.bar && root.bar.transparent ? Border.none()
            : Border.flat(Util.alpha(root.bar ? root.bar.borderColor : Color.foreground,
                root.bar ? Math.max(root.bar.borderOpacity, 0.35) : 0.35),
                root.bar ? Math.max(1, root.bar.borderWidth) : 1)
        radius: Math.min(Style.space(8), Math.min(width, height) / 3)
    }

    Canvas {
        anchors.fill: parent
        opacity: root.bar && root.bar.transparent ? 0.7 : 1
        onPaint: {
            var c = getContext("2d")
            c.reset()
            c.strokeStyle = Util.alpha(root.bar ? root.bar.borderColor : Color.accent, 0.42)
            c.lineWidth = 1
            var inset = Math.max(4, Math.min(width, height) * 0.12)
            var apex = Math.max(inset + 2, height * 0.28)
            c.beginPath()
            c.moveTo(inset, height - inset)
            c.lineTo(inset, apex)
            c.lineTo(width / 2, inset)
            c.lineTo(width - inset, apex)
            c.lineTo(width - inset, height - inset)
            c.stroke()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
    }
}
