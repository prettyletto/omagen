import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// A restrained LCD treatment for the same native clock content. Unlike the
// pixel faces, this intentionally keeps arbitrary date/weekday formats legible
// instead of replacing them with a reduced representation.
Item {
    id: root

    property var bar: null
    property string value: "06:53"
    property bool vertical: false

    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    // Keep vertical LCD rows on the same stride as the native clock widget.
    readonly property int lineHeight: vertical ? Style.bar.iconSlot : barSize
    readonly property color lcdColor: Color.accent
    readonly property var lines: String(value || "").split("\n")
    readonly property real textSize: vertical
        ? Math.max(9, Math.min(15, lineHeight * 0.50))
        : Math.max(13, Math.min(27, barSize * 0.76))

    implicitWidth: vertical
        ? barSize
        : Math.max(78, Math.min(220, String(value || "06:53").length * textSize * 0.64 + 18))
    implicitHeight: vertical
        ? Math.max(lineHeight, Math.max(1, lines.length) * lineHeight)
        : Math.max(barSize, textSize + 8)

    Rectangle {
        id: lcdSurface
        anchors.fill: parent
        radius: Math.min(6, Math.min(width, height) / 3)
        color: Util.alpha(Color.background, 0.46)
        border.width: 1
        border.color: Util.alpha(root.lcdColor, 0.46)
    }

    Text {
        id: lcdText
        anchors.fill: parent
        anchors.leftMargin: root.vertical ? 1 : 8
        anchors.rightMargin: root.vertical ? 1 : 8
        text: root.value
        color: root.lcdColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: root.textSize
        font.bold: true
        font.letterSpacing: root.vertical ? 0.2 : 1.1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        style: Text.Outline
        styleColor: Util.alpha(Color.background, 0.88)
    }

    MultiEffect {
        anchors.fill: lcdText
        anchors.margins: -Style.space(4)
        source: lcdText
        blurEnabled: true
        blur: 1.0
        blurMax: 24
        blurMultiplier: 1.1
        opacity: 0.30
    }

    Repeater {
        model: root.vertical ? 2 : 3
        delegate: Rectangle {
            required property int index
            anchors.left: lcdSurface.left
            anchors.right: lcdSurface.right
            y: Math.round((index + 1) * lcdSurface.height / (root.vertical ? 3 : 4))
            height: 1
            color: Util.alpha(root.lcdColor, 0.11)
        }
    }
}
