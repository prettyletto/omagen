import QtQuick
import qs.Commons

// Presentation-only gothic clock. The bold serif numerals, dark inset, and
// hand-drawn chamfered frame keep the style distinctive without depending on
// an optional blackletter font or taking ownership of clock behavior.
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
        ? Math.max(7, Math.min(11, lineHeight * 0.86))
        : Math.max(11, Math.min(17, barSize * 0.60))

    implicitWidth: vertical
        ? barSize
        : Math.max(53, Math.min(160, String(value || "06:53").length * textSize * 0.56 + 12))
    implicitHeight: vertical
        ? Math.max(lineHeight, Math.max(1, lines.length) * lineHeight)
        : Math.max(barSize, textSize + 8)

    Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.background, root.vertical ? 0.13 : 0.22)
        radius: root.vertical ? 1 : 3
        border.width: 1
        border.color: Util.alpha(root.inkColor, 0.28)
    }

    Canvas {
        id: gothicFrame
        anchors.fill: parent
        onPaint: {
            var context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (width < 8 || height < 8) return

            var inset = root.vertical ? 2 : 3
            var cut = Math.max(2, Math.min(5, height * 0.20))
            context.strokeStyle = root.inkColor
            context.globalAlpha = 0.78
            context.lineWidth = 1
            context.beginPath()
            context.moveTo(inset + cut, inset)
            context.lineTo(width - inset - cut, inset)
            context.lineTo(width - inset, inset + cut)
            context.lineTo(width - inset, height - inset - cut)
            context.lineTo(width - inset - cut, height - inset)
            context.lineTo(inset + cut, height - inset)
            context.lineTo(inset, height - inset - cut)
            context.lineTo(inset, inset + cut)
            context.closePath()
            context.stroke()

            // Small pointed side marks make the face read as gothic without
            // introducing an unsupported glyph into the clock value.
            context.globalAlpha = 0.62
            var centerY = height / 2
            context.beginPath()
            context.moveTo(inset, centerY)
            context.lineTo(inset + 3, centerY - 2)
            context.lineTo(inset + 3, centerY + 2)
            context.closePath()
            context.fill()
            context.beginPath()
            context.moveTo(width - inset, centerY)
            context.lineTo(width - inset - 3, centerY - 2)
            context.lineTo(width - inset - 3, centerY + 2)
            context.closePath()
            context.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Text {
        id: gothicText
        anchors.fill: parent
        anchors.leftMargin: root.vertical ? 2 : 5
        anchors.rightMargin: root.vertical ? 2 : 5
        anchors.topMargin: root.vertical ? 1 : 2
        anchors.bottomMargin: root.vertical ? 1 : 2
        text: root.value
        color: root.inkColor
        font.family: "Noto Serif Display"
        font.pixelSize: root.textSize
        font.weight: Font.Black
        font.italic: true
        font.letterSpacing: root.vertical ? -0.15 : -0.55
        lineHeight: root.lineHeight
        lineHeightMode: root.vertical ? Text.FixedHeight : Text.ProportionalHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        style: Text.Outline
        styleColor: Util.alpha(Color.background, 0.94)
    }

    onInkColorChanged: gothicFrame.requestPaint()
}
