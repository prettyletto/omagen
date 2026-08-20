import QtQuick
import qs.Commons

Item {
    id: root
    required property string variant
    required property string label
    property var palette: null
    property string sourceImage: ""
    property bool selected: false
    property bool previewed: false
    property bool enabled: true
    signal clicked(string variant)

    function c(name, fallback) { return palette && palette[name] ? palette[name] : fallback }
    readonly property color bg: c("background", "#111318")
    readonly property color darkBg: c("dark_background", "#0b0d10")
    readonly property color darkerBg: c("darker_background", "#07080a")
    readonly property color lighterBg: c("lighter_background", "#1c2028")
    readonly property color fg: c("foreground", "#e8e8e8")
    readonly property color darkFg: c("dark_foreground", "#929292")
    readonly property color accent: c("accent", "#8aadf4")
    readonly property color selection: c("selection", "#414559")
    readonly property color muted: c("muted", "#6e738d")
    readonly property color red: c("red", "#ed8796")
    readonly property color yellow: c("yellow", "#eed49f")
    readonly property color green: c("green", "#a6da95")
    readonly property color cyan: c("cyan", "#8bd5ca")
    readonly property color blue: c("blue", "#8aadf4")
    readonly property color magenta: c("magenta", "#c6a0f6")

    Rectangle {
        anchors.fill: parent; radius: 12; color: root.bg; border.width: root.selected ? 2 : 1
        border.color: root.selected ? root.accent : root.muted; opacity: root.enabled ? 1 : .45; clip: true
        Image { anchors.fill: parent; visible: root.sourceImage !== ""; source: root.sourceImage !== "" ? Util.fileUrl(root.sourceImage) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: .16 }
        Rectangle { anchors.fill: parent; color: root.bg; opacity: .84 }
        Rectangle { id: bar; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 24; color: root.darkerBg
            Text { anchors.centerIn: parent; text: "Omagen"; color: root.fg; font.pixelSize: 9; font.family: "monospace" }
            Row { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "1  2  3"; color: root.accent; font.pixelSize: 9; font.family: "monospace" } }
            Row { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Repeater { model: [root.green, root.yellow, root.red]; Rectangle { required property var modelData; width: 5; height: 5; radius: 3; color: modelData } } }
        }
        Rectangle { id: editor; anchors.top: bar.bottom; anchors.topMargin: 8; anchors.left: parent.left; anchors.leftMargin: 8; anchors.bottom: footer.top; anchors.bottomMargin: 8; width: parent.width*.57; radius: 6; color: root.darkBg; border.color: root.selection; border.width: 1
            Column { anchors.fill: parent; anchors.margins: 9; spacing: 4
                Text { text: "sample.go"; color: root.darkFg; font.pixelSize: 9; font.family: "monospace" }
                Text { text: "func main() {"; color: root.magenta; font.pixelSize: 10; font.family: "monospace" }
                Text { text: "  theme := \"omagen\""; color: root.yellow; font.pixelSize: 10; font.family: "monospace" }
                Text { text: "  // generated from image"; color: root.muted; font.pixelSize: 10; font.family: "monospace" }
                Text { text: "  apply(theme)"; color: root.blue; font.pixelSize: 10; font.family: "monospace" }
                Text { text: "}"; color: root.fg; font.pixelSize: 10; font.family: "monospace" }
                Rectangle { width: parent.width; height: 18; radius: 3; color: root.selection; Text { anchors.centerIn: parent; text: "NORMAL  sample.go"; color: root.fg; font.pixelSize: 8; font.family: "monospace" } }
            }
        }
        Rectangle { id: monitor; anchors.top: editor.top; anchors.left: editor.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 8; height: (editor.height-8)*.52; radius: 6; color: root.darkBg; border.color: root.selection; border.width: 1
            Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8; text: "cpu"; color: root.fg; font.pixelSize: 9; font.family: "monospace" }
            Row { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8; height: parent.height*.55; spacing: 3
                Repeater {
                    model: [.30, .52, .42, .73, .58, .84, .48, .67]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: Math.max(3, (monitor.width - 37) / 8)
                        height: parent.height * modelData
                        anchors.bottom: parent.bottom
                        color: index % 3 === 0 ? root.yellow : index % 3 === 1 ? root.cyan : root.accent
                        radius: 1
                    }
                }
            }
        }
        Rectangle { id: terminal; anchors.top: monitor.bottom; anchors.topMargin: 8; anchors.left: monitor.left; anchors.right: monitor.right; anchors.bottom: editor.bottom; radius: 6; color: root.darkerBg; border.color: root.selection; border.width: 1
            Column { anchors.fill: parent; anchors.margins: 8; spacing: 3
                Text { text: "$ ls"; color: root.green; font.pixelSize: 9; font.family: "monospace" }
                Text { text: "src   README"; color: root.blue; font.pixelSize: 9; font.family: "monospace" }
                Text { text: "main.go  theme"; color: root.magenta; font.pixelSize: 9; font.family: "monospace" }
                Text { text: "✓ ready"; color: root.accent; font.pixelSize: 9; font.family: "monospace" }
            }
        }
        Rectangle { id: footer; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 30; color: root.lighterBg
            Row {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Text { text: root.label; color: root.fg; font.pixelSize: 11; font.bold: true }
                Text { visible: root.previewed; text: "LIVE"; color: root.accent; font.pixelSize: 8; font.bold: true }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Repeater {
                    model: [root.red, root.yellow, root.green, root.cyan, root.blue, root.magenta]
                    delegate: Rectangle {
                        required property var modelData
                        width: 9; height: 9; radius: 2; color: modelData
                    }
                }
            }
        }
        Rectangle { anchors.fill: parent; visible: root.selected; color: "transparent"; border.width: 2; border.color: root.accent; radius: 12 }
        MouseArea { anchors.fill: parent; enabled: root.enabled && root.palette !== null; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked(root.variant) }
    }
}
