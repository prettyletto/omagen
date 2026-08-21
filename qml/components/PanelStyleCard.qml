import QtQuick
import qs.Commons

Item {
    id: root

    required property string styleKey
    required property string title
    required property string description
    property bool selected: false
    property bool focused: false
    signal clicked()

    implicitHeight: 180
    implicitWidth: 300

    Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: root.selected
            ? Util.alpha(Color.accent, 0.14)
            : root.focused
                ? Util.alpha(Color.foreground, 0.08)
                : Util.alpha(Color.background, 0.34)
        border.width: root.selected || root.focused ? 2 : 1
        border.color: root.selected ? Color.accent : root.focused ? Color.foreground : Util.alpha(Color.foreground, 0.22)

        Column {
            anchors.fill: parent
            anchors.margins: Style.space(14)
            spacing: Style.space(9)

            Item {
                width: parent.width
                height: 76

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Util.alpha(Color.background, 0.72)
                    border.width: 1
                    border.color: Util.alpha(Color.foreground, 0.14)
                }

                Rectangle {
                    id: panelPreview
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 9
                    radius: 9
                    color: Color.accent

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: parent.radius
                        anchors.bottom: parent.bottom
                        color: parent.color
                    }

                    visible: root.styleKey !== "split"
                    opacity: root.styleKey === "neon" ? neonOpacity : 1

                    property real neonOpacity: 0.75
                    SequentialAnimation on neonOpacity {
                        running: root.styleKey === "neon"
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.38; duration: 700; easing.type: Easing.InOutSine }
                    }

                    SequentialAnimation on color {
                        running: root.styleKey === "cycle"
                        loops: Animation.Infinite
                        ColorAnimation { to: Qt.lighter(Color.accent, 1.3); duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: Color.urgent; duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: Color.accent; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 9
                    radius: 9
                    visible: root.styleKey === "split"
                    gradient: Gradient {
                        GradientStop { position: 0; color: Color.accent }
                        GradientStop { position: 0.5; color: Color.accent }
                        GradientStop { position: 0.5; color: Color.foreground }
                        GradientStop { position: 1; color: Color.foreground }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "active window"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }
            }

            Text {
                text: root.title
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }

            Text {
                width: parent.width
                text: root.description
                color: Color.foreground
                opacity: 0.58
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
