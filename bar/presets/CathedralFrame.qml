import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root
    property var bar: null
    default property alias contentData: content.data
    property real horizontalPadding: Style.space(12)
    property real verticalPadding: Style.space(6)
    readonly property color frameColor: root.bar ? root.bar.borderColor : Color.foreground
    readonly property real frameBorderWidth: root.bar ? Math.max(2, root.bar.borderWidth) : 2
    readonly property real borderGap: 2
    readonly property real innerBorderOpacity: 0.68
    readonly property color solidSurface: {
        var source = root.bar ? root.bar.surfaceColor : Color.bar.background
        return Qt.rgba(source.r, source.g, source.b, 1)
    }
    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: content.implicitHeight + verticalPadding * 2

    BorderSurface {
        anchors.fill: parent
        color: root.bar && root.bar.transparent ? "transparent"
            : root.solidSurface
        borderSpec: root.bar && root.bar.transparent ? Border.none()
            : Border.flat(Util.alpha(root.frameColor,
                root.bar ? Math.max(root.bar.borderOpacity, 0.5) : 0.5),
                root.frameBorderWidth)
        radius: Math.min(Style.space(2), Math.min(width, height) / 6)
    }

    Rectangle {
        anchors.fill: parent
        // Leave a visible trim gap between the heavy outer border and this
        // fine inset line so the frame reads as two details, not one bar.
        anchors.margins: root.frameBorderWidth + root.borderGap
        color: "transparent"
        border.width: 1
        border.color: root.bar && root.bar.transparent
            ? "transparent" : Util.alpha(root.frameColor, root.innerBorderOpacity)
        radius: Math.min(Style.space(1), Math.min(width, height) / 8)
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
