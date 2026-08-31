import QtQuick
import QtQuick.Effects
import qs.Commons
import "Contrast.js" as Contrast
import "../../bar/BarSizing.js" as BarSizing

Item {
    id: root

    required property string variant
    required property string label
    property var palette: null
    property string sourceImage: ""
    property string borderStyle: "solid"
    property bool configurationPreview: false
    property int activeSection: 0
    property var desktopStyle: ({ borderStyle: root.borderStyle, borderSize: -1, borderSizeMode: "default", windowOpacity: 100, shape: "native", spacing: "native", depth: "native", inactiveStyle: "native" })
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", colors: ({}), profile: null, spec: null })
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
    readonly property string activeBorderStyle: root.configurationPreview ? (root.desktopStyle.borderStyle || "solid") : root.borderStyle
    readonly property string inactiveWindowStyle: root.configurationPreview ? (root.desktopStyle.inactiveStyle || root.desktopStyle.inactive_style || "native") : "native"
    readonly property string shellPreset: String(root.shellStyle.preset || "default")
    readonly property bool frostedInactivePreview: inactiveWindowStyle === "blur" || inactiveWindowStyle.indexOf("frosted_") === 0
    readonly property real windowOpacity: Math.max(0, Math.min(1, Number(root.desktopStyle.windowOpacity !== undefined ? root.desktopStyle.windowOpacity : root.desktopStyle.window_opacity !== undefined ? root.desktopStyle.window_opacity : 100) / 100))
    readonly property real previewBorderWidth: !root.configurationPreview || Number(root.desktopStyle.borderSize) < 0
        ? 2 : Number(root.desktopStyle.borderSize)
    readonly property real windowRadius: !root.configurationPreview ? Math.max(9, root.cardRadius - 11)
        // Match the Hyprland output: Native keeps the theme baseline, then
        // five semantic presets increase rounding without exposing compositor
        // implementation details in the preview.
        : root.desktopStyle.shape === "pill" ? 18
        : root.desktopStyle.shape === "rounded" ? 10
        : root.desktopStyle.shape === "soft" ? 5
        : root.desktopStyle.shape === "subtle" ? 2 : 0
    readonly property real windowMargin: root.configurationPreview && root.desktopStyle.spacing === "airy" ? 14
        : root.configurationPreview && root.desktopStyle.spacing === "compact" ? 5 : 8
    readonly property real paneGap: root.configurationPreview && root.desktopStyle.spacing === "airy" ? 12
        : root.configurationPreview && root.desktopStyle.spacing === "compact" ? 5 : 9
    readonly property real paneInset: root.configurationPreview && root.desktopStyle.spacing === "airy" ? 12
        : root.configurationPreview && root.desktopStyle.spacing === "compact" ? 7 : 9
    readonly property var barSpec: root.barStyle.spec || ({})
    readonly property string barTopology: root.barSpec.topology || (root.barStyle.visibility === "islands" ? "sections" : root.barStyle.form === "docked" ? "sections" : "continuous")
    readonly property string barPosition: root.barSpec.position || "top"
    readonly property bool verticalBar: root.barPosition === "left" || root.barPosition === "right"
    readonly property string barDensity: String(root.barSpec.geometry && root.barSpec.geometry.density || root.barStyle.density || "native")
    readonly property real previewBarHeight: BarSizing.baseSize(
        root.barDensity,
        root.verticalBar,
        Style.bar.sizeHorizontal,
        Style.bar.sizeVertical,
        Style.barScaleWithFont,
        Style.fontScale
    )
    readonly property real barOpacity: ["preset", "opaque"].indexOf(String(root.barSpec.surface && root.barSpec.surface.treatment || "preset")) >= 0
        ? 1
        : (root.barSpec.surface && root.barSpec.surface.opacity !== undefined ? Math.max(0, Math.min(1, Number(root.barSpec.surface.opacity))) : 1)
    readonly property int barRadius: root.barSpec.geometry && root.barSpec.geometry.radius !== undefined ? Number(root.barSpec.geometry.radius) : 0
    readonly property int barEdgeOffset: root.barSpec.geometry && root.barSpec.geometry.edge_offset !== undefined ? Math.max(0, Number(root.barSpec.geometry.edge_offset)) : 0
    readonly property int barOuterMargin: root.barSpec.geometry && root.barSpec.geometry.outer_margin !== undefined ? Math.max(0, Number(root.barSpec.geometry.outer_margin)) : 0
    readonly property int barThickness: root.barSpec.geometry && Number(root.barSpec.geometry.thickness) > 0
        ? Number(root.barSpec.geometry.thickness)
        : root.previewBarHeight + BarSizing.structuralPadding(root.barSpec, root.verticalBar ? Style.space(16) : 0)
    readonly property int barBorderWidth: root.barSpec.surface && root.barSpec.surface.border_width !== undefined ? Math.max(0, Number(root.barSpec.surface.border_width)) : 0
    readonly property real barBorderOpacity: root.barSpec.surface && root.barSpec.surface.border_opacity !== undefined ? Math.max(0, Math.min(1, Number(root.barSpec.surface.border_opacity))) : 0
    readonly property int barMotionDuration: root.barSpec.motion && root.barSpec.motion.duration_ms !== undefined ? Math.max(0, Number(root.barSpec.motion.duration_ms)) : 150
    readonly property bool separatedBar: ["sections", "islands", "split", "notch"].indexOf(root.barTopology) >= 0

    function shellPopupSurface() {
        if (root.shellPreset === "glass") return root.bg
        var surface = root.shellStyle.surface || "flat"
        if (surface === "layered") return root.darkBg
        if (surface === "contrast") return root.lighterBg
        if (surface === "accent") return root.darkBg
        return root.bg
    }

    function shellControlSurface() {
        if (root.shellPreset === "glass") return root.lighterBg
        var surface = root.shellStyle.surface || "flat"
        if (surface === "contrast") return root.darkBg
        if (surface === "accent") return root.lighterBg
        return root.lighterBg
    }

    function shellSelectedSurface() {
        if (root.shellStyle.surface === "accent") return Util.alpha(root.accent, 0.18)
        return root.shellStyle.surface === "contrast" ? root.accent : root.selection
    }

    function barSurface() {
        if (root.barStyle.colors && root.barStyle.colors.background) return root.barStyle.colors.background
        var role = root.barSpec.surface && root.barSpec.surface.role ? root.barSpec.surface.role : root.barStyle.surface
        if (role === "background") return root.bg
        if (role === "selection") return root.selection
        if (role === "transparent") return root.bg
        switch (role) {
        case "dark": return root.darkBg
        case "light": return root.fg
        case "accent": return root.accent
        default: return root.bg
        }
    }

    function barForeground() {
        if (root.barStyle.colors && root.barStyle.colors.text) return root.barStyle.colors.text
        var role = root.barSpec.surface && root.barSpec.surface.role ? root.barSpec.surface.role : root.barStyle.surface
        return role === "light" || role === "accent" ? root.bg : root.fg
    }

    function barActive() {
        if (root.barStyle.colors && root.barStyle.colors.active) return root.barStyle.colors.active
        return root.barStyle.attention === "accent" ? root.accent : root.red
    }

    function barBorderColor() {
        var role = root.barSpec.surface && root.barSpec.surface.border_role ? root.barSpec.surface.border_role : "foreground"
        if (role === "accent") return root.accent
        if (role === "custom") return root.accent
        return root.fg
    }

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
                id: shellBar
                visible: root.configurationPreview
                x: root.verticalBar ? (root.barPosition === "right" ? parent.width - width - root.barOuterMargin : root.barOuterMargin) : root.windowMargin + (root.barTopology === "dock" ? parent.width * 0.18 : 0)
                y: root.verticalBar ? root.windowMargin : (root.barPosition === "bottom" ? parent.height - height - root.barEdgeOffset : root.barEdgeOffset)
                width: root.verticalBar ? root.barThickness : parent.width - 2 * root.windowMargin - (root.barTopology === "dock" ? parent.width * 0.36 : 0)
                height: root.verticalBar ? parent.height - 2 * root.windowMargin : root.barThickness
                radius: root.barRadius > 0 ? Math.min(root.barRadius, height / 2) : Math.min(root.windowRadius, height / 2)
                color: root.separatedBar ? "transparent" : Util.alpha(root.barSurface(), root.barOpacity)
                border.width: root.separatedBar ? 0 : root.activeSection === 2 ? Math.max(2, root.barBorderWidth) : root.barBorderWidth
                border.color: root.activeSection === 2 ? root.accent : Util.alpha(root.barBorderColor(), root.barBorderOpacity)
                opacity: root.barOpacity > 0 ? 1 : 0.72

                Behavior on height { NumberAnimation { duration: root.barMotionDuration; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: root.barMotionDuration; easing.type: Easing.OutCubic } }

                Repeater {
                    model: root.separatedBar ? [
                        { x: 0.00, width: 0.30 },
                        { x: 0.36, width: 0.28 },
                        { x: 0.70, width: 0.30 }
                    ] : []
                    delegate: Rectangle {
                        required property var modelData
                        x: root.verticalBar ? 0 : parent.width * modelData.x
                        y: root.verticalBar ? parent.height * modelData.x : 0
                        width: root.verticalBar ? parent.width : parent.width * modelData.width
                        height: root.verticalBar ? parent.height * modelData.width : parent.height
                        radius: Math.min(root.barRadius > 0 ? root.barRadius : root.windowRadius, Math.min(width, height) / 2)
                        color: Util.alpha(root.barSurface(), root.barOpacity)
                        border.width: root.barBorderWidth
                        border.color: root.activeSection === 2 ? Util.alpha(root.accent, 0.78) : Util.alpha(root.barBorderColor(), root.barBorderOpacity)
                    }
                }

                Row {
                    visible: !root.verticalBar
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.barDensity === "compact" ? 3 : 5

                    Repeater {
                        model: ["1", "2", "3"]
                        delegate: Rectangle {
                            required property string modelData
                            width: root.barDensity === "comfortable" ? 24 : root.barDensity === "compact" ? 15 : 19
                            height: parent.parent.height - (root.barDensity === "compact" ? 8 : 10)
                            radius: Math.min(5, height / 3)
                            color: modelData === "1" ? Util.alpha(root.barActive(), 0.28) : "transparent"
                            border.width: modelData === "1" ? 1 : 0
                            border.color: root.barActive()
                            Text { anchors.centerIn: parent; text: modelData; color: modelData === "1" ? root.barForeground() : root.muted; font.family: Style.font.family; font.pixelSize: 8 }
                        }
                    }
                }

                Rectangle {
                    visible: !root.verticalBar
                    anchors.centerIn: parent
                    width: Math.max(74, parent.width * 0.25)
                    height: Math.max(14, parent.height - 10)
                    radius: Math.min(5, height / 3)
                    color: Util.alpha(root.barForeground(), 0.10)
                    border.width: 1
                    border.color: Util.alpha(root.barForeground(), 0.16)

                    Text {
                        anchors.centerIn: parent
                        text: "◌  omagen"
                        color: root.barForeground()
                        opacity: 0.78
                        font.family: Style.font.family
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                Row {
                    visible: !root.verticalBar
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text { text: "NET"; color: root.barForeground(); opacity: 0.7; font.family: Style.font.family; font.pixelSize: 7; font.bold: true }
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.barActive()
                    }
                    Text { text: "10:42"; color: root.barForeground(); font.family: Style.font.family; font.pixelSize: 8; font.bold: true }
                }

                Text {
                    visible: root.verticalBar
                    anchors.centerIn: parent
                    text: "omagen"
                    color: root.barForeground()
                    rotation: root.barPosition === "left" ? 90 : -90
                    font.family: Style.font.family
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            Rectangle {
                visible: root.configurationPreview && root.desktopStyle.depth === "shadow"
                anchors.left: mockWindow.left
                anchors.right: mockWindow.right
                anchors.top: mockWindow.top
                anchors.bottom: mockWindow.bottom
                anchors.leftMargin: 5
                anchors.rightMargin: -5
                anchors.topMargin: 7
                anchors.bottomMargin: -7
                radius: root.windowRadius + 2
                color: Util.alpha(root.darkerBg, 0.72)
            }

            Item {
                id: neonGlowPreview
                visible: root.configurationPreview && root.activeBorderStyle === "neon"
                anchors.fill: mockWindow
                anchors.margins: -10
                z: 1

                Rectangle {
                    id: neonGlowSource
                    anchors.fill: parent
                    radius: root.windowRadius + 10
                    color: "transparent"
                    border.width: root.previewBorderWidth + 2
                    border.color: Util.alpha(root.magenta, 0.9)
                }

                MultiEffect {
                    anchors.fill: neonGlowSource
                    source: neonGlowSource
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 32
                    blurMultiplier: 1.35
                    opacity: neonGlowPreview.glowOpacity
                }

                // Hyprland's compositor glow is static; the animated part of
                // Neon Blend is the borderangle gradient below.
                property real glowOpacity: 0.68
            }

            Rectangle {
                id: mockWindow
                anchors.top: root.configurationPreview ? shellBar.bottom : parent.top
                anchors.topMargin: root.windowMargin
                anchors.left: parent.left
                anchors.leftMargin: root.windowMargin
                anchors.right: parent.right
                anchors.rightMargin: root.windowMargin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.windowMargin
                radius: root.windowRadius
                color: root.bg
                border.width: root.configurationPreview && (root.activeBorderStyle === "solid" || root.activeBorderStyle === "neon") ? root.previewBorderWidth : 0
                border.color: root.activeBorderStyle === "neon" ? root.magenta
                    : root.accent
                opacity: root.configurationPreview && root.activeSection === 1 ? 0.34
                    : root.configurationPreview && root.activeSection === 2 ? 0.78
                    : root.configurationPreview && root.desktopStyle.depth === "flat" ? 0.94 * root.windowOpacity
                    : root.configurationPreview ? root.windowOpacity : 1

                Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Item {
                    id: inactivePanePreview
                    visible: root.configurationPreview && root.inactiveWindowStyle !== "native"
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 12
                    anchors.bottomMargin: 14
                    width: Math.max(86, parent.width * 0.28)
                    height: Math.max(58, parent.height * 0.24)
                    z: 3

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.inactiveWindowStyle === "shadow" ? -6 : -2
                        radius: root.windowRadius + 2
                        color: root.inactiveWindowStyle === "shadow" ? Util.alpha(root.darkerBg, 0.62) : "transparent"
                        border.width: root.inactiveWindowStyle === "shadow" ? 2 : 1
                        border.color: Util.alpha(root.darkFg, root.inactiveWindowStyle === "shadow" ? 0.34 : 0.18)
                    }

                    Item {
                        id: inactivePaneSource
                        anchors.fill: parent
                        // This card deliberately represents transparency only.
                        // Hyprland blurs the backdrop behind a real surface; Qt
                        // must not pretend it can blur the application's pixels.
                        opacity: root.inactiveWindowStyle === "shadow" ? 0.52
                            : root.inactiveWindowStyle === "frosted_light" ? 0.80
                            : root.inactiveWindowStyle === "frosted_rich" ? 0.62
                            : 0.68

                        Rectangle {
                            anchors.fill: parent
                            radius: root.windowRadius
                            color: root.lighterBg
                            border.width: 1
                            border.color: Util.alpha(root.darkFg, 0.48)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.frostedInactivePreview ? "inactive · frosted backdrop" : "inactive · soft dim"
                            color: root.darkFg
                            font.family: Style.font.family
                            font.pixelSize: Math.max(7, 8 * root.uiScale)
                            font.bold: true
                        }
                    }

                }

                Rectangle {
                    visible: root.configurationPreview && root.activeBorderStyle === "split_top"
                    anchors.left: parent.left; anchors.top: parent.top; anchors.right: parent.right
                    height: root.previewBorderWidth; radius: parent.radius
                    color: root.accent
                }
                Rectangle {
                    visible: root.configurationPreview && root.activeBorderStyle === "split_bottom"
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: root.previewBorderWidth; radius: parent.radius
                    color: root.accent
                }
                Rectangle {
                    visible: root.configurationPreview && root.activeBorderStyle === "blend"
                    anchors.left: parent.left; anchors.top: parent.top; anchors.right: parent.right
                    height: root.previewBorderWidth; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.accent }
                        GradientStop { position: 1; color: root.blue }
                    }
                }
                Rectangle {
                    id: spinningBorderPreview
                    visible: root.configurationPreview && root.activeBorderStyle === "spin"
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: root.previewBorderWidth
                    border.color: spinningBorderPreview.spinBorderColor
                    property color spinBorderColor: root.accent
                    SequentialAnimation on spinBorderColor {
                        running: spinningBorderPreview.visible
                        loops: Animation.Infinite
                        ColorAnimation { to: root.blue; duration: 1200; easing.type: Easing.Linear }
                        ColorAnimation { to: root.magenta; duration: 1200; easing.type: Easing.Linear }
                        ColorAnimation { to: root.accent; duration: 1200; easing.type: Easing.Linear }
                    }
                }
                Rectangle {
                    visible: root.configurationPreview && root.activeBorderStyle === "blend"
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: root.previewBorderWidth; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.blue }
                        GradientStop { position: 1; color: root.accent }
                    }
                }

                Rectangle {
                    id: windowBar
                    visible: !root.configurationPreview
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(24, 28 * root.uiScale)
                    radius: mockWindow.radius
                    color: Util.alpha(root.lighterBg, 0.72)

                    SequentialAnimation on color {
                        running: false
                        loops: Animation.Infinite
                        ColorAnimation { to: root.blue; duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: root.magenta; duration: 900; easing.type: Easing.InOutSine }
                        ColorAnimation { to: root.accent; duration: 900; easing.type: Easing.InOutSine }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: !root.configurationPreview && (root.activeBorderStyle === "split" || root.activeBorderStyle === "split_top" || root.activeBorderStyle === "split_bottom" || root.activeBorderStyle === "blend")
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.activeBorderStyle === "split_bottom" ? root.fg : root.accent }
                            GradientStop { position: 0.5; color: root.activeBorderStyle === "split_bottom" ? root.fg : root.accent }
                            GradientStop { position: 0.5; color: root.activeBorderStyle === "blend" ? root.blue : root.activeBorderStyle === "split_bottom" ? root.accent : root.fg }
                            GradientStop { position: 1; color: root.activeBorderStyle === "blend" ? root.blue : root.activeBorderStyle === "split_bottom" ? root.accent : root.fg }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: !root.configurationPreview && root.activeBorderStyle === "neon"
                        color: "transparent"
                        border.width: 2
                        border.color: Util.alpha(root.accent, neonOpacity)
                        property real neonOpacity: 0.45
                        SequentialAnimation on neonOpacity {
                            running: false
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
                    anchors.top: root.configurationPreview ? parent.top : windowBar.bottom
                    anchors.topMargin: root.paneGap
                    anchors.left: parent.left
                    anchors.leftMargin: root.paneInset
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.paneInset
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
                    anchors.leftMargin: root.paneGap
                    anchors.right: parent.right
                    anchors.rightMargin: root.paneInset
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
                    anchors.top: monitor.bottom
                    anchors.topMargin: root.paneGap
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
                visible: quickShellPanel.visible
                anchors.fill: quickShellPanel
                anchors.leftMargin: 7
                anchors.rightMargin: -7
                anchors.topMargin: 8
                anchors.bottomMargin: -8
                radius: quickShellPanel.radius + 2
                color: Util.alpha(root.darkerBg, 0.72)
                z: 3
            }

            Rectangle {
                id: quickShellPanel
                visible: root.configurationPreview && root.activeSection === 1
                anchors.centerIn: mockWindow
                width: Math.min(mockWindow.width * 0.68, 390 * root.uiScale)
                height: Math.min(mockWindow.height * 0.78, 360 * root.uiScale)
                radius: root.shellPreset === "glass" ? 14 : root.shellStyle.surface === "flat" ? 8 : 14
                color: root.shellPreset === "glass" ? Util.alpha(root.shellPopupSurface(), 0.76) : root.shellPopupSurface()
                border.width: root.shellPreset === "glass" ? 1 : root.shellStyle.detail === "framed" ? 2 : 1
                border.color: root.shellPreset === "glass" || root.shellStyle.detail === "focus" || root.shellStyle.surface === "accent"
                    ? root.accent : Util.alpha(root.fg, 0.34)
                z: 4

                Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    visible: root.shellStyle.detail === "edge"
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    radius: parent.radius
                    color: root.accent
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 30
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text { text: "QUICK SHELL"; color: root.accent; font.family: Style.font.family; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.2 }
                            Text { text: "Application launcher"; color: root.fg; font.family: Style.font.family; font.pixelSize: 11; font.bold: true }
                        }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "ESC"; color: root.muted; font.family: Style.font.family; font.pixelSize: 8; font.bold: true }
                    }

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 7
                        color: Util.alpha(root.shellControlSurface(), 0.92)
                        border.width: root.shellStyle.tooltip === "accent" || root.shellStyle.detail === "focus" || root.shellStyle.detail === "framed" ? 1 : 0
                        border.color: root.shellStyle.tooltip === "accent" ? root.accent : root.shellStyle.detail === "focus" ? root.accent : Util.alpha(root.fg, 0.36)
                        Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "⌕  Search applications…"; color: root.darkFg; font.family: Style.font.family; font.pixelSize: 9 }
                        Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "SUPER"; color: root.accent; font.family: Style.font.family; font.pixelSize: 7; font.bold: true }
                    }

                    Rectangle {
                        visible: root.shellStyle.notifications === "accent"
                        width: parent.width
                        height: 24
                        radius: 7
                        color: Util.alpha(root.accent, 0.13)
                        border.width: 1
                        border.color: Util.alpha(root.accent, 0.8)
                        Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "●  NOTIFICATION  ready"; color: root.accent; font.family: Style.font.family; font.pixelSize: 8; font.bold: true }
                    }

                    Repeater {
                        model: [
                            { icon: "◫", label: "Applications", hint: "42" },
                            { icon: "◆", label: "Theme studio", hint: "ENTER" },
                            { icon: "▦", label: "Workspaces", hint: "6" },
                            { icon: "⏻", label: "Session", hint: "" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 34
                            radius: 7
                            color: index === 1 ? root.shellSelectedSurface() : index % 2 === 0 ? Util.alpha(root.shellControlSurface(), 0.42) : "transparent"
                            border.width: root.shellStyle.detail === "framed" ? 1 : 0
                            border.color: Util.alpha(root.fg, 0.3)

                            Rectangle {
                                visible: index === 1 && root.shellStyle.detail === "edge"
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: 3; radius: parent.radius; color: root.accent
                            }
                            Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; color: root.accent; font.family: Style.font.family; font.pixelSize: 11; font.bold: true }
                            Text { anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: root.fg; font.family: Style.font.family; font.pixelSize: 9; font.bold: index === 1 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.hint; color: root.muted; opacity: 0.75; font.family: Style.font.family; font.pixelSize: 7 }
                        }
                    }

                    Item { width: parent.width; height: 2 }
                    Text { width: parent.width; text: "Quickshell surface · not an application window"; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.family: Style.font.family; font.pixelSize: 8 }
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
                visible: root.selected
                z: 10

                Text {
                    id: selectedBadge
                    anchors.centerIn: parent
                    text: "✓  SELECTED"
                    color: Contrast.textFor(Color.foreground, root.bg, root.fg)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            Rectangle {
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
                visible: root.hovered && !root.selected && !root.configurationPreview

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
