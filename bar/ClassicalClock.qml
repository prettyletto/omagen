import QtQuick
import qs.Commons

// Presentation-only classical clock. It keeps the native clock's formatted
// text intact, using a serif face and a fine clockmaker frame rather than
// inventing a second clock or changing the native interaction target.
Item {
    id: root

    property var bar: null
    property string value: "06:53"
    property bool vertical: false

    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    readonly property int lineHeight: vertical ? Style.bar.iconSlot : barSize
    readonly property color inkColor: bar && bar.transparent ? bar.barForeground : Color.accent
    readonly property var lines: String(value || "").split("\n")
    readonly property real textSize: vertical
        ? Math.max(7, Math.min(11, lineHeight * 0.82))
        : Math.max(11, Math.min(16, barSize * 0.56))

    implicitWidth: vertical
        ? barSize
        : Math.max(53, Math.min(160, String(value || "06:53").length * textSize * 0.55 + 12))
    implicitHeight: vertical
        ? Math.max(lineHeight, Math.max(1, lines.length) * lineHeight)
        : Math.max(barSize, textSize + 8)

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.vertical ? 1 : 2
        color: "transparent"
        radius: root.vertical ? 1 : 3
        border.width: 1
        border.color: Util.alpha(root.inkColor, 0.50)
    }

    Text {
        id: classicalText
        anchors.fill: parent
        anchors.leftMargin: root.vertical ? 2 : 5
        anchors.rightMargin: root.vertical ? 2 : 5
        anchors.topMargin: root.vertical ? 1 : 2
        anchors.bottomMargin: root.vertical ? 1 : 2
        text: root.value
        color: root.inkColor
        font.family: "Noto Serif Display"
        font.pixelSize: root.textSize
        font.weight: Font.DemiBold
        font.letterSpacing: root.vertical ? 0 : 0.35
        lineHeight: root.lineHeight
        lineHeightMode: root.vertical ? Text.FixedHeight : Text.ProportionalHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        style: Text.Outline
        styleColor: Util.alpha(Color.background, 0.82)
    }

    // Thin rules give the horizontal version its classical instrument-panel
    // character without adding a large pill or changing the slot's bounds.
    Rectangle {
        visible: !root.vertical
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        y: 1
        height: 1
        color: Util.alpha(root.inkColor, 0.72)
    }

    Rectangle {
        visible: !root.vertical
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        y: parent.height - 2
        height: 1
        color: Util.alpha(root.inkColor, 0.42)
    }
}
