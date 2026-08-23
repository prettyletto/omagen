import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components

PanelWindow {
    id: root

    property bool active: false
    property bool previewBusy: false
    property bool generationBusy: false
    property bool workspaceReady: false
    property bool demoBusy: false
    property bool demoActive: false
    property bool cancelBusy: false
    property bool applyBusy: false
    property bool extraConfigsEnabled: false
    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" })
    property bool applyRecoveryRequired: false
    property bool protocolCanBack: false
    property bool protocolCanForward: false
    property bool protocolBusy: false
    property string protocolMessage: ""
    property string errorMessage: ""
    property string selectedVariant: "source"
    property string monitorName: ""
    property string suggestedThemeName: ""
    property var variants: []
    property var palettes: ({})
    property bool colorEditorOpen: false
    property bool colorPreviewLive: false
    property string editingColorRole: "accent"
    property var stagedColors: ({})
    property var colorOverridesByVariant: ({})
    property bool moreColorsOpen: false
    property string expandedColorGroup: "surfaces"
    property bool advancedEditorOpen: false

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
    signal cancelRequested()
    signal variantRequested(string variant)
    signal colorTestLiveRequested(string variant, var overrides, var shellStyle, var desktopStyle, var barStyle)
    signal advancedStylesChanged(var shellStyle, var desktopStyle, var barStyle)
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
        root.editingColorRole = "accent"
        root.moreColorsOpen = false
        root.expandedColorGroup = "surfaces"
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
        if (Object.keys(root.stagedColors).length > 0)
            root.colorEditorOpen = true
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
        // the panel translucent when Backdrop blur is selected; an almost
        // opaque panel would hide the compositor effect even with the rule.
        color: Util.alpha(
            Color.popups.background,
            root.desktopStyle.inactiveStyle === "blur" ? 0.72 : 0.97
        )
        border.width: 1
        border.color: Color.popups.border

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
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
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: root.generationBusy ? "Preparing palette directions" : "Real desktop / " + (root.monitorName || "focused monitor")
                        color: Color.foreground
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
                    foreground: Color.foreground
                    tooltipText: "Hide Studio panel"
                    onClicked: root.hideRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(76)
                radius: Style.cornerRadius
                color: Util.alpha(Color.accent, 0.1)
                border.width: 1
                border.color: Util.alpha(Color.accent, 0.45)

                Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(3)
                    Text {
                        text: "ACTIVE PRESET"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    Text {
                        text: root.selectedVariant.toUpperCase()
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.generationBusy ? "Generating six interpretations…" : root.colorEditorOpen ? "Tune a staged colour, then reset it or return to the preset directions." : root.demoActive ? "Choose another preset to reapply it without losing this canvas." : root.workspaceReady ? "Choose a direction to apply it to the real desktop." : "Preparing the Live Canvas…"
                color: Color.foreground
                opacity: 0.62
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            Button {
                Layout.fillWidth: true
                text: root.colorEditorOpen ? "← Preset directions" : "Edit colours"
                foreground: Color.foreground
                accent: Color.accent
                background: root.colorEditorOpen ? Util.alpha(Color.foreground, 0.045) : Util.alpha(Color.accent, 0.1)
                bordered: true
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: {
                    root.colorEditorOpen = !root.colorEditorOpen
                    if (root.colorEditorOpen)
                        root.advancedEditorOpen = false
                }
            }

            Button {
                visible: root.extraConfigsEnabled
                Layout.fillWidth: true
                text: root.advancedEditorOpen ? "← Close advanced settings" : "Advanced settings · Window / Shell / Bar"
                foreground: Color.foreground
                accent: Color.accent
                background: root.advancedEditorOpen ? Util.alpha(Color.accent, 0.1) : Util.alpha(Color.foreground, 0.045)
                bordered: true
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: {
                    root.advancedEditorOpen = !root.advancedEditorOpen
                    if (root.advancedEditorOpen)
                        root.colorEditorOpen = false
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
                        foreground: root.editingColorRole === modelData.key ? Color.background : Color.foreground
                        accent: Color.accent
                        background: root.editingColorRole === modelData.key ? Color.accent : Util.alpha(Color.foreground, 0.045)
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
                foreground: Color.foreground
                accent: Color.accent
                background: Util.alpha(Color.foreground, 0.045)
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
                            foreground: Color.foreground
                            accent: Color.accent
                            background: Util.alpha(Color.foreground, 0.045)
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
                                    foreground: root.editingColorRole === modelData.key ? Color.background : Color.foreground
                                    accent: Color.accent
                                    background: root.editingColorRole === modelData.key ? Color.accent : Util.alpha(Color.foreground, 0.045)
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

            Components.AdvancedStyleEditor {
                visible: root.extraConfigsEnabled && root.advancedEditorOpen
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                shellStyle: root.shellStyle
                desktopStyle: root.desktopStyle
                barStyle: root.barStyle
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onStylesChanged: function(shellStyle, desktopStyle, barStyle) {
                    root.advancedStylesChanged(shellStyle, desktopStyle, barStyle)
                }
            }

            Button {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                text: "Reset variant colours"
                foreground: Color.foreground
                accent: Color.accent
                background: Util.alpha(Color.foreground, 0.045)
                bordered: true
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy && Object.keys(root.stagedColors).length > 0
                onClicked: {
                    root.resetVariantColors()
                    root.colorTestLiveRequested(root.selectedVariant, ({}))
                }
            }

            Button {
                visible: root.colorEditorOpen
                Layout.fillWidth: true
                text: root.previewBusy ? "Applying live changes…" : "Test Live colours"
                foreground: Color.background
                accent: Color.accent
                background: Color.accent
                enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                onClicked: root.colorTestLiveRequested(root.selectedVariant, root.stagedColors, root.shellStyle, root.desktopStyle, root.barStyle)
            }

            ColumnLayout {
                visible: !root.colorEditorOpen && !root.advancedEditorOpen
                Layout.fillWidth: true
                spacing: Style.space(5)

                Repeater {
                    model: root.variants
                    delegate: Button {
                        required property var modelData
                        Layout.fillWidth: true
                        text: (root.selectedVariant === modelData.variant ? "●  " : "○  ") + modelData.label
                        leftAlign: true
                        foreground: Color.foreground
                        accent: root.selectedVariant === modelData.variant ? Color.accent : Color.foreground
                        background: root.selectedVariant === modelData.variant ? Util.alpha(Color.accent, 0.12) : Util.alpha(Color.foreground, 0.04)
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
                color: Color.foreground
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
            color: Util.alpha(Color.foreground, 0.08)

            Rectangle {
                width: parent.width
                height: Math.max(Style.space(36), parent.height * scrollArea.height / scrollArea.contentHeight)
                y: (parent.height - height) * (scrollArea.contentY / Math.max(1, scrollArea.contentHeight - scrollArea.height))
                radius: width / 2
                color: Util.alpha(Color.accent, 0.7)
            }
        }

        Rectangle {
            id: actionFooter
            z: 4
            height: Style.space(146)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: Util.alpha(Color.popups.background, 0.96)
            border.color: Color.popups.border
            border.width: 1

            ColumnLayout {
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
                                : root.advancedEditorOpen
                                    ? "Test Live composition"
                                    : "Test Live"
                        foreground: Color.background
                        accent: Color.accent
                        background: Color.accent
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.colorTestLiveRequested(root.selectedVariant, root.stagedColors, root.shellStyle, root.desktopStyle, root.barStyle)
                    }

                    Button {
                        Layout.fillWidth: true
                        text: root.applyBusy ? "Applying…" : "Apply theme"
                        foreground: Color.background
                        accent: Color.accent
                        background: Color.accent
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
                        foreground: Color.foreground
                        bordered: true
                        enabled: !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.demoActive ? root.closeCanvasRequested() : root.startDemoRequested()
                    }

                    Button {
                        Layout.fillWidth: true
                        text: root.cancelBusy ? "Restoring original desktop…" : "Restore & close"
                        foreground: Color.foreground
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
                        foreground: Color.foreground
                        bordered: true
                        tooltipText: "Hide Studio panel"
                        enabled: !root.previewBusy && !root.demoBusy && !root.cancelBusy && !root.applyBusy
                        onClicked: root.hideRequested()
                    }
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
