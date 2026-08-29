import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "ClockStyleModel.js" as Model

// Presentation-only dot-matrix clock. It consumes the native clock's already
// formatted text and never owns clock input or calendar state.
Item {
    id: root

    property var bar: null
    property string value: "06:53"
    property bool vertical: false

    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    // Match the native vertical clock's fixed line stride without changing
    // the rail width selected by the active bar geometry.
    readonly property int lineHeight: vertical ? Style.bar.iconSlot : barSize
    readonly property color dotColor: Color.accent
    readonly property var lines: Model.normalizedLines(value)
    readonly property bool renderable: Model.isMatrixText(value)
    readonly property real cellSize: vertical
        ? Math.max(1, Math.min(3, (lineHeight - 5) / 7))
        : Math.max(2, Math.min(4, (barSize - 6) / 7))
    readonly property real characterGap: Math.max(1, cellSize * 1.45)

    function characterWidth(character) {
        var pattern = Model.matrixFor(character)
        return pattern.length > 0 ? pattern[0].length * cellSize : cellSize * 5
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

    readonly property real horizontalWidth: Math.max(64, lineWidth(lines[0] || "06:53"))
    implicitWidth: vertical ? barSize : horizontalWidth
    implicitHeight: vertical
        ? Math.max(lineHeight, lines.length * lineHeight)
        : Math.max(barSize, cellSize * 7 + 6)

    function paintCharacter(context, character, x, y, cell) {
        var pattern = Model.matrixFor(character)
        if (pattern.length === 0) return
        context.fillStyle = root.dotColor
        context.globalAlpha = 0.95
        var radius = Math.max(0.7, cell * 0.42)
        for (var row = 0; row < pattern.length; row++) {
            for (var column = 0; column < pattern[row].length; column++) {
                if (pattern[row].charAt(column) !== "1") continue
                context.beginPath()
                context.arc(x + cell * (column + 0.5), y + cell * (row + 0.5), radius, 0, Math.PI * 2)
                context.fill()
            }
        }
    }

    Canvas {
        id: matrixSource
        anchors.fill: parent
        visible: root.renderable
        z: 1
        onPaint: {
            var context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (!root.renderable) return

            var rows = root.lines
            var rowHeight = root.vertical ? height / Math.max(1, rows.length) : height
            var gridHeight = root.cellSize * 7
            for (var row = 0; row < rows.length; row++) {
                var line = String(rows[row] || "")
                var lineWidth = root.lineWidth(line)
                var x = (width - lineWidth) / 2
                var y = row * rowHeight + (rowHeight - gridHeight) / 2
                for (var index = 0; index < line.length; index++) {
                    if (index > 0) x += root.characterGap
                    var character = line.charAt(index)
                    root.paintCharacter(context, character, x, y, root.cellSize)
                    x += root.characterWidth(character)
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MultiEffect {
        anchors.fill: matrixSource
        anchors.margins: -Style.space(6)
        source: matrixSource
        visible: root.renderable
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        blurMultiplier: 1.55
        opacity: 0.48
    }

    Text {
        visible: !root.renderable
        anchors.fill: parent
        text: root.value
        color: root.dotColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: root.vertical ? Math.max(9, root.lineHeight * 0.42) : Math.max(11, root.barSize * 0.56)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    onValueChanged: matrixSource.requestPaint()
    onVerticalChanged: matrixSource.requestPaint()
    onBarChanged: matrixSource.requestPaint()
}
