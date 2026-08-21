import QtQuick
import qs.Commons

Item {
    id: root

    required property string variant
    required property string label
    property var palette: null
    property string sourceImage: ""
    property string panelStyle: "solid"
    property bool selected: false
    property bool focused: false
    property bool hovered: false
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
    readonly property real uiScale: Math.max(0.82, Math.min(1.2, root.width / 500))
    // The card and preview use the same rounded silhouette.  Do not rely on
    // `clip` for this: Qt clips children to a rectangle, not to this radius.
    readonly property real cardRadius: Math.max(18, Math.min(24, root.width / 22))

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: root.bg
        border.width: 0
        border.color: "transparent"
        opacity: root.enabled ? 1 : 0.48
        transformOrigin: Item.Center
        scale: root.selected && root.enabled ? 1.004 : root.hovered && root.enabled ? 1.008 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: root.hovered ? Util.alpha(Color.accent, 0.035) : "transparent"
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.cardRadius / 2
            anchors.rightMargin: root.cardRadius / 2
            anchors.topMargin: 1
            height: root.selected || root.focused ? 2 : 1
            radius: height / 2
            color: root.selected ? Color.foreground : root.focused ? Color.accent : Util.alpha(root.accent, 0.42)
        }

        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(42, 52 * root.uiScale)
            radius: root.cardRadius
            color: Util.alpha(root.darkBg, 0.55)

            // Restore the lower, square portion of the header.  A fully
            // rounded header alone would carve unwanted crescents above the
            // canvas; this keeps only the two outer corners rounded.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Math.min(root.cardRadius, parent.height)
                anchors.bottom: parent.bottom
                color: parent.color
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.label
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Math.max(12, 14 * root.uiScale)
                    font.bold: true
                }

                Text {
                    text: root.variant === "source" ? "ORIGINAL PALETTE" : "DERIVED VARIANT"
                    color: root.darkFg
                    font.family: Style.font.family
                    font.pixelSize: Math.max(8, 9 * root.uiScale)
                    font.letterSpacing: 1.1
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: [root.red, root.yellow, root.green, root.cyan, root.blue, root.magenta]
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.max(8, 10 * root.uiScale)
                        height: width
                        radius: width / 2
                        color: modelData
                        border.width: 1
                        border.color: Util.alpha(root.fg, 0.22)
                    }
                }
            }
        }

        Rectangle {
            id: canvas
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: footer.top
            anchors.bottomMargin: 10
            radius: Math.max(12, root.cardRadius - 8)
            color: root.darkerBg
            border.width: 0

            Image {
                // Keep the rectangular image pixels clear of the rounded
                // canvas corners.  The canvas colour supplies that small rim.
                anchors.fill: parent
                anchors.margins: Math.max(2, canvas.radius / 3)
                visible: root.sourceImage !== ""
                source: root.sourceImage !== "" ? Util.fileUrl(root.sourceImage) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.07
            }

            Rectangle {
                anchors.fill: parent
                radius: canvas.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Util.alpha(root.bg, 0.24) }
                    GradientStop { position: 1; color: Util.alpha(root.darkerBg, 0.72) }
                }
            }

            Rectangle {
                id: mockWindow
                anchors.fill: parent
                anchors.margins: 8
                radius: Math.max(9, root.cardRadius - 11)
                color: root.bg
                border.width: 0

                Rectangle {
                    id: windowBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(24, 28 * root.uiScale)
                    radius: mockWindow.radius
                    color: root.panelStyle === "neon" ? root.accent : Util.alpha(root.lighterBg, 0.72)

                    SequentialAnimation on color {
                        running: root.panelStyle === "cycle"
                        loops: Animation.Infinite
                        ColorAnimation { to: root.blue; duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: root.magenta; duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: root.accent; duration: 900; easing.type: Easing.InOutSine }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: root.panelStyle === "split"
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.accent }
                            GradientStop { position: 0.5; color: root.accent }
                            GradientStop { position: 0.5; color: root.fg }
                            GradientStop { position: 1; color: root.fg }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: root.panelStyle === "neon"
                        color: "transparent"
                        border.width: 2
                        border.color: Util.alpha(root.accent, neonOpacity)
                        property real neonOpacity: 0.45
                        SequentialAnimation on neonOpacity {
                            running: root.panelStyle === "neon"
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Math.min(mockWindow.radius, parent.height)
                        anchors.bottom: parent.bottom
                        color: parent.color
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: [root.red, root.yellow, root.green]
                            delegate: Rectangle {
                                required property var modelData
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "omagen"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Math.max(9, 10 * root.uiScale)
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "●  ●  ●"
                        color: root.muted
                        font.family: Style.font.family
                        font.pixelSize: Math.max(8, 9 * root.uiScale)
                    }
                }

                Rectangle {
                    id: editor
                    anchors.top: windowBar.bottom
                    anchors.topMargin: 9
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    width: parent.width * 0.56
                    radius: 7
                    color: Util.alpha(root.darkBg, 0.88)
                    border.width: 0

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        Text {
                            text: "sample.go"
                            color: root.darkFg
                            font.family: Style.font.family
                            font.pixelSize: Math.max(9, 10 * root.uiScale)
                        }
                        Text { text: "func main() {"; color: root.magenta; font.family: Style.font.family; font.pixelSize: Math.max(9, 10 * root.uiScale) }
                        Text { text: "  theme := \"omagen\""; color: root.yellow; font.family: Style.font.family; font.pixelSize: Math.max(9, 10 * root.uiScale) }
                        Text { text: "  // generated from image"; color: root.muted; font.family: Style.font.family; font.pixelSize: Math.max(9, 10 * root.uiScale) }
                        Text { text: "  apply(theme)"; color: root.blue; font.family: Style.font.family; font.pixelSize: Math.max(9, 10 * root.uiScale) }
                        Text { text: "}"; color: root.fg; font.family: Style.font.family; font.pixelSize: Math.max(9, 10 * root.uiScale) }

                        Rectangle {
                            width: parent.width
                            height: Math.max(18, 22 * root.uiScale)
                            radius: 4
                            color: Util.alpha(root.selection, 0.9)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                Text { text: "NORMAL"; color: root.accent; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale); font.bold: true }
                                Text { text: "sample.go"; color: root.fg; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale) }
                            }
                        }
                    }
                }

                Rectangle {
                    id: monitor
                    anchors.top: editor.top
                    anchors.left: editor.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    height: (editor.height - 9) * 0.52
                    radius: 7
                    color: Util.alpha(root.darkBg, 0.76)
                    border.width: 0

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 9
                        text: "system · cpu"
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Math.max(8, 9 * root.uiScale)
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        anchors.bottomMargin: 9
                        height: parent.height * 0.54
                        spacing: 4

                        Repeater {
                            model: [0.28, 0.52, 0.42, 0.72, 0.58, 0.84, 0.48, 0.67]
                            delegate: Rectangle {
                                required property real modelData
                                required property int index
                                width: Math.max(3, (monitor.width - 44) / 8)
                                height: parent.height * modelData
                                anchors.bottom: parent.bottom
                                radius: 2
                                color: index % 3 === 0 ? root.yellow : index % 3 === 1 ? root.cyan : root.accent
                            }
                        }
                    }
                }

                Rectangle {
                    id: terminal
                    anchors.top: monitor.bottom
                    anchors.topMargin: 9
                    anchors.left: monitor.left
                    anchors.right: monitor.right
                    anchors.bottom: editor.bottom
                    radius: 7
                    color: Util.alpha(root.darkerBg, 0.82)
                    border.width: 0

                    Column {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 3
                        Text { text: "$ ls"; color: root.green; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale) }
                        Text { text: "src   README"; color: root.blue; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale) }
                        Text { text: "main.go  theme"; color: root.magenta; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale) }
                        Text { text: "✓ ready"; color: root.accent; font.family: Style.font.family; font.pixelSize: Math.max(8, 9 * root.uiScale) }
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: selectedBadge.implicitWidth + 18
                height: 24
                radius: 12
                color: root.selected ? Color.foreground : Util.alpha(Color.background, 0.82)
                border.width: root.selected ? 0 : 1
                border.color: Util.alpha(Color.foreground, 0.72)
                visible: root.selected || root.previewed

                Text {
                    id: selectedBadge
                    anchors.centerIn: parent
                    text: root.selected ? "✓  SELECTED" : "●  LIVE"
                    color: root.selected ? Color.background : Color.accent
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            Rectangle {
                id: hoverHint
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: 66
                height: 24
                radius: 12
                color: Util.alpha(Color.background, 0.82)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.72)
                visible: root.hovered && !root.selected

                Text {
                    anchors.centerIn: parent
                    text: "SELECT"
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        Rectangle {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(48, 58 * root.uiScale)
            radius: root.cardRadius
            color: root.selected ? Util.alpha(Color.foreground, 0.10) : Util.alpha(root.lighterBg, 0.62)

            // As with the header, round only the outside edge of the footer.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(0, parent.height - root.cardRadius)
                color: parent.color
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: root.selected ? "Selected direction" : root.previewed ? "Live preview" : "Ready to explore"
                    color: root.selected ? Color.foreground : root.darkFg
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    text: root.label
                    color: root.fg
                    font.family: Style.font.family
                    font.pixelSize: Math.max(11, 12 * root.uiScale)
                    font.bold: true
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [root.red, root.yellow, root.green, root.cyan, root.blue, root.magenta]
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.max(7, 9 * root.uiScale)
                        height: width
                        radius: 3
                        color: modelData
                    }
                }
            }
        }

        Rectangle {
            id: outerFrame
            anchors.fill: parent
            radius: root.cardRadius
            color: "transparent"
            border.width: root.selected || root.focused ? 2 : 1
            border.color: root.selected
                ? Color.foreground
                : root.focused
                    ? Color.accent
                    : root.hovered
                        ? Util.alpha(root.fg, 0.72)
                        : Util.alpha(root.fg, 0.24)
            z: 30
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.palette !== null
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked(root.variant)
    }
}
