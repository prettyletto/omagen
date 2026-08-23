import QtQuick
import qs.Commons

Item {
    id: root
    required property string title
    property bool selected: false
    property bool focused: false
    property bool hovered: false
    property bool compact: false
    property string description: ""
    readonly property bool hot: root.hovered
    signal clicked()
    implicitHeight: root.compact ? Style.space(42) : Style.space(54)
    implicitWidth: 150

    Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: root.selected ? Util.alpha(Color.accent, 0.16) : root.focused || root.hovered ? Util.alpha(Color.foreground, 0.08) : Util.alpha(Color.background, 0.28)
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? Color.accent : root.focused || root.hovered ? Util.alpha(Color.foreground, 0.58) : Util.alpha(Color.foreground, 0.2)
        scale: root.hovered ? 1.012 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: root.compact ? Style.font.caption : Style.font.bodySmall
            font.bold: root.selected
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            visible: root.selected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Style.space(6)
            anchors.topMargin: Style.space(4)
            text: "✓"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: root.compact ? Style.font.caption : Style.font.bodySmall
            font.bold: true
        }
    }
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }

    BoundedTooltip {
        anchorItem: root
        text: root.description
    }
}
