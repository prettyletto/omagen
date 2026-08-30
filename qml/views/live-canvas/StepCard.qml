import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast

// Shared choice surface for wizard decisions.  It deliberately uses the
// shell Button so mouse, keyboard focus, tooltip, and pressed-state behavior
// stay consistent with the rest of Omarchy's UI.
Item {
    id: root

    property string title: ""
    property string description: ""
    property string eyebrow: ""
    property string status: ""
    property bool selected: false
    property bool live: false
    property bool previewing: false
    property bool hasCursor: false
    property bool enabled: true
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent
    property var contentItem: null

    signal clicked()

    implicitHeight: Math.max(Style.space(76), card.implicitHeight)

    Button {
        id: card
        anchors.fill: parent
        text: ""
        fontSize: Style.font.bodySmall
        foreground: root.selected
            ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
            : root.foregroundColor
        accent: root.accentColor
        background: root.selected
            ? root.accentColor
            : Util.alpha(root.foregroundColor, 0.045)
        bordered: true
        hasCursor: root.hasCursor
        enabled: root.enabled
        tooltipText: root.description
        onClicked: root.clicked()

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(10)
            anchors.bottomMargin: Style.space(10)
            spacing: Style.space(3)

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Text {
                    Layout.fillWidth: true
                    text: root.eyebrow.toUpperCase()
                    color: root.selected
                        ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        : root.accentColor
                    opacity: root.selected ? 0.9 : 0.82
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0.9
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.status !== ""
                    text: root.status
                    color: root.selected
                        ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        : root.foregroundColor
                    opacity: root.selected ? 0.9 : 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.selected
                    ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                    : root.foregroundColor
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                color: root.selected
                    ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                    : root.foregroundColor
                opacity: root.selected ? 0.78 : 0.62
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true; visible: false }
        }

        Rectangle {
            visible: root.live || root.previewing
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Style.space(10)
            anchors.bottomMargin: Style.space(8)
            width: liveLabel.implicitWidth + Style.space(12)
            height: Style.space(20)
            radius: Style.space(4)
            color: root.previewing
                ? Util.alpha(root.accentColor, 0.25)
                : Util.alpha(root.accentColor, 0.14)
            border.width: 1
            border.color: Util.alpha(root.accentColor, 0.5)

            Text {
                id: liveLabel
                anchors.centerIn: parent
                text: root.previewing ? "PREVIEWING…" : "LIVE"
                color: root.selected
                    ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                    : root.accentColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }
        }
    }
}
