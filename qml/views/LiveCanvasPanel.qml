import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components
import "../components/Contrast.js" as Contrast

PanelWindow {
    id: root

    property bool active: false
    property bool previewBusy: false
    property bool generationBusy: false
    property bool workspaceReady: false
    property bool demoBusy: false
    property bool demoActive: false
    property string demoMode: "none"
    property bool cancelBusy: false
    property bool applyBusy: false
    property bool extraConfigsEnabled: false
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null })
    property var animationsStyle: ({ version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false })
    property bool glitchEnabled: false
    property int glitchEpoch: 0
    property var lookFeel: ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    // Keep the resolved Look & Feel recipe beside its metadata. The metadata
    // says whether Shell is customized; the recipe supplies the inherited
    // Shell document when it is not. This avoids letting the editor's default
    // placeholder replace a selected Look & Feel preset during a stale/resume
    // or cross-engine update.
    property var lookFeelRecipe: null
    property var lookFeelCatalog: []
    property bool lookFeelBusy: false
    property var terminalTranslucency: ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" })
    property real terminalPresetOpacity: 0.82
    property bool applyRecoveryRequired: false
    property bool protocolCanBack: false
    property bool protocolCanForward: false
    property bool protocolBusy: false
    property string protocolMessage: ""
    property string errorMessage: ""
    readonly property bool operationBusy: root.generationBusy || root.previewBusy || root.demoBusy || root.cancelBusy || root.applyBusy || root.protocolBusy || root.lookFeelBusy
    readonly property string operationTitle: root.generationBusy
        ? "Preparing Live Canvas…"
        : root.previewBusy
            ? (root.applyBusy ? "Preparing final theme…" : "Applying live changes…")
            : root.applyBusy
                ? "Saving theme…"
                : root.demoBusy
                    ? (root.demoActive ? "Closing Live Canvas…" : "Opening Live Canvas…")
                    : root.cancelBusy
                        ? "Restoring original desktop…"
                        : "Updating history…"
    readonly property string operationDetail: root.generationBusy
        ? "Building the palette directions before the canvas can be edited."
        : root.previewBusy
            ? (root.applyBusy
                ? "Materializing the exact state shown here before the permanent save."
                : "Updating the long-lived Omarchy shell in place. Controls are locked until it finishes.")
            : root.applyBusy
                ? "Saving the selected theme and completing the native Omarchy transaction."
                : root.demoBusy
                    ? "Waiting for the Live Canvas workspace transition to finish."
                    : root.cancelBusy
                        ? "Restoring the original theme and closing this session."
                        : "Reapplying the selected history checkpoint."
    property string selectedVariant: "source"
    property string monitorName: ""
    property string suggestedThemeName: ""
    property var variants: []
    property var palettes: ({})
    // All editor surfaces follow the selected/staged palette, not the theme
    // that happened to launch Omagen.  Fall back to native tokens while the
    // palette catalog is still loading.
    readonly property color foregroundColor: root.palettes[root.selectedVariant] && root.palettes[root.selectedVariant].foreground
        ? root.palettes[root.selectedVariant].foreground : Color.foreground
    readonly property color backgroundColor: root.palettes[root.selectedVariant] && root.palettes[root.selectedVariant].background
        ? root.palettes[root.selectedVariant].background : Color.background
    readonly property color accentColor: root.palettes[root.selectedVariant] && root.palettes[root.selectedVariant].accent
        ? root.palettes[root.selectedVariant].accent : Color.accent
    property bool colorEditorOpen: false
    property bool colorPreviewLive: false
    property string editingColorRole: "accent"
    property var stagedColors: ({})
    property var colorOverridesByVariant: ({})
    property bool moreColorsOpen: false
    property string expandedColorGroup: "surfaces"
    property bool lookFeelEditorOpen: false
    property bool advancedEditorOpen: false
    property int advancedSection: 0
    readonly property string inactiveStyle: desktopStyle.inactiveStyle || desktopStyle.inactive_style || "native"
    readonly property bool frostedBackdropEnabled: inactiveStyle === "blur" || inactiveStyle.indexOf("frosted_") === 0
    readonly property real frostedBackdropOpacity: inactiveStyle === "native" ? 1.0
        : inactiveStyle === "frosted_rich" ? 0.46
        : inactiveStyle === "frosted_balanced" || inactiveStyle === "blur" ? 0.56
        : inactiveStyle === "frosted_light" ? 0.68 : 0.97
    readonly property var editableColorRoles: [
        { key: "accent", label: "Accent" },
        { key: "background", label: "Background" },
        { key: "foreground", label: "Foreground" },
        { key: "selection", label: "Selection" }
    ]

    readonly property var advancedColorGroups: [
        {
            key: "surfaces",
            label: "Surfaces",
            roles: [
                { key: "muted", label: "Muted" },
                { key: "dark_background", label: "Dark background" },
                { key: "darker_background", label: "Deep background" },
                { key: "lighter_background", label: "Light background" }
            ]
        },
        {
            key: "text",
            label: "Text",
            roles: [
                { key: "dark_foreground", label: "Dark text" },
                { key: "light_foreground", label: "Light text" },
                { key: "bright_foreground", label: "Bright text" }
            ]
        },
        {
            key: "terminal",
            label: "Terminal colours",
            roles: [
                { key: "red", label: "Red" },
                { key: "orange", label: "Orange" },
                { key: "yellow", label: "Yellow" },
                { key: "green", label: "Green" },
                { key: "cyan", label: "Cyan" },
                { key: "blue", label: "Blue" },
                { key: "magenta", label: "Magenta" },
                { key: "brown", label: "Brown" }
            ]
        },
        {
            key: "bright-terminal",
            label: "Bright terminal colours",
            roles: [
                { key: "bright_red", label: "Bright red" },
                { key: "bright_yellow", label: "Bright yellow" },
                { key: "bright_green", label: "Bright green" },
                { key: "bright_cyan", label: "Bright cyan" },
                { key: "bright_blue", label: "Bright blue" },
                { key: "bright_magenta", label: "Bright magenta" }
            ]
        }
    ]

    signal hideRequested()
    signal closeCanvasRequested()
    signal startDemoRequested()
    signal windowDemoRequested()
    signal windowDemoStopRequested()
    signal shellDemoRequested()
    signal shellDemoStopRequested()
    signal barDemoRequested()
    signal barDemoStopRequested()
    signal cancelRequested()
    signal variantRequested(string variant)
    signal colorTestLiveRequested(string variant, var overrides, var shellStyle, var desktopStyle, var barStyle, var animationsStyle)
    signal advancedStylesChanged(var shellStyle, var desktopStyle, var barStyle, var animationsStyle)
    signal lookFeelPresetRequested(string preset)
    signal lookFeelResetRequested(string scope)
    signal terminalIntentChanged(var terminal)
    signal protocolBackRequested()
    signal protocolForwardRequested()
    signal applyRequested(string variant, string name, bool generateUnlock, bool capturePreview)

    function copyColors() {
        var next = {}
        for (var key in root.stagedColors)
            next[key] = root.stagedColors[key]
        return next
    }

    function copyOverrideColors(overrides) {
        var next = {}
        for (var key in (overrides || {}))
            next[key] = String(overrides[key]).toUpperCase()
        return next
    }

    function overridesForVariant(variant) {
        return root.copyOverrideColors(root.colorOverridesByVariant[variant] || ({}))
    }

    function storeOverridesForVariant(variant, overrides) {
        var next = {}
        for (var key in root.colorOverridesByVariant)
            next[key] = root.colorOverridesByVariant[key]

        var copied = root.copyOverrideColors(overrides)
        if (Object.keys(copied).length > 0)
            next[variant] = copied
        else
            delete next[variant]
        root.colorOverridesByVariant = next
    }

    function copyShellStyle(value) {
        value = value || ({})
        var overrides = {}
        for (var key in (value.overrides || {}))
            overrides[key] = String(value.overrides[key])
        return {
            preset: value.preset || "default",
            surface: value.surface || "flat",
            detail: value.detail || "native",
            tooltip: value.tooltip || "native",
            notifications: value.notifications || "native",
            overrides: overrides
        }
    }

    function shellStyleForVariant(_variant) {
        var customized = root.lookFeel.customized || ({})
        var inherited = root.lookFeelRecipe && root.lookFeelRecipe.shell && customized.shell !== true
            ? root.lookFeelRecipe.shell : root.shellStyle
        return root.copyShellStyle(inherited)
    }

    function barStyleForVariant(variant) {
        return root.barStyle
    }

    function paletteValue(role) {
        var palette = root.palettes[root.selectedVariant] || null
        return palette && palette[role] ? String(palette[role]).toUpperCase() : "#FFFFFF"
    }

    function presetColor(role) {
        return root.paletteValue(role)
    }

    function currentColor(role) {
        return root.stagedColors[role] || root.presetColor(role)
    }

    function colorRoleLabel(role) {
        for (var i = 0; i < root.editableColorRoles.length; i++) {
            if (root.editableColorRoles[i].key === role)
                return root.editableColorRoles[i].label
        }
        for (var groupIndex = 0; groupIndex < root.advancedColorGroups.length; groupIndex++) {
            var roles = root.advancedColorGroups[groupIndex].roles
            for (var roleIndex = 0; roleIndex < roles.length; roleIndex++) {
                if (roles[roleIndex].key === role)
                    return roles[roleIndex].label
            }
        }
        return role
    }

    function colorRoleDescription(role) {
        var descriptions = {
            accent: "Primary shell highlight for focus, selection, active borders, and theme accents.",
            background: "Base background used by the shell fallback and terminal/editor theme templates.",
            foreground: "Primary text and icon colour for Quickshell and generated application themes.",
            selection: "Selection fill and text pairing in menus, terminals, editors, and code views.",
            muted: "Low-emphasis text, inactive details, dividers, and ANSI black in supported apps.",
            dark_background: "Dark surface tier for recessed shell panels and application templates.",
            darker_background: "Deepest surface tier for nested or recessed backgrounds in supported templates.",
            lighter_background: "Raised surface tier for cards, controls, and editor backgrounds.",
            dark_foreground: "Low-contrast text for inactive labels, line numbers, and disabled UI.",
            light_foreground: "Secondary readable text in editors, charts, and supporting UI.",
            bright_foreground: "Strong text and cursor colour, including ANSI bright white in supported apps.",
            red: "ANSI red plus error and urgent accents in the shell and supported applications.",
            orange: "Warm syntax, number, and modified-state accent in supported editors and applications.",
            yellow: "Warning, attention, and ANSI yellow accent in supported applications.",
            green: "Success, positive-state, and ANSI green accent in supported applications.",
            cyan: "Informational highlight and ANSI cyan accent in supported applications.",
            blue: "Links, functions, information, and ANSI blue accent in supported applications.",
            magenta: "Keywords, special syntax, and ANSI magenta accent in supported applications.",
            brown: "Warm low-intensity terminal or editor accent where supported.",
            bright_red: "High-emphasis ANSI red and error accent in supported applications.",
            bright_yellow: "High-emphasis ANSI yellow and warning accent in supported applications.",
            bright_green: "High-emphasis ANSI green and success accent in supported applications.",
            bright_cyan: "High-emphasis ANSI cyan and information accent in supported applications.",
            bright_blue: "High-emphasis ANSI blue, links, and function accent in supported applications.",
            bright_magenta: "High-emphasis ANSI magenta and syntax accent in supported applications."
        }
        return descriptions[role] || "Semantic palette colour used by supported Omarchy theme consumers."
    }

    // qs.Ui.Button's native tooltip sizes to its text's implicit width. Keep
    // long semantic descriptions inside the panel/monitor without replacing
    // the shell-owned tooltip surface.
    function tooltipDescription(value) {
        var words = String(value || "").split(/\s+/)
        var lines = []
        var line = ""
        var maximumCharacters = 48

        for (var index = 0; index < words.length; index++) {
            var word = words[index]
            if (!word)
                continue
            if (!line) {
                line = word
            } else if (line.length + word.length + 1 <= maximumCharacters) {
                line += " " + word
            } else {
                lines.push(line)
                line = word
            }
        }
        if (line)
            lines.push(line)
        return lines.join("\n")
    }

    function stageColor(role, value) {
        var next = root.copyColors()
        next[role] = value.toUpperCase()
        root.stagedColors = next
        root.storeOverridesForVariant(root.selectedVariant, next)
        root.colorPreviewLive = false
    }

    function resetColor(role) {
        var next = root.copyColors()
        delete next[role]
        root.stagedColors = next
        root.storeOverridesForVariant(root.selectedVariant, next)
        root.colorPreviewLive = false
    }

    function resetVariantColors() {
        root.stagedColors = ({})
        root.storeOverridesForVariant(root.selectedVariant, ({}))
        root.colorPreviewLive = false
    }

    function clearColorSession() {
        root.stagedColors = ({})
        root.colorOverridesByVariant = ({})
        root.colorPreviewLive = false
        root.colorEditorOpen = false
        root.lookFeelEditorOpen = false
        root.advancedEditorOpen = false
        root.editingColorRole = "accent"
        root.moreColorsOpen = false
        root.expandedColorGroup = "surfaces"
    }

    // The palette-direction list is the root of the Live Canvas flow. Keep
    // this navigation separate from the editor toggles so a user can always
    // return to another colour variant without resetting staged edits.
    function showPaletteDirections() {
        root.colorEditorOpen = false
        root.lookFeelEditorOpen = false
        root.advancedEditorOpen = false
        root.moreColorsOpen = false
    }

    function resetApplyDialog() {
        themeNameDialog.reset()
    }

    function setStagedColors(overrides, variant) {
        var targetVariant = variant || root.selectedVariant
        var copied = root.copyOverrideColors(overrides)
        root.storeOverridesForVariant(targetVariant, copied)
        if (targetVariant !== root.selectedVariant)
            return
        root.stagedColors = copied
        if (Object.keys(root.stagedColors).length > 0) {
            root.colorEditorOpen = true
            root.lookFeelEditorOpen = false
            root.advancedEditorOpen = false
        }
        root.colorPreviewLive = false
    }

    function markColorsLive() {
        root.colorPreviewLive = Object.keys(root.stagedColors).length > 0
    }

    function suggestionsFor(role) {
        var palette = root.palettes[root.selectedVariant] || ({})
        var candidates = []
        if (role === "accent") {
            candidates = [
                { hex: palette.accent, label: "Preset colour" },
                { hex: palette.blue, label: "Blue from preset" },
                { hex: palette.magenta, label: "Magenta from preset" },
                { hex: palette.cyan, label: "Cyan from preset" }
            ]
        } else if (role === "background") {
            candidates = [
                { hex: palette.background, label: "Preset surface" },
                { hex: palette.dark_background, label: "Dark surface" },
                { hex: palette.darker_background, label: "Deep surface" },
                { hex: palette.lighter_background, label: "Lifted surface" }
            ]
        } else if (role === "foreground") {
            candidates = [
                { hex: palette.foreground, label: "Preset text" },
                { hex: palette.light_foreground, label: "Light text" },
                { hex: palette.bright_foreground, label: "Bright text" },
                { hex: palette.dark_foreground, label: "Muted text" }
            ]
        } else if (role === "selection") {
            candidates = [
                { hex: palette.selection, label: "Preset selection" },
                { hex: palette.accent, label: "Accent selection" },
                { hex: palette.lighter_background, label: "Lifted selection" },
                { hex: palette.muted, label: "Muted selection" }
            ]
        } else if (role === "muted") {
            candidates = [
                { hex: palette.muted, label: "Preset muted" },
                { hex: palette.dark_foreground, label: "Dark text" },
                { hex: palette.selection, label: "Selection" },
                { hex: palette.foreground, label: "Foreground" }
            ]
        } else if (role.indexOf("background") !== -1) {
            candidates = [
                { hex: palette[role], label: "Preset surface" },
                { hex: palette.background, label: "Background" },
                { hex: palette.darker_background, label: "Deep background" },
                { hex: palette.lighter_background, label: "Light background" }
            ]
        } else if (role.indexOf("foreground") !== -1) {
            candidates = [
                { hex: palette[role], label: "Preset text" },
                { hex: palette.foreground, label: "Foreground" },
                { hex: palette.light_foreground, label: "Light text" },
                { hex: palette.bright_foreground, label: "Bright text" }
            ]
        } else {
            var baseRole = role.indexOf("bright_") === 0 ? role.substring(7) : role
            candidates = [
                { hex: palette[role], label: "Preset " + root.colorRoleLabel(role).toLowerCase() },
                { hex: palette[baseRole], label: "Base " + root.colorRoleLabel(baseRole).toLowerCase() },
                { hex: palette.accent, label: "Accent from preset" },
                { hex: palette.selection, label: "Selection from preset" }
            ]
        }

        return candidates.filter(function(candidate) {
            return candidate.hex && String(candidate.hex).length === 7
        }).map(function(candidate) {
            return { hex: String(candidate.hex).toUpperCase(), label: candidate.label }
        })
    }

    function resolveScreen() {
        const screens = Quickshell.screens || []
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === root.monitorName)
                return screens[i]
        }
        return null
    }

    visible: root.active
    screen: root.resolveScreen()
    color: "transparent"
    // The frosted profile needs an alpha-capable Wayland surface. Without this
    // declaration, the compositor may treat this PanelWindow as opaque even
    // though its content Rectangle has an alpha value.
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagen-live-canvas"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }
    margins {
        top: Style.bar.sizeHorizontal + Style.space(12)
    }
    implicitWidth: Style.space(480)
    implicitHeight: Math.min(
        Style.space(780),
        Math.max(
            Style.space(420),
            (root.screen ? root.screen.height : Style.space(900))
                - Style.bar.sizeHorizontal
                - Style.space(24)
        )
    )

    Rectangle {
        anchors.fill: parent
        // Hyprland's layer blur samples the pixels behind this surface. Keep
        // the panel translucent when a Frosted backdrop profile is selected; an almost
        // opaque panel would hide the compositor effect even with the rule.
        color: Util.alpha(
            Color.popups.background,
            root.frostedBackdropOpacity
        )
        border.width: 1
        border.color: Color.popups.border

        Components.SignalGlitch {
            anchors.fill: parent
            z: 10
            enabled: root.glitchEnabled
            triggerEpoch: root.glitchEpoch
            accentColor: root.accentColor
            secondaryColor: root.foregroundColor
        }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            enabled: !root.operationBusy
            onCloseRequested: root.hideRequested()
        }

        Flickable {
            id: scrollArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: actionFooter.top
            clip: true
            contentWidth: width
            contentHeight: contentColumn.y + contentColumn.implicitHeight + Style.space(18)
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            WheelHandler {
                onWheel: function(event) {
                    if (event.angleDelta.y === 0 || !scrollArea.interactive)
                        return
                    scrollArea.cancelFlick()
                    const maximum = Math.max(0, scrollArea.contentHeight - scrollArea.height)
                    scrollArea.contentY = Math.max(0, Math.min(maximum, scrollArea.contentY - event.angleDelta.y / 2))
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: contentColumn
                x: Style.space(18)
                y: Style.space(18)
                width: scrollArea.width - Style.space(36)
                height: implicitHeight
                spacing: Style.space(9)
                z: 1

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(42)

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                        text: "LIVE CANVAS"
                        color: root.accentColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: root.generationBusy ? "Preparing palette directions" : "Real desktop / " + (root.monitorName || "focused monitor")
                        color: root.foregroundColor
                        opacity: 0.6
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                }

                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(34)
                    height: Style.space(34)
                    text: "—"
                    fontSize: Style.font.title
                    foreground: root.foregroundColor
                    tooltipText: "Hide Studio panel"
                    onClicked: root.hideRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(76)
                radius: Style.cornerRadius
                color: Util.alpha(root.accentColor, 0.1)
                border.width: 1
                border.color: Util.alpha(root.accentColor, 0.45)

                Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(3)
                    Text {
                        text: "ACTIVE PALETTE"
                        color: root.accentColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    Text {
                        text: root.selectedVariant.toUpperCase()
                        color: root.foregroundColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.generationBusy
                    ? "Generating six interpretations…"
                    : root.colorEditorOpen
                        ? "Tune a staged colour, then reset it or return to the palette directions."
                        : root.lookFeelEditorOpen
                            ? "Choose a complete Look & Feel recipe. The four engines remain available as advanced controls."
                            : root.advancedEditorOpen
                                ? "Tune one engine at a time. Window, Shell, Bar, and Animations keep their native owners."
                                : root.demoActive
                                    ? "Choose another palette direction to reapply it without losing this canvas."
                                    : root.workspaceReady
                                        ? "Choose a direction to apply it to the real desktop."
                                        : "Preparing the Live Canvas…"
                color: root.foregroundColor
                opacity: 0.62
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            RowLayout {
                visible: root.colorEditorOpen || root.lookFeelEditorOpen || root.advancedEditorOpen
                Layout.fillWidth: true
                spacing: Style.space(5)

                Button {
                    Layout.fillWidth: true
                    text: "←  Palette directions"
                    leftAlign: true
                    fontSize: Style.font.caption
                    foreground: root.foregroundColor
                    accent: root.accentColor
                    background: Util.alpha(root.foregroundColor, 0.045)
                    bordered: true
                    enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && !root.lookFeelBusy
                    tooltipText: "Return to the colour variants without losing staged edits"
                    onClicked: root.showPaletteDirections()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                Button {
                    Layout.fillWidth: true
                    text: "Edit colours"
                    fontSize: Style.font.caption
                    foreground: root.colorEditorOpen ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                    accent: root.accentColor
                    background: root.colorEditorOpen ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                    bordered: true
                    enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && !root.lookFeelBusy
                    onClicked: {
                        root.colorEditorOpen = !root.colorEditorOpen
                        if (root.colorEditorOpen) {
                            root.lookFeelEditorOpen = false
                            root.advancedEditorOpen = false
                        }
                    }
                }

                Button {
                    visible: root.extraConfigsEnabled
                    Layout.fillWidth: true
                    text: "Choose a preset"
                    fontSize: Style.font.caption
                    foreground: root.lookFeelEditorOpen ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                    accent: root.accentColor
                    background: root.lookFeelEditorOpen ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                    bordered: true
                    enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && !root.lookFeelBusy
                    onClicked: {
                        root.lookFeelEditorOpen = !root.lookFeelEditorOpen
                        if (root.lookFeelEditorOpen) {
                            root.colorEditorOpen = false
                            root.advancedEditorOpen = false
                        }
                    }
                }

                Button {
                    visible: root.extraConfigsEnabled
                    Layout.fillWidth: true
                    text: "Advanced controls"
                    fontSize: Style.font.caption
                    foreground: root.advancedEditorOpen ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                    accent: root.accentColor
                    background: root.advancedEditorOpen ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                    bordered: true
                    enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && !root.lookFeelBusy
                    onClicked: {
                        root.advancedEditorOpen = !root.advancedEditorOpen
                        if (root.advancedEditorOpen) {
                            root.colorEditorOpen = false
                            root.lookFeelEditorOpen = false
                        }
                    }
                }
            }

            RowLayout {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: root.editableColorRoles
                    delegate: Button {
                        id: editableRoleButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(32)
                        text: modelData.label
                        fontSize: Style.font.caption
                        foreground: root.editingColorRole === modelData.key ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                        accent: root.accentColor
                        background: root.editingColorRole === modelData.key ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                        bordered: true
                        tooltipText: ""
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.editingColorRole = modelData.key

                        Components.BoundedTooltip {
                            anchorItem: editableRoleButton
                            text: root.tooltipDescription(root.colorRoleDescription(modelData.key))
                        }
                    }
                }
            }

            Button {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                text: root.moreColorsOpen ? "More colours  ↑" : "More colours  ↓"
                foreground: root.foregroundColor
                accent: root.accentColor
                background: Util.alpha(root.foregroundColor, 0.045)
                bordered: true
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: root.moreColorsOpen = !root.moreColorsOpen
            }

            ColumnLayout {
                visible: root.colorEditorOpen && root.moreColorsOpen
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: root.advancedColorGroups
                    delegate: ColumnLayout {
                        id: groupDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Style.space(4)

                        Button {
                            Layout.fillWidth: true
                            text: (root.expandedColorGroup === groupDelegate.modelData.key ? "▾  " : "▸  ") + groupDelegate.modelData.label
                            leftAlign: true
                            foreground: root.foregroundColor
                            accent: root.accentColor
                            background: Util.alpha(root.foregroundColor, 0.045)
                            bordered: true
                            enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                            onClicked: root.expandedColorGroup = root.expandedColorGroup === groupDelegate.modelData.key ? "" : groupDelegate.modelData.key
                        }

                        GridLayout {
                            visible: root.expandedColorGroup === groupDelegate.modelData.key
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: Style.space(4)
                            columnSpacing: Style.space(4)

                            Repeater {
                                model: groupDelegate.modelData.roles
                                delegate: Button {
                                    id: advancedRoleButton
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Style.space(32)
                                    text: modelData.label
                                    fontSize: Style.font.caption
                                    foreground: root.editingColorRole === modelData.key ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                                    accent: root.accentColor
                                    background: root.editingColorRole === modelData.key ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                                    bordered: true
                                    tooltipText: ""
                                    enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                                    onClicked: root.editingColorRole = modelData.key

                                    Components.BoundedTooltip {
                                        anchorItem: advancedRoleButton
                                        text: root.tooltipDescription(root.colorRoleDescription(modelData.key))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Components.ColorRoleEditor {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                roleKey: root.editingColorRole
                roleLabel: root.colorRoleLabel(root.editingColorRole)
                roleDescription: root.tooltipDescription(root.colorRoleDescription(root.editingColorRole))
                value: root.currentColor(root.editingColorRole)
                presetValue: root.presetColor(root.editingColorRole)
                suggestions: root.suggestionsFor(root.editingColorRole)
                live: root.colorPreviewLive
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onValueEdited: function(hex) { root.stageColor(root.editingColorRole, hex) }
                onResetRequested: root.resetColor(root.editingColorRole)
                onSuggestionRequested: function(hex) { root.stageColor(root.editingColorRole, hex) }
            }

            Components.LookFeelControls {
                visible: root.extraConfigsEnabled && root.lookFeelEditorOpen
                Layout.fillWidth: true
                catalog: root.lookFeelCatalog
                lookFeel: root.lookFeel
                recipe: root.lookFeelRecipe
                terminalTranslucency: root.terminalTranslucency
                presetOpacity: root.terminalPresetOpacity
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                busy: root.lookFeelBusy
                onPresetRequested: root.lookFeelPresetRequested(preset)
                onResetRequested: root.lookFeelResetRequested(scope)
                onTerminalChanged: root.terminalIntentChanged(terminal)
            }

            Components.AdvancedStyleEditor {
                id: advancedStyleEditor
                visible: root.extraConfigsEnabled && root.advancedEditorOpen
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                shellStyle: root.shellStyleForVariant(root.selectedVariant)
                desktopStyle: root.desktopStyle
                barStyle: root.barStyleForVariant(root.selectedVariant)
                animationsStyle: root.animationsStyle
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && !root.lookFeelBusy
                onStylesChanged: function(shellStyle, desktopStyle, barStyle, animationsStyle) {
                    root.advancedStylesChanged(shellStyle, desktopStyle, barStyle, animationsStyle)
                }
                onSectionChanged: function(index) {
                    root.advancedSection = index
                    if (index !== 0 && root.demoActive && root.demoMode === "window")
                        root.windowDemoStopRequested()
                    if (index !== 1 && root.demoActive && root.demoMode === "shell")
                        root.shellDemoStopRequested()
                    if (index !== 2 && root.demoActive && root.demoMode === "bar")
                        root.barDemoStopRequested()
                }
            }

            Rectangle {
                // This is deliberately translucent, not a Qt item blur. With a
                // frosted profile selected, Hyprland's scoped layer rule blurs
                // the real wallpaper/window pixels behind the Live Canvas.
                visible: root.extraConfigsEnabled && root.advancedEditorOpen && root.frostedBackdropEnabled
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(64)
                radius: Style.space(8)
                color: Util.alpha(root.backgroundColor, 0.12)
                border.width: 1
                border.color: Util.alpha(Color.popups.border, 0.72)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(2)
                    Text { text: "LIVE BACKDROP PROBE"; color: root.foregroundColor; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.7 }
                    Text { Layout.fillWidth: true; text: "After Test Live, the wallpaper or windows behind this canvas should soften here. Application content itself remains sharp."; color: root.foregroundColor; opacity: 0.7; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }

            Button {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                text: "Reset variant colours"
                foreground: root.foregroundColor
                accent: root.accentColor
                background: Util.alpha(root.foregroundColor, 0.045)
                bordered: true
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && Object.keys(root.stagedColors).length > 0
                onClicked: {
                    root.resetVariantColors()
                    root.colorTestLiveRequested(root.selectedVariant, ({}), root.shellStyleForVariant(root.selectedVariant), root.desktopStyle, root.barStyleForVariant(root.selectedVariant), root.animationsStyle)
                }
            }

            Button {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                text: root.previewBusy ? "Applying live changes…" : "Test Live colours"
                foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                accent: root.accentColor
                background: root.accentColor
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: root.colorTestLiveRequested(root.selectedVariant, root.stagedColors, root.shellStyleForVariant(root.selectedVariant), root.desktopStyle, root.barStyleForVariant(root.selectedVariant), root.animationsStyle)
            }

            ColumnLayout {
                visible: !root.colorEditorOpen && !root.lookFeelEditorOpen && !root.advancedEditorOpen
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: root.variants
                    delegate: Button {
                        required property var modelData
                        Layout.fillWidth: true
                        text: (root.selectedVariant === modelData.variant ? "●  " : "○  ") + modelData.label
                        leftAlign: true
                        foreground: root.foregroundColor
                        accent: root.selectedVariant === modelData.variant ? root.accentColor : root.foregroundColor
                        background: root.selectedVariant === modelData.variant ? Util.alpha(root.accentColor, 0.12) : Util.alpha(root.foregroundColor, 0.04)
                        bordered: true
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.variantRequested(modelData.variant)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorMessage !== ""
                text: root.errorMessage
                color: Color.urgent
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Text {
                Layout.fillWidth: true
                visible: root.protocolMessage !== ""
                text: root.protocolMessage
                color: root.foregroundColor
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            }
        }

        Rectangle {
            id: scrollTrack
            visible: scrollArea.contentHeight > scrollArea.height
            z: 3
            width: Style.space(4)
            anchors.top: parent.top
            anchors.topMargin: Style.space(22)
            anchors.bottom: actionFooter.top
            anchors.bottomMargin: Style.space(22)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(7)
            radius: width / 2
            color: Util.alpha(root.foregroundColor, 0.08)

            Rectangle {
                width: parent.width
                height: Math.max(Style.space(36), parent.height * scrollArea.height / scrollArea.contentHeight)
                y: (parent.height - height) * (scrollArea.contentY / Math.max(1, scrollArea.contentHeight - scrollArea.height))
                radius: width / 2
                color: Util.alpha(root.accentColor, 0.7)
            }
        }

        Rectangle {
            id: actionFooter
            z: 4
            height: footerColumn.implicitHeight + Style.space(20)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: Util.alpha(Color.popups.background, 0.96)
            border.color: Color.popups.border
            border.width: 1

            ColumnLayout {
                id: footerColumn
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(5)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)

                    Button {
                        Layout.fillWidth: true
                        text: root.previewBusy
                            ? "Applying live changes…"
                            : root.colorEditorOpen
                                ? "Test Live colours"
                                : root.lookFeelEditorOpen || root.advancedEditorOpen
                                    ? "Test Live composition"
                                    : "Test Live"
                        foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        accent: root.accentColor
                        background: root.accentColor
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.colorTestLiveRequested(root.selectedVariant, root.stagedColors, root.shellStyleForVariant(root.selectedVariant), root.desktopStyle, root.barStyleForVariant(root.selectedVariant), root.animationsStyle)
                    }

                    Button {
                        Layout.fillWidth: true
                        text: root.applyBusy ? "Applying…" : "Apply theme"
                        foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        accent: root.accentColor
                        background: root.accentColor
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: themeNameDialog.openWith(root.suggestedThemeName)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)

                    Button {
                        Layout.fillWidth: true
                        text: root.demoBusy ? (root.demoActive ? "Stopping demo…" : "Starting demo…") : (root.demoActive ? "Stop demo" : "Start demo")
                        foreground: root.foregroundColor
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.demoActive ? root.closeCanvasRequested() : root.startDemoRequested()
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: root.advancedEditorOpen && root.advancedSection === 0
                        text: root.demoBusy
                            ? (root.demoActive && root.demoMode === "window" ? "Stopping Window…" : "Opening Window…")
                            : (root.demoActive && root.demoMode === "window" ? "Stop Window Demo" : "Window Demo")
                        foreground: root.foregroundColor
                        background: root.demoActive && root.demoMode === "window" ? Util.alpha(root.accentColor, 0.16) : Util.alpha(root.foregroundColor, 0.045)
                        accent: root.accentColor
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.windowDemoRequested()
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: root.advancedEditorOpen && root.advancedSection === 1
                        text: root.demoBusy
                            ? (root.demoActive && root.demoMode === "shell" ? "Stopping Shell…" : "Opening Shell…")
                            : (root.demoActive && root.demoMode === "shell" ? "Stop Shell Demo" : "Shell Demo")
                        foreground: root.foregroundColor
                        background: root.demoActive && root.demoMode === "shell" ? Util.alpha(root.accentColor, 0.16) : Util.alpha(root.foregroundColor, 0.045)
                        accent: root.accentColor
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.shellDemoRequested()
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: root.advancedEditorOpen && root.advancedSection === 2
                        text: root.demoBusy
                            ? (root.demoActive && root.demoMode === "bar" ? "Stopping Bar…" : "Opening Bar…")
                            : (root.demoActive && root.demoMode === "bar" ? "Stop Bar Demo" : "Bar Demo")
                        foreground: root.foregroundColor
                        background: root.demoActive && root.demoMode === "bar" ? Util.alpha(root.accentColor, 0.16) : Util.alpha(root.foregroundColor, 0.045)
                        accent: root.accentColor
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.barDemoRequested()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)

                    Button {
                        Layout.fillWidth: true
                        text: root.cancelBusy ? "Restoring original desktop…" : "Restore & close"
                        foreground: root.foregroundColor
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.cancelRequested()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)

                    Components.ProtocolNavigationControls {
                        Layout.fillWidth: true
                        caption: root.colorEditorOpen ? "UNDO" : "HISTORY"
                        canBack: root.protocolCanBack
                        canForward: root.protocolCanForward
                        busy: root.protocolBusy
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onBackRequested: root.protocolBackRequested()
                        onForwardRequested: root.protocolForwardRequested()
                    }

                    Button {
                        Layout.preferredWidth: Style.space(72)
                        text: "Hide"
                        foreground: root.foregroundColor
                        bordered: true
                        tooltipText: "Hide Studio panel"
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.hideRequested()
                    }
                }
            }
        }
    }

    // Preview and Apply update the long-lived Quickshell process. The existing
    // buttons already disable themselves, but a disabled-looking panel still
    // accepts focus, wheel input, and accidental clicks while the shell is
    // settling. Keep the native panel visible as orientation, then make the
    // transaction explicitly modal until the backend reports completion.
    FocusScope {
        id: operationShield
        anchors.fill: parent
        visible: root.operationBusy
        z: 20
        focus: visible

        Keys.onPressed: function(event) { event.accepted = true }
        onVisibleChanged: Qt.callLater(function() {
            if (operationShield.visible)
                operationShield.forceActiveFocus()
            else
                keyCatcher.forceActiveFocus()
        })

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: function(mouse) { mouse.accepted = true }
            onReleased: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }

        Rectangle {
            width: Math.min(parent.width - Style.space(48), Style.space(370))
            height: operationDetailText.implicitHeight + Style.space(112)
            anchors.centerIn: parent
            radius: Style.cornerRadius
            color: Color.popups.background
            border.width: 1
            border.color: Color.popups.border

            Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(44)
                spacing: Style.space(9)

                Item {
                    width: Style.space(28)
                    height: Style.space(28)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: Style.space(3)
                        border.color: Util.alpha(Color.popups.text, 0.2)
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "transparent"
                        border.width: Style.space(3)
                        border.color: root.accentColor
                        rotation: 0

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: operationShield.visible
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.operationTitle
                    horizontalAlignment: Text.AlignHCenter
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                }

                Text {
                    id: operationDetailText
                    width: parent.width
                    text: root.operationDetail
                    horizontalAlignment: Text.AlignHCenter
                    color: Color.popups.text
                    opacity: 0.62
                    wrapMode: Text.WordWrap
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }
            }
        }
    }

    Components.ThemeNameDialog {
        id: themeNameDialog
        anchors.fill: parent
        busy: root.applyBusy
        onConfirmed: function(name, generateUnlock, capturePreview) {
            root.applyRequested(root.selectedVariant, name, generateUnlock, capturePreview)
        }
    }

    onActiveChanged: if (active)
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); })
    onSelectedVariantChanged: {
        root.stagedColors = root.overridesForVariant(root.selectedVariant)
        root.colorEditorOpen = Object.keys(root.stagedColors).length > 0
        root.colorPreviewLive = false
        root.editingColorRole = "accent"
    }
}
