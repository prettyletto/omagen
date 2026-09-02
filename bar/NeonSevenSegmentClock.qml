import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "ClockStyleModel.js" as Model

// Presentation-only neon clock. The native clock remains underneath this
// face, which keeps its calendar, format cycling, timezone action, and IPC.
Item {
    id: root

    property var bar: null
    property string value: "06:53"
    property bool vertical: false

    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    // The native vertical clock allocates one Style.bar.iconSlot per line;
    // keep that stride while the rail width still follows the active bar.
    readonly property int lineHeight: vertical ? Style.bar.iconSlot : barSize
    // Preserve the neon accent on opaque bars. Once transparency is active,
    // use the same sampled foreground as native bar widgets so the face stays
    // legible against the wallpaper underneath.
    readonly property color segmentColor: bar && bar.transparent ? bar.barForeground : Color.accent
    readonly property var lines: Model.normalizedLines(value)
    readonly property bool renderable: Model.isSevenSegmentText(value)
    readonly property real digitHeight: vertical
        ? Math.max(10, Math.min(16, lineHeight - 7))
        : Math.max(11, Math.min(17, barSize - 8))
    readonly property real digitWidth: digitHeight * 0.58
    readonly property real characterGap: Math.max(1, digitHeight * 0.10)
    readonly property real colonWidth: Math.max(5, digitHeight * 0.25)

    function characterWidth(character) {
        if (character === ":") return colonWidth
        if (character === ".") return Math.max(3, digitHeight * 0.18)
        if (character === " ") return Math.max(4, digitHeight * 0.28)
        return digitWidth
    }

    function lineWidth(line) {
        var total = 0
        var text = String(line || "")
        for (var index = 0; index < text.length; index++) {
            if (index > 0) total += characterGap
            total += characterWidth(text.charAt(index))
        }
        return total
    }

    // Date/weekday formats fall back to Text because they are not valid
    // seven-segment glyphs. Measure that fallback text itself so it gets the
    // same expanding slot as the custom numeric face.
    readonly property real fallbackWidth: fallbackText.implicitWidth + 12
    readonly property real horizontalWidth: renderable
        ? Math.max(64, lineWidth(lines[0] || "06:53"))
        : Math.max(64, Math.ceil(fallbackWidth))

    implicitWidth: vertical ? barSize : horizontalWidth
    implicitHeight: vertical
        ? Math.max(lineHeight, lines.length * lineHeight)
        : Math.max(barSize, digitHeight + 6)

    function polygon(context, points) {
        context.beginPath()
        context.moveTo(points[0][0], points[0][1])
        for (var index = 1; index < points.length; index++)
            context.lineTo(points[index][0], points[index][1])
        context.closePath()
        context.fill()
    }

    function horizontalSegment(context, x, y, width, thickness) {
        var bevel = Math.max(1, thickness * 0.7)
        polygon(context, [
            [x + bevel, y], [x + width - bevel, y],
            [x + width, y + thickness / 2],
            [x + width - bevel, y + thickness], [x + bevel, y + thickness],
            [x, y + thickness / 2]
        ])
    }

    function verticalSegment(context, x, y, thickness, height) {
        var bevel = Math.max(1, thickness * 0.7)
        polygon(context, [
            [x + thickness / 2, y], [x + thickness, y + bevel],
            [x + thickness, y + height - bevel],
            [x + thickness / 2, y + height], [x, y + height - bevel],
            [x, y + bevel]
        ])
    }

    function paintCharacter(context, character, x, y, height) {
        var normalized = Model.normalizedChar(character)
        var width = height * 0.58
        var thickness = Math.max(1.4, height * 0.14)
        var halfHeight = (height - thickness) / 2
        var segments = Model.segmentsFor(normalized)
        context.fillStyle = root.segmentColor
        context.globalAlpha = 0.96

        if (segments.indexOf("a") >= 0) horizontalSegment(context, x + thickness * 0.35, y, width - thickness * 0.7, thickness)
        if (segments.indexOf("b") >= 0) verticalSegment(context, x + width - thickness, y + thickness * 0.35, thickness, halfHeight - thickness * 0.35)
        if (segments.indexOf("c") >= 0) verticalSegment(context, x + width - thickness, y + height / 2 + thickness * 0.15, thickness, halfHeight - thickness * 0.35)
        if (segments.indexOf("d") >= 0) horizontalSegment(context, x + thickness * 0.35, y + height - thickness, width - thickness * 0.7, thickness)
        if (segments.indexOf("e") >= 0) verticalSegment(context, x, y + height / 2 + thickness * 0.15, thickness, halfHeight - thickness * 0.35)
        if (segments.indexOf("f") >= 0) verticalSegment(context, x, y + thickness * 0.35, thickness, halfHeight - thickness * 0.35)
        if (segments.indexOf("g") >= 0) horizontalSegment(context, x + thickness * 0.35, y + (height - thickness) / 2, width - thickness * 0.7, thickness)
    }

    function paintColon(context, x, y, height) {
        context.fillStyle = root.segmentColor
        context.globalAlpha = 0.96
        var radius = Math.max(1.5, height * 0.075)
        var centerX = x + colonWidth / 2
        context.beginPath()
        context.arc(centerX, y + height * 0.34, radius, 0, Math.PI * 2)
        context.fill()
        context.beginPath()
        context.arc(centerX, y + height * 0.66, radius, 0, Math.PI * 2)
        context.fill()
    }

    function paintDot(context, x, y, height) {
        context.fillStyle = root.segmentColor
        context.globalAlpha = 0.96
        context.beginPath()
        context.arc(x + digitHeight * 0.09, y + height - digitHeight * 0.10, Math.max(1.2, height * 0.07), 0, Math.PI * 2)
        context.fill()
    }

    Canvas {
        id: neonSource
        anchors.fill: parent
        visible: root.renderable
        z: 1
        onPaint: {
            var context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (!root.renderable) return

            var rows = root.lines
            var rowHeight = root.vertical ? height / Math.max(1, rows.length) : height
            var drawHeight = Math.min(root.digitHeight, Math.max(8, rowHeight - 4))
            for (var row = 0; row < rows.length; row++) {
                var line = String(rows[row] || "")
                var lineWidth = root.lineWidth(line)
                var x = (width - lineWidth) / 2
                var y = row * rowHeight + (rowHeight - drawHeight) / 2
                for (var index = 0; index < line.length; index++) {
                    var character = line.charAt(index)
                    if (index > 0) x += root.characterGap
                    if (character === ":") root.paintColon(context, x, y, drawHeight)
                    else if (character === ".") root.paintDot(context, x, y, drawHeight)
                    else root.paintCharacter(context, character, x, y, drawHeight)
                    x += root.characterWidth(character)
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MultiEffect {
        anchors.fill: neonSource
        anchors.margins: -Style.space(5)
        source: neonSource
        visible: root.renderable
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        blurMultiplier: 1.8
        opacity: 0.62
    }

    Text {
        id: fallbackText
        visible: !root.renderable
        anchors.fill: parent
        text: root.value
        color: root.segmentColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: root.vertical ? Math.max(9, root.barSize * 0.42) : Math.max(11, root.barSize * 0.58)
        font.bold: true
        wrapMode: Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    onValueChanged: neonSource.requestPaint()
    onVerticalChanged: neonSource.requestPaint()
    onBarChanged: neonSource.requestPaint()
}
