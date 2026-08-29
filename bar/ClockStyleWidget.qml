import QtQuick
import qs.Commons
import "ClockStyleModel.js" as Model

// Visual shell for a styled clock. WidgetSlot keeps the native clock as its
// active item; this item only paints above it and therefore owns no behavior.
Item {
    id: root

    property var bar: null
    property var clock: null

    readonly property string style: Model.normalizeStyle(bar ? bar.clockStyle : "native")
    readonly property string value: clock && clock.displayText !== undefined
        ? String(clock.displayText)
        : "06:53"
    readonly property bool vertical: !!bar && bar.vertical

    implicitWidth: faceLoader.item ? faceLoader.item.implicitWidth : (vertical ? (bar ? bar.barSize : 24) : 78)
    implicitHeight: faceLoader.item ? faceLoader.item.implicitHeight : (vertical ? Style.bar.iconSlot * 3 : (bar ? bar.barSize : 30))

    Loader {
        id: faceLoader
        anchors.fill: parent
        active: root.style !== "native"
        sourceComponent: root.style === "neon"
            ? neonFace
            : root.style === "matrix"
                ? matrixFace
                : root.style === "lcd" ? lcdFace : null
    }

    Component {
        id: neonFace
        NeonSevenSegmentClock {
            bar: root.bar
            value: root.value
            vertical: root.vertical
        }
    }

    Component {
        id: matrixFace
        DotMatrixClock {
            bar: root.bar
            value: root.value
            vertical: root.vertical
        }
    }

    Component {
        id: lcdFace
        RetroLcdClock {
            bar: root.bar
            value: root.value
            vertical: root.vertical
        }
    }
}
