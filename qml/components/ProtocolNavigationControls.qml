import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root

    property bool canBack: false
    property bool canForward: false
    property bool busy: false
    property string caption: "HISTORY"

    signal backRequested()
    signal forwardRequested()

    implicitWidth: navigationRow.implicitWidth
    implicitHeight: navigationRow.implicitHeight

    Row {
        id: navigationRow
        spacing: Style.space(5)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.busy ? "MOVING" : root.caption
            color: Color.foreground
            opacity: root.busy ? 0.7 : 0.42
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
        }

        Button {
            width: Style.space(32)
            height: Style.space(32)
            text: "‹"
            fontSize: Style.font.title
            foreground: Color.foreground
            background: Util.alpha(Color.foreground, 0.045)
            bordered: true
            enabled: root.enabled && !root.busy && root.canBack
            tooltipText: "Back through protocol history"
            onClicked: root.backRequested()
        }

        Button {
            width: Style.space(32)
            height: Style.space(32)
            text: "›"
            fontSize: Style.font.title
            foreground: Color.foreground
            background: Util.alpha(Color.foreground, 0.045)
            bordered: true
            enabled: root.enabled && !root.busy && root.canForward
            tooltipText: "Forward through protocol history"
            onClicked: root.forwardRequested()
        }
    }
}
