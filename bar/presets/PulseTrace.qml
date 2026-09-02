import QtQuick
import qs.Commons

Item {
    id: root
    property var bar: null
    property bool vertical: false
    readonly property bool animate: root.bar && root.bar.motionSpec
        && String(root.bar.motionSpec.preset || "native") !== "none"
        && Number(root.bar.motionSpec.duration_ms !== undefined ? root.bar.motionSpec.duration_ms : 180) > 0

    Rectangle {
        id: trace
        color: Color.accent
        radius: Math.min(width, height) / 2
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        width: root.vertical ? Style.space(2) : Style.space(26)
        height: root.vertical ? Style.space(26) : Style.space(2)
        opacity: root.animate ? 0.85 : 0.5

        SequentialAnimation on opacity {
            running: root.animate
            loops: Animation.Infinite
            NumberAnimation { to: 0.22; duration: 240; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.95; duration: 240; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 420 }
        }
    }

    Rectangle {
        color: Color.accent
        opacity: root.animate ? 0.28 : 0.12
        radius: Math.min(width, height) / 2
        anchors.centerIn: parent
        width: root.vertical ? Style.space(8) : Style.space(52)
        height: root.vertical ? Style.space(52) : Style.space(8)
    }
}
