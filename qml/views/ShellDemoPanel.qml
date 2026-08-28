import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components

// A live, read-only shell surface for the Shell engine.  This deliberately
// uses the same Quickshell surface vocabulary as the native shell while the
// editor keeps the choices staged in Omagen's session.
PanelWindow {
    id: root

    property bool active: false
    property string monitorName: ""
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property bool glitchEnabled: false
    property int glitchEpoch: 0

    readonly property var targetScreen: root.resolveScreen()
    readonly property string presetChoice: String(root.shellStyle.preset || "default")
    readonly property string surfaceChoice: String(root.shellStyle.surface || "flat")
    readonly property string detailChoice: String(root.shellStyle.detail || "native")
    readonly property string tooltipChoice: String(root.shellStyle.tooltip || "native")
    readonly property string notificationChoice: String(root.shellStyle.notifications || "native")
    readonly property var overrides: root.shellStyle.overrides || ({})
    readonly property int overrideCount: Object.keys(root.overrides).length

    readonly property color canvasColor: {
        if (root.presetChoice === "glass") return Util.alpha(Color.popups.background, 0.78)
        // The panel surface itself is opaque by default. Transparency is a
        // deliberate Shell choice, not a property every generated theme must
        // inherit just because the PanelWindow uses an alpha-capable surface.
        if (root.surfaceChoice === "accent") return Util.alpha(Color.accent, 0.94)
        if (root.surfaceChoice === "contrast") return Color.background
        if (root.surfaceChoice === "layered") return Util.alpha(Color.popups.background, 0.90)
        return Color.popups.background
    }
    readonly property color cardColor: root.presetChoice === "glass"
        ? Util.alpha(Color.foreground, 0.055)
        : root.surfaceChoice === "accent"
        ? Util.alpha(Color.accent, 0.12)
        : root.surfaceChoice === "layered"
            ? Util.alpha(Color.foreground, 0.055)
            : Util.alpha(Color.foreground, 0.035)
    readonly property color detailColor: {
        if (root.detailChoice === "focus") return Color.accent
        if (root.detailChoice === "edge") return Util.alpha(Color.accent, 0.82)
        if (root.detailChoice === "framed") return Util.alpha(Color.foreground, 0.78)
        return Color.popups.border
    }
    readonly property int detailWidth: root.detailChoice === "native" ? 1 : 2
    readonly property color tooltipColor: root.tooltipChoice === "accent" ? Color.accent : Color.tooltip.border
    readonly property color notificationColor: root.notificationChoice === "accent" ? Color.accent : Color.notifications.border

    function resolveScreen() {
        var screens = Quickshell.screens || []
        if (root.monitorName === "" && screens.length > 0)
            return screens[0]
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === root.monitorName)
                return screens[i]
        }
        return screens.length > 0 ? screens[0] : null
    }

    function titleFor(choice) {
        var labels = {
            flat: "Flat", layered: "Layered", contrast: "Contrast", accent: "Accent",
            native: "Native", framed: "Framed", edge: "Edge", focus: "Focus",
            default: "Default", glass: "Glass"
        }
        return labels[choice] || choice
    }

    function overrideValue(key, fallback) {
        var value = root.overrides[key]
        return value === undefined || value === null || String(value) === "" ? fallback : String(value)
    }

    visible: root.active && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagen-shell-demo"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
    }
    margins {
        top: Style.bar.sizeHorizontal + Style.space(24)
        left: Style.space(28)
    }
    implicitWidth: Math.max(
        Style.space(420),
        Math.min(Style.space(760), (root.targetScreen ? root.targetScreen.width * 0.48 : Style.space(760)))
    )
    implicitHeight: Math.max(
        Style.space(420),
        Math.min(Style.space(700), (root.targetScreen ? root.targetScreen.height - Style.bar.sizeHorizontal - Style.space(48) : Style.space(700)))
    )

    BorderSurface {
        anchors.fill: parent
        color: root.canvasColor
        radius: Style.cornerRadius
        borderSpec: Border.flat(root.detailColor, root.detailWidth)

        Components.SignalGlitch {
            anchors.fill: parent
            z: 10
            enabled: root.glitchEnabled
            triggerEpoch: root.glitchEpoch
            accentColor: Color.accent
            secondaryColor: Color.foreground
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(18)
            spacing: Style.space(10)

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(48)

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                        text: "SHELL ENGINE / LIVE READER"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: "Quickshell surface capabilities"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.title
                        font.bold: true
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OMAGEN\nSTUDIO\n" + root.overrideCount + " TOKENS"
                    horizontalAlignment: Text.AlignRight
                    color: Color.foreground
                    opacity: 0.72
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: [
                        { label: "LOOK", value: root.titleFor(root.presetChoice) },
                        { label: "MATERIAL", value: root.presetChoice === "glass" ? "Blurred glass" : "Native" },
                        { label: "PALETTE", value: "Native" },
                        { label: "TOKENS", value: String(root.overrideCount) }
                    ]

                    delegate: BorderSurface {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(42)
                        color: root.cardColor
                        radius: Style.cornerRadius
                        borderSpec: Border.flat(Util.alpha(root.detailColor, 0.58), 1)

                        Column {
                            anchors.centerIn: parent
                            spacing: Style.space(2)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Color.foreground
                                opacity: 0.58
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                            }
                        }
                    }
                }
            }

            BorderSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(44)
                color: Util.alpha(Color.bar.background, root.presetChoice === "glass" ? 0.82 : root.surfaceChoice === "layered" ? 0.82 : 0.96)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Util.alpha(root.detailColor, 0.72), 1)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(12)

                    Text { text: "1  2  3"; color: Color.bar.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "OMAGEN STUDIO"; color: Color.bar.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "NET 100%   21:42"; color: Color.bar.text; opacity: 0.76; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }

            BorderSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(34)
                color: Util.alpha(Color.foreground, 0.025)
                radius: Math.max(Style.space(4), Style.cornerRadius / 2)
                borderSpec: Border.flat(Util.alpha(root.detailColor, 0.52), 1)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(8)
                    Text { text: "TYPE  " + root.overrideValue("font.base-size", "theme"); color: Color.foreground; opacity: 0.78; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { text: "SPACING  " + root.overrideValue("spacing.scale", "1.0") + "×"; color: Color.foreground; opacity: 0.78; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: root.overrideCount + " additive shell token" + (root.overrideCount === 1 ? "" : "s"); color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: Style.space(8)
                columnSpacing: Style.space(8)

                BorderSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.cardColor
                    radius: Style.cornerRadius
                    borderSpec: Border.flat(root.detailColor, root.detailWidth)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(7)

                        Text { text: "POPUP / MENU"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                        Text { text: "Launcher and menu readers"; color: Color.foreground; opacity: 0.66; font.family: Style.font.family; font.pixelSize: Style.font.caption }

                        Repeater {
                            model: ["Appearance", "Window", "Shell", "Bar"]
                            delegate: BorderSurface {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(28)
                                color: modelData === "Shell" ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.foreground, 0.025)
                                radius: Math.max(Style.space(3), Style.cornerRadius / 2)
                                borderSpec: Border.flat(modelData === "Shell" ? root.detailColor : Util.alpha(Color.foreground, 0.10), 1)
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Style.space(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (modelData === "Shell" ? "●  " : "   ") + modelData
                                    color: modelData === "Shell" ? Color.accent : Color.popups.text
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: modelData === "Shell"
                                }
                            }
                        }
                    }
                }

                BorderSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.cardColor
                    radius: Style.cornerRadius
                    borderSpec: Border.flat(root.detailColor, root.detailWidth)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(7)

                        Text { text: "CONTROL SURFACE"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                        Text { text: "Buttons, toggles, and state borders"; color: Color.foreground; opacity: 0.66; font.family: Style.font.family; font.pixelSize: Style.font.caption }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(5)
                            Repeater {
                                model: ["Flat", "Layered", "Accent"]
                                delegate: BorderSurface {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Style.space(30)
                                    color: modelData === root.titleFor(root.surfaceChoice) ? Util.alpha(Color.accent, 0.18) : Util.alpha(Color.foreground, 0.035)
                                    radius: Math.max(Style.space(3), Style.cornerRadius / 2)
                                    borderSpec: Border.flat(modelData === root.titleFor(root.surfaceChoice) ? root.detailColor : Util.alpha(Color.foreground, 0.12), 1)
                                    Text { anchors.centerIn: parent; text: modelData; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: modelData === root.titleFor(root.surfaceChoice) }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(5)
                            Repeater {
                                model: ["Focus state", "Selected state", "Normal state"]
                                delegate: RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: Style.space(8)
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: Style.space(5); radius: 3; color: modelData === "Focus state" ? Color.accent : Util.alpha(Color.foreground, 0.18) }
                                    Text { Layout.preferredWidth: Style.space(86); text: modelData; color: Color.foreground; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)

                BorderSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(72)
                    color: Util.alpha(Color.tooltip.background, root.tooltipChoice === "accent" ? 0.92 : 0.98)
                    radius: Style.cornerRadius
                    borderSpec: Border.flat(root.tooltipColor, root.tooltipChoice === "accent" ? 2 : 1)
                    Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(3)
                        Text { text: "TOOLTIP"; color: root.tooltipColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { text: "Accent-aware hover reader"; color: Color.tooltip.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                        Text { text: root.tooltipChoice === "accent" ? "accent border" : "native border"; color: Color.tooltip.text; opacity: 0.58; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }

                BorderSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(72)
                    color: Util.alpha(Color.notifications.background, root.notificationChoice === "accent" ? 0.92 : 0.98)
                    radius: Style.cornerRadius
                    borderSpec: Border.flat(root.notificationColor, root.notificationChoice === "accent" ? 2 : 1)
                    Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        spacing: Style.space(3)
                        Text { text: "NOTIFICATION"; color: root.notificationColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        Text { text: "Theme preview ready"; color: Color.notifications.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                        Text { text: "Live token refresh   00:08"; color: Color.notifications.countdown; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.presetChoice === "glass"
                    ? "Glass preset · native Quickshell reader · scoped backdrop blur"
                    : "Default preset · native Quickshell reader · Test Live applies the actual tokens"
                color: Color.foreground
                opacity: 0.54
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
