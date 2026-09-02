import QtQuick
import qs.Commons
import "ClockStyleModel.js" as Model

// Visual shell for a styled clock. WidgetSlot keeps the native clock as its
// active item; this item only paints above it and therefore owns no behavior.
Item {
    id: root

    property var bar: null
    property var clock: null
    // Keep the native slot geometry and interaction target unchanged while
    // making every Omagen face a restrained 75% of that footprint.
    readonly property real visualScale: 0.75

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
        scale: root.visualScale
        transformOrigin: Item.Center
        active: root.style !== "native"
        sourceComponent: root.style === "neon"
            ? neonFace
            : root.style === "matrix"
                ? matrixFace
                : root.style === "lcd"
                    ? lcdFace
                    : root.style === "classical"
                        ? classicalFace
                        : root.style === "gothic" ? gothicFace : null
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

    Component {
        id: classicalFace
        ClassicalClock {
            bar: root.bar
            value: root.value
            vertical: root.vertical
        }
    }

    Component {
        id: gothicFace
        GothicClock {
            bar: root.bar
            value: root.value
            vertical: root.vertical
        }
    }
}
