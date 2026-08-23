import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Live Canvas editor for the four native composition documents.  The
// choices remain staged in the session until the parent sends them through
// the preview transaction; this keeps Window, Shell, and Bar changes on their
// real owners instead of simulating them only inside a card.
Item {
    id: root

    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" })
    property var animationsStyle: ({ window: "native", workspace: "native", border: "native", borderSpeed: 36, reducedMotion: false })
    property int activeTab: 0

    signal stylesChanged(var shellStyle, var desktopStyle, var barStyle, var animationsStyle)

    readonly property var tabs: [
        { title: "Window", eyebrow: "HYPRLAND" },
        { title: "Shell", eyebrow: "QUICKSHELL" },
        { title: "Bar", eyebrow: "QUATTRO BAR" },
        { title: "Animations", eyebrow: "HYPRLAND" }
    ]
    readonly property var borderOptions: [
        { key: "solid", title: "Solid" }, { key: "split_top", title: "Split top" },
        { key: "split_bottom", title: "Split bottom" }, { key: "blend", title: "Accent blend" },
        { key: "neon", title: "Neon" }, { key: "spin", title: "Spinning" }
    ]
    readonly property var shapeOptions: [
        { key: "native", title: "Default" }, { key: "subtle", title: "Subtle" },
        { key: "soft", title: "Soft" }, { key: "rounded", title: "Rounded" }, { key: "pill", title: "Pill" }
    ]
    readonly property var spacingOptions: [
        { key: "native", title: "Default" }, { key: "compact", title: "Compact" }, { key: "airy", title: "Airy" }
    ]
    readonly property var depthOptions: [
        { key: "native", title: "Default" }, { key: "flat", title: "Flat" }, { key: "shadow", title: "Shadow" }
    ]
    readonly property var inactiveOptions: [
        { key: "native", title: "Native" }, { key: "shadow", title: "Soft dim" },
        { key: "frosted_light", title: "Frosted · Light" }, { key: "frosted_balanced", title: "Frosted · Balanced" },
        { key: "frosted_rich", title: "Frosted · Rich" }
    ]
    readonly property var activeOptions: [
        { key: "native", title: "Native" }, { key: "frosted_light", title: "Frosted · Light" },
        { key: "frosted_balanced", title: "Frosted · Balanced" }, { key: "frosted_rich", title: "Frosted · Rich" }
    ]
    readonly property var animationOptions: [
        { key: "native", title: "Native" }, { key: "smooth", title: "Smooth" },
        { key: "snappy", title: "Snappy" }, { key: "none", title: "Off" }
    ]
    readonly property var workspaceAnimationOptions: [
        { key: "native", title: "Native" }, { key: "smooth", title: "Smooth" }, { key: "snappy", title: "Snappy" }, { key: "none", title: "Off" }
    ]
    readonly property var borderAnimationOptions: [
        { key: "native", title: "Native" }, { key: "static", title: "Static" }, { key: "spin", title: "Spin" }
    ]
    readonly property var surfaceOptions: [
        { key: "flat", title: "Flat" }, { key: "layered", title: "Layered" },
        { key: "contrast", title: "Contrast" }, { key: "accent", title: "Accent" }
    ]
    readonly property var detailOptions: [
        { key: "native", title: "Default" }, { key: "framed", title: "Framed" },
        { key: "edge", title: "Edge" }, { key: "focus", title: "Focus" }
    ]
    readonly property var feedbackOptions: [
        { key: "native", title: "Native" }, { key: "accent", title: "Accent" }
    ]
    readonly property var barSurfaceOptions: [
        { key: "native", title: "Default" }, { key: "dark", title: "Dark" },
        { key: "light", title: "Light" }, { key: "accent", title: "Accent" }
    ]
    readonly property var barDensityOptions: [
        { key: "native", title: "Default" }, { key: "compact", title: "Compact" }, { key: "comfortable", title: "Comfortable" }
    ]
    readonly property var attentionOptions: [
        { key: "semantic", title: "Semantic" }, { key: "accent", title: "Accent" }
    ]
    readonly property var barFormOptions: [
        { key: "continuous", title: "Continuous" }, { key: "docked", title: "Docked" }
    ]
    readonly property var barVisibilityOptions: [
        { key: "native", title: "Native" }, { key: "islands", title: "Show islands" }
    ]
    property int stagedBorderSize: root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1
    property int stagedBorderSpeed: Number(root.desktopStyle.borderSpeed || 36)
    property bool borderSizeEditing: false
    property bool speedEditing: false

    function borderSliderPosition() {
        if (root.stagedBorderSize < 0) return 0
        if (root.stagedBorderSize === 0) return 1
        return Math.max(2, Math.min(13, 1 + root.stagedBorderSize / 2))
    }

    function borderSizeFromSlider(position) {
        var snapped = Math.round(position)
        if (snapped <= 0) return -1
        if (snapped === 1) return 0
        return Math.min(24, (snapped - 1) * 2)
    }

    function beginBorderSizeEdit() {
        root.borderSizeEditing = true
        borderSizeInput.text = root.stagedBorderSize > 0 ? String(root.stagedBorderSize) : "2"
        Qt.callLater(function() { borderSizeInput.forceActiveFocus(); borderSizeInput.selectAll() })
    }

    function commitBorderSizeEdit() {
        if (!root.borderSizeEditing) return
        var value = Number(borderSizeInput.text)
        root.borderSizeEditing = false
        if (!isFinite(value)) return
        root.chooseDesktop("borderSize", Math.max(-1, Math.min(24, Math.round(value))))
    }

    function beginSpeedEdit() {
        root.speedEditing = true
        speedInput.text = (root.stagedBorderSpeed / 10).toFixed(1)
        Qt.callLater(function() { speedInput.forceActiveFocus(); speedInput.selectAll() })
    }

    function commitSpeedEdit() {
        if (!root.speedEditing) return
        var seconds = Number(speedInput.text)
        root.speedEditing = false
        if (!isFinite(seconds)) return
        root.chooseDesktop("borderSpeed", Math.max(10, Math.min(100, Math.round(seconds * 10))))
    }

    onDesktopStyleChanged: {
        if (!borderSlider.dragging)
            root.stagedBorderSize = root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1
        if (!speedSlider.dragging)
            root.stagedBorderSpeed = Number(root.desktopStyle.borderSpeed || 36)
    }

    function chooseDesktop(group, key) {
        var next = {
            borderStyle: root.desktopStyle.borderStyle || "solid",
            borderSize: root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1,
            borderSizeMode: root.desktopStyle.borderSizeMode || root.desktopStyle.border_size_mode || (root.desktopStyle.borderSize === 0 ? "none" : root.desktopStyle.borderSize > 0 ? "fixed" : "default"),
            borderSpeed: Number(root.desktopStyle.borderSpeed || 36),
            shape: root.desktopStyle.shape || "native",
            spacing: root.desktopStyle.spacing || "native",
            depth: root.desktopStyle.depth || "native",
            activeStyle: root.desktopStyle.activeStyle || root.desktopStyle.active_style || "native",
            inactiveStyle: root.desktopStyle.inactiveStyle || root.desktopStyle.inactive_style || "native"
        }
        next[group] = key
        if (group === "borderSize") {
            next.borderSizeMode = key < 0 ? "default" : key === 0 ? "none" : "fixed"
        }
        root.stylesChanged(root.shellStyle, next, root.barStyle, root.animationsStyle)
    }

    function chooseShell(group, key) {
        var next = {
            surface: root.shellStyle.surface || "flat",
            detail: root.shellStyle.detail || "native",
            tooltip: root.shellStyle.tooltip || "native",
            notifications: root.shellStyle.notifications || "native"
        }
        next[group] = key
        root.stylesChanged(next, root.desktopStyle, root.barStyle, root.animationsStyle)
    }

    function chooseBar(group, key) {
        var next = {
            surface: root.barStyle.surface || "native",
            density: root.barStyle.density || "native",
            attention: root.barStyle.attention || "semantic",
            form: root.barStyle.form || "continuous",
            visibility: root.barStyle.visibility || "native"
        }
        next[group] = key
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseAnimations(group, key) {
        var next = { window: root.animationsStyle.window || "native", workspace: root.animationsStyle.workspace || "native", border: root.animationsStyle.border || "native", borderSpeed: Number(root.animationsStyle.borderSpeed || root.animationsStyle.border_speed || 36), reducedMotion: root.animationsStyle.reducedMotion === true || root.animationsStyle.reduced_motion === true }
        next[group] = key
        if (next.reducedMotion) { next.window = "none"; next.workspace = "none"; next.border = "static" }
        root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
    }

    function chooseActive(key) {
        var next = { borderStyle: root.desktopStyle.borderStyle || "solid", borderSize: root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1, borderSizeMode: root.desktopStyle.borderSizeMode || "default", borderSpeed: Number(root.desktopStyle.borderSpeed || 36), shape: root.desktopStyle.shape || "native", spacing: root.desktopStyle.spacing || "native", depth: root.desktopStyle.depth || "native", activeStyle: key, inactiveStyle: root.desktopStyle.inactiveStyle || "native" }
        root.stylesChanged(root.shellStyle, next, root.barStyle, root.animationsStyle)
    }

    function description(section, group, key) {
        if (section === "window") {
            if (group === "borderStyle") return "Hyprland border treatment around the focused window."
            if (group === "borderSize") return "Hyprland border thickness. Default inherits the theme; None removes the border."
            if (group === "shape") return "Window corner rounding owned by Hyprland."
            if (group === "spacing") return "Hyprland gaps between panes and the screen edge."
            if (group === "depth") return "Compositor shadow treatment around windows."
            if (key === "blur" || key.indexOf("frosted_") === 0) return "Frosted backdrop blurs what is behind a translucent inactive surface. It does not blur opaque application text or controls."
            if (key === "shadow") return "Soft dim keeps inactive windows readable while making the focused window clearer."
            return "Native inactive-window treatment from the active Hyprland configuration."
        }
        if (section === "shell") {
            if (group === "surface") return "Quickshell popup, menu, launcher, and control surface hierarchy."
            if (group === "detail") return "Quickshell border language for controls, menus, and notifications."
            if (group === "tooltip") return "Border treatment for shell-owned tooltips."
            return "Border and countdown treatment for shell notifications."
        }
        if (group === "surface") return "Native bar surface colour and contrast."
        if (group === "density") return "Bar control density; this changes supported bar spacing and height tokens."
        if (group === "attention") return "Whether bar attention states use semantic colours or the theme accent."
        if (group === "form") return "Continuous keeps the native bar surface; Docked adds Omagen-owned section surfaces beneath native widgets."
        return "Native keeps transparency; Show islands exposes the supported docked section surfaces."
    }

    function optionDescription(section, group, key) {
        var descriptions = {
            window: {
                borderStyle: {
                    solid: "A single accent border around the focused window.",
                    split_top: "An accent border with a stronger top edge for the focused window.",
                    split_bottom: "An accent border with a stronger bottom edge for the focused window.",
                    blend: "A softer border that blends the accent into the window surface.",
                    neon: "A high-contrast accent border for a more luminous focused window.",
                    spin: "An animated accent border treatment for the focused window."
                },
                shape: {
                    native: "Use the active theme's normal window corner radius.",
                    subtle: "Use a small 2 px corner radius on windows.",
                    soft: "Use a gentle 4 px corner radius on windows.",
                    rounded: "Use a clearly rounded 8 px corner radius on windows.",
                    pill: "Use a very rounded 16 px corner radius on windows."
                },
                spacing: {
                    native: "Keep the active theme's normal gaps between windows.",
                    compact: "Reduce gaps between windows for a tighter layout.",
                    airy: "Increase gaps between windows for a more open layout."
                },
                depth: {
                    native: "Keep the active theme's normal compositor shadow treatment.",
                    flat: "Reduce compositor shadows for a flatter window surface.",
                    shadow: "Emphasise compositor shadows to separate windows from the desktop."
                },
                inactiveStyle: {
                    native: "Keep inactive windows using the active Hyprland treatment.",
                    shadow: "Dim inactive windows without adding background blur.",
                    blur: "Legacy Backdrop blur setting; it becomes the Balanced frosted backdrop profile.",
                    frosted_light: "A light glass treatment: subtle dimming and low-cost background blur.",
                    frosted_balanced: "Recommended glass treatment: visible background blur without a shadow-heavy dim.",
                    frosted_rich: "A stronger glass treatment with a larger, multipass blur and higher GPU cost."
                }
            },
            shell: {
                surface: {
                    flat: "Use a flat Quickshell popup and menu surface.",
                    layered: "Use stronger foreground and background tiers in Quickshell surfaces.",
                    contrast: "Increase contrast between Quickshell surface layers.",
                    accent: "Use the theme accent to emphasise Quickshell surfaces."
                },
                detail: {
                    native: "Keep the active Quattro border treatment for shell controls.",
                    framed: "Give shell controls a more visible framed border.",
                    edge: "Emphasise the outer edge of shell controls and menus.",
                    focus: "Use accent borders for focused shell controls."
                },
                tooltip: {
                    native: "Keep the native tooltip border and surface treatment.",
                    accent: "Use the theme accent to make tooltips easier to spot."
                },
                notifications: {
                    native: "Keep the native notification border and countdown treatment.",
                    accent: "Use the theme accent for notification borders and countdowns."
                }
            },
            bar: {
                surface: {
                    native: "Keep the native Quattro bar surface and transparency.",
                    dark: "Use a darker supported surface for the bar.",
                    light: "Use a lighter supported surface for the bar.",
                    accent: "Use the theme accent for the supported bar surface."
                },
                density: {
                    native: "Keep the native bar spacing and height tokens.",
                    compact: "Use tighter supported bar spacing and height tokens.",
                    comfortable: "Use roomier supported bar spacing and height tokens."
                },
                attention: {
                    semantic: "Keep semantic colours for bar warnings, errors, and status.",
                    accent: "Use the theme accent for supported bar attention states."
                },
                form: {
                    continuous: "Keep the native continuous bar surface.",
                    docked: "Add Omagen-owned docked section surfaces beneath native widgets."
                },
                visibility: {
                    native: "Keep the native bar visibility and transparency.",
                    islands: "Show the supported docked section surfaces as separate islands."
                }
            }
        }
        return descriptions[section] && descriptions[section][group] && descriptions[section][group][key]
            ? descriptions[section][group][key]
            : root.description(section, group, key)
    }

    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        Text {
            Layout.fillWidth: true
            text: "ADVANCED COMPOSITION"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
        }
        Text {
            Layout.fillWidth: true
            text: "Stage a Window, Shell, or Bar choice, then test it live."
            color: Color.foreground
            opacity: 0.62
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)
            Repeater {
                model: root.tabs
                delegate: Button {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData.title
                    fontSize: Style.font.caption
                    foreground: root.activeTab === index ? Color.background : Color.foreground
                    background: root.activeTab === index ? Color.accent : Util.alpha(Color.foreground, 0.045)
                    accent: Color.accent
                    bordered: true
                    onClicked: root.activeTab = index
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: root.activeTab
            implicitHeight: root.activeTab === 0 ? windowColumn.implicitHeight : root.activeTab === 1 ? shellColumn.implicitHeight : root.activeTab === 2 ? barColumn.implicitHeight : animationColumn.implicitHeight

            Item {
                implicitHeight: windowColumn.implicitHeight
                ColumnLayout {
                    id: windowColumn
                    width: parent.width
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "HYPRLAND WINDOW EFFECTS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: "Window appearance is written to hyprland.lua for the compositor."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { Layout.fillWidth: true; text: "BORDER STYLE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.borderOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "borderStyle", modelData.key); selected: root.desktopStyle.borderStyle === modelData.key; onClicked: root.chooseDesktop("borderStyle", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "BORDER THICKNESS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        Text { text: "BORDER"; color: Color.foreground; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        PanelSlider {
                            id: borderSlider
                            Layout.fillWidth: true
                            minimum: 0
                            maximum: 13
                            step: 1
                            integer: true
                            value: root.borderSliderPosition()
                            tickCount: 14
                            trackColor: Util.alpha(Color.foreground, 0.2)
                            fillColor: Color.accent
                            knobColor: Color.accent
                            tickColor: Color.background
                            onMoved: root.stagedBorderSize = root.borderSizeFromSlider(value)
                            onReleased: root.chooseDesktop("borderSize", root.borderSizeFromSlider(value))
                        }
                        Item {
                            Layout.preferredWidth: Style.space(70)
                            Layout.preferredHeight: Style.space(32)

                            Text {
                                anchors.fill: parent
                                visible: !root.borderSizeEditing
                                text: root.stagedBorderSize < 0 ? "Default" : root.stagedBorderSize === 0 ? "None" : root.stagedBorderSize + " px"
                                color: Color.accent
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea {
                                anchors.fill: parent
                                visible: !root.borderSizeEditing
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.beginBorderSizeEdit()
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: root.borderSizeEditing
                                radius: Style.space(5)
                                color: Util.alpha(Color.background, 0.48)
                                border.width: 1
                                border.color: borderSizeInput.activeFocus ? Color.accent : Color.popups.border
                            }
                            TextInput {
                                id: borderSizeInput
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(6)
                                anchors.rightMargin: Style.space(6)
                                visible: root.borderSizeEditing
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                horizontalAlignment: TextInput.AlignRight
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                Keys.onReturnPressed: root.commitBorderSizeEdit()
                                Keys.onEnterPressed: root.commitBorderSizeEdit()
                                Keys.onEscapePressed: root.borderSizeEditing = false
                                onEditingFinished: root.commitBorderSizeEdit()
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "SPIN SPEED"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "Controls the full gradient cycle. Lower seconds move faster."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    RowLayout {
                        visible: root.desktopStyle.borderStyle === "spin"
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        Text { text: "SPEED"; color: Color.foreground; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        PanelSlider {
                            id: speedSlider
                            Layout.fillWidth: true
                            minimum: 10
                            maximum: 100
                            step: 1
                            integer: true
                            value: root.stagedBorderSpeed
                            tickCount: 10
                            trackColor: Util.alpha(Color.foreground, 0.2)
                            fillColor: Color.accent
                            knobColor: Color.accent
                            tickColor: Color.background
                            onMoved: root.stagedBorderSpeed = Math.round(value)
                            onReleased: root.chooseDesktop("borderSpeed", Math.round(value))
                        }
                        Item {
                            Layout.preferredWidth: Style.space(70)
                            Layout.preferredHeight: Style.space(32)

                            Text {
                                anchors.fill: parent
                                visible: !root.speedEditing
                                text: (root.stagedBorderSpeed / 10).toFixed(1) + " s"
                                color: Color.accent
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea {
                                anchors.fill: parent
                                visible: !root.speedEditing
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.beginSpeedEdit()
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: root.speedEditing
                                radius: Style.space(5)
                                color: Util.alpha(Color.background, 0.48)
                                border.width: 1
                                border.color: speedInput.activeFocus ? Color.accent : Color.popups.border
                            }
                            TextInput {
                                id: speedInput
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(6)
                                anchors.rightMargin: Style.space(6)
                                visible: root.speedEditing
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                horizontalAlignment: TextInput.AlignRight
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                Keys.onReturnPressed: root.commitSpeedEdit()
                                Keys.onEnterPressed: root.commitSpeedEdit()
                                Keys.onEscapePressed: root.speedEditing = false
                                onEditingFinished: root.commitSpeedEdit()
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "SHAPE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.shapeOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "shape", modelData.key); selected: root.desktopStyle.shape === modelData.key; onClicked: root.chooseDesktop("shape", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "SPACING"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.spacingOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "spacing", modelData.key); selected: root.desktopStyle.spacing === modelData.key; onClicked: root.chooseDesktop("spacing", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "DEPTH"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.depthOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "depth", modelData.key); selected: root.desktopStyle.depth === modelData.key; onClicked: root.chooseDesktop("depth", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "ACTIVE WINDOWS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Active and inactive surfaces are independent compositor paths. Choose active glass only when the focused surface itself is translucent."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.activeOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Focused-window opacity and backdrop treatment."; selected: (root.desktopStyle.activeStyle || "native") === modelData.key; onClicked: root.chooseActive(modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "INACTIVE WINDOWS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: root.description("window", "inactiveStyle", root.desktopStyle.inactiveStyle || "native"); color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.inactiveOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "inactiveStyle", modelData.key); selected: (root.desktopStyle.inactiveStyle || "native") === modelData.key || (modelData.key === "frosted_balanced" && root.desktopStyle.inactiveStyle === "blur"); onClicked: root.chooseDesktop("inactiveStyle", modelData.key) } }
                    }
                }
            }

            Item {
                implicitHeight: shellColumn.implicitHeight
                ColumnLayout {
                    id: shellColumn
                    width: parent.width
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "QUICKSHELL SURFACES"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "These choices feed Quattro's native popup, menu, launcher, control, tooltip, and notification readers."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { Layout.fillWidth: true; text: "SURFACE / DETAIL"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.surfaceOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Surface · " + modelData.title; description: root.optionDescription("shell", "surface", modelData.key); selected: root.shellStyle.surface === modelData.key; onClicked: root.chooseShell("surface", modelData.key) } }
                        Repeater { model: root.detailOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Detail · " + modelData.title; description: root.optionDescription("shell", "detail", modelData.key); selected: root.shellStyle.detail === modelData.key; onClicked: root.chooseShell("detail", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "FEEDBACK"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Style.space(5)
                        Repeater { model: root.feedbackOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Tooltip · " + modelData.title; description: root.optionDescription("shell", "tooltip", modelData.key); selected: root.shellStyle.tooltip === modelData.key; onClicked: root.chooseShell("tooltip", modelData.key) } }
                        Repeater { model: root.feedbackOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Alerts · " + modelData.title; description: root.optionDescription("shell", "notifications", modelData.key); selected: root.shellStyle.notifications === modelData.key; onClicked: root.chooseShell("notifications", modelData.key) } }
                    }
                }
            }

            Item {
                implicitHeight: barColumn.implicitHeight
                ColumnLayout {
                    id: barColumn
                    width: parent.width
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "QUATTRO BAR COMPOSITION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Native left, centre, and right widgets remain owned by Quattro. These settings change the supported bar tokens and Omagen's additive docked surfaces."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.barSurfaceOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Surface · " + modelData.title; description: root.optionDescription("bar", "surface", modelData.key); selected: root.barStyle.surface === modelData.key; onClicked: root.chooseBar("surface", modelData.key) } }
                        Repeater { model: root.barDensityOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Density · " + modelData.title; description: root.optionDescription("bar", "density", modelData.key); selected: root.barStyle.density === modelData.key; onClicked: root.chooseBar("density", modelData.key) } }
                        Repeater { model: root.attentionOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Attention · " + modelData.title; description: root.optionDescription("bar", "attention", modelData.key); selected: root.barStyle.attention === modelData.key; onClicked: root.chooseBar("attention", modelData.key) } }
                        Repeater { model: root.barFormOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Form · " + modelData.title; description: root.optionDescription("bar", "form", modelData.key); selected: root.barStyle.form === modelData.key; onClicked: root.chooseBar("form", modelData.key) } }
                        Repeater { model: root.barVisibilityOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Visibility · " + modelData.title; description: root.optionDescription("bar", "visibility", modelData.key); selected: root.barStyle.visibility === modelData.key; onClicked: root.chooseBar("visibility", modelData.key) } }
                    }
                }
            }

            Item {
                implicitHeight: animationColumn.implicitHeight
                ColumnLayout {
                    id: animationColumn
                    width: parent.width
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "COMPOSITOR ANIMATIONS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: "Animation settings are a separate Hyprland engine. Window motion, workspace transitions, and animated borders can be tuned independently of surfaces."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { Layout.fillWidth: true; text: "WINDOW MOTION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.animationOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Window open, close, and resize animation."; selected: root.animationsStyle.window === modelData.key; onClicked: root.chooseAnimations("window", modelData.key) } } }
                    Text { Layout.fillWidth: true; text: "WORKSPACE MOTION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.workspaceAnimationOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Workspace switching transition."; selected: root.animationsStyle.workspace === modelData.key; onClicked: root.chooseAnimations("workspace", modelData.key) } } }
                    Text { Layout.fillWidth: true; text: "BORDER MOTION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.borderAnimationOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Animated focus-border treatment."; selected: root.animationsStyle.border === modelData.key; onClicked: root.chooseAnimations("border", modelData.key) } } }
                    DesktopOptionCard { Layout.fillWidth: true; compact: true; title: root.animationsStyle.reducedMotion === true ? "Reduced motion · On" : "Reduced motion · Off"; description: "Disable compositor motion while keeping surfaces and layout unchanged."; selected: root.animationsStyle.reducedMotion === true; onClicked: root.chooseAnimations("reducedMotion", !(root.animationsStyle.reducedMotion === true)) }
                }
            }
        }
    }
}
