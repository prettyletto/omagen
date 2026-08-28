import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// Shell owns the visual language of Quickshell surfaces. The first slice is
// intentionally small: choose a complete look, then reveal native
// shell.toml tokens only when the user wants to tune it.
Item {
    id: root

    // Legacy fields remain readable by previews and older sessions. New
    // writes use preset plus explicit overrides.
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property int activePage: 0
    property string rawMessage: ""
    property bool showAdvanced: false
    property bool showAdjustments: false
    property bool showExpertTokens: false
    property string lastRecipe: "default"

    signal styleChanged(var shellStyle)

    readonly property var recipes: [
        { key: "default", title: "Default", eyebrow: "NATIVE BASELINE", description: "Keep the active Omarchy shell behavior and native surface treatment." },
        { key: "glass", title: "Glass", eyebrow: "BACKDROP GLASS", description: "Use translucent shell surfaces with compositor backdrop blur behind them." }
    ]

    // These are actual shell.toml values understood by the installed
    // Quickshell reader. Future visual engines can add more fields here
    // without changing the preset/override contract.
    readonly property var advancedFields: [
        { key: "popups.background-alpha", label: "Popup opacity", description: "Launcher and popup surface alpha." },
        { key: "menu.background-alpha", label: "Menu opacity", description: "Context and application menu surface alpha." },
        { key: "launcher.background-alpha", label: "Launcher opacity", description: "Launcher surface alpha." },
        { key: "tooltip.background-alpha", label: "Tooltip opacity", description: "Tooltip surface alpha." },
        { key: "notifications.background-alpha", label: "Notification opacity", description: "Notification surface alpha." },
        { key: "polkit.background-alpha", label: "Security prompt opacity", description: "Authentication prompt surface alpha." },
        { key: "lock.background-alpha", label: "Lock screen opacity", description: "Lock screen surface alpha." },
        { key: "spacing.scale", label: "Shell spacing", description: "Global shell spacing multiplier." }
    ]

    // These are the user-facing Shell contract. The backend maps the choices
    // to the native Quickshell shell.toml keys; users do not need to know those
    // keys to make a meaningful change.
    readonly property var surfaceOptions: [
        { key: "flat", title: "Flat", description: "Use the theme's direct surface hierarchy." },
        { key: "layered", title: "Layered", description: "Separate popups and controls into deeper surfaces." },
        { key: "contrast", title: "Contrast", description: "Make selected and active shell states easier to read." },
        { key: "accent", title: "Accent", description: "Use the theme accent for selected shell states." }
    ]
    readonly property var detailOptions: [
        { key: "native", title: "Default", description: "Keep Quickshell's native border language." },
        { key: "framed", title: "Framed", description: "Give shell controls and surfaces a complete frame." },
        { key: "edge", title: "Edge", description: "Use a restrained edge marker for selected states." },
        { key: "focus", title: "Focus", description: "Reserve stronger borders for the active state." }
    ]
    readonly property var tooltipOptions: [
        { key: "native", title: "Default", description: "Use the theme's tooltip border and feedback." },
        { key: "accent", title: "Accent", description: "Give tooltips the theme accent border." }
    ]
    readonly property var notificationOptions: [
        { key: "native", title: "Default", description: "Use the theme's notification feedback." },
        { key: "accent", title: "Accent", description: "Use the accent for notification borders and countdowns." }
    ]
    readonly property var clarityOptions: [
        { key: "preset", title: "Preset", description: "Use the selected preset's surface clarity." },
        { key: "solid", title: "Solid", description: "Keep more of the surface opaque and grounded." },
        { key: "balanced", title: "Balanced", description: "Use a middle ground between surface and desktop." },
        { key: "clear", title: "Clear", description: "Reveal more of the desktop behind shell surfaces." }
    ]
    readonly property var clarityKeys: [
        "bar.background-alpha", "popups.background-alpha", "menu.background-alpha",
        "launcher.background-alpha", "tooltip.background-alpha", "notifications.background-alpha",
        "polkit.background-alpha", "lock.background-alpha"
    ]
    readonly property var surfaceOpacityKeys: [
        "bar.background-alpha", "popups.background-alpha", "menu.background-alpha", "launcher.background-alpha"
    ]
    readonly property var feedbackOpacityKeys: [
        "tooltip.background-alpha", "notifications.background-alpha", "polkit.background-alpha", "lock.background-alpha"
    ]

    function presetTokens(key) {
        if (key === "glass") {
            return {
                "bar.background-alpha": "0.72",
                "popups.background-alpha": "0.72",
                "menu.background-alpha": "0.72",
                "launcher.background-alpha": "0.72",
                "tooltip.background-alpha": "0.88",
                "notifications.background-alpha": "0.86",
                "polkit.background-alpha": "0.88",
                "lock.background-alpha": "0.82"
            }
        }
        return ({})
    }

    function presetMeaning(key) {
        if (key === "glass") {
            return "Layered surfaces; native borders and feedback; 72% bar, popup, menu, and launcher opacity; 88% tooltip and security prompt; 86% notification; 82% lock screen. A scoped Hyprland rule blurs the backdrop behind shell layers only."
        }
        return "Flat surfaces; native borders and feedback. No shell alpha values or compositor rules are written, so the active theme and your shell.toml stay in charge."
    }

    function presetRecipeRows(key) {
        if (key === "glass") {
            return [
                "Surfaces · Layered",
                "Borders · Native",
                "Feedback · Native",
                "Backdrop · Scoped shell blur",
                "Main surfaces · 72%"
            ]
        }
        return [
            "Surfaces · Flat",
            "Borders · Native",
            "Feedback · Native",
            "Backdrop · None",
            "Alpha · Theme default"
        ]
    }

    function currentPreset() {
        var key = String(root.shellStyle.preset || "default")
        return key === "glass" ? "glass" : "default"
    }

    function overridesCopy() {
        var next = {}
        var source = root.shellStyle.overrides || ({})
        for (var key in source)
            next[key] = String(source[key])
        return next
    }

    function effectiveTokenKeys() {
        var keys = []
        var seen = {}
        var preset = presetTokens(root.currentPreset())
        var custom = root.shellStyle.overrides || ({})
        for (var presetKey in preset) {
            keys.push(presetKey)
            seen[presetKey] = true
        }
        for (var customKey in custom) {
            if (!seen[customKey])
                keys.push(customKey)
        }
        keys.sort()
        return keys
    }

    function tokenValue(key) {
        var custom = root.shellStyle.overrides || ({})
        if (custom[key] !== undefined && custom[key] !== null && String(custom[key]) !== "")
            return String(custom[key])
        var preset = presetTokens(root.currentPreset())
        return preset[key] === undefined ? "" : String(preset[key])
    }

    function tokenSource(key) {
        var custom = root.shellStyle.overrides || ({})
        if (custom[key] !== undefined && custom[key] !== null && String(custom[key]) !== "")
            return "CUSTOM"
        var preset = presetTokens(root.currentPreset())
        return preset[key] === undefined ? "NATIVE" : "PRESET"
    }

    function emitStyle(preset, overrides, styleBase) {
        var selected = preset === undefined ? root.currentPreset() : preset
        var source = styleBase || root.shellStyle || ({})
        var next = {
            preset: selected,
            // Keep compatibility values readable by the current preview.
            surface: source.surface || (selected === "glass" ? "layered" : "flat"),
            detail: source.detail || "native",
            tooltip: source.tooltip || "native",
            notifications: source.notifications || "native",
            overrides: overrides === undefined ? root.overridesCopy() : overrides
        }
        root.lastRecipe = next.preset
        root.styleChanged(next)
    }

    function applyPreset(key) {
        var selected = key === "glass" ? "glass" : "default"
        root.emitStyle(selected, root.overridesCopy(), {
            surface: selected === "glass" ? "layered" : "flat",
            detail: "native",
            tooltip: "native",
            notifications: "native"
        })
    }

    function chooseShell(group, key) {
        var next = {
            preset: root.currentPreset(),
            surface: root.shellStyle.surface || (root.currentPreset() === "glass" ? "layered" : "flat"),
            detail: root.shellStyle.detail || "native",
            tooltip: root.shellStyle.tooltip || "native",
            notifications: root.shellStyle.notifications || "native",
            overrides: root.overridesCopy()
        }
        next[group] = key
        root.emitStyle(next.preset, next.overrides, next)
    }

    function clarityValues(key) {
        if (key === "solid") {
            return { base: "0.96", tooltip: "0.98", notifications: "0.97", polkit: "0.98" }
        }
        if (key === "balanced") {
            return { base: "0.88", tooltip: "0.92", notifications: "0.90", polkit: "0.93" }
        }
        return { base: "0.74", tooltip: "0.84", notifications: "0.80", polkit: "0.86" }
    }

    function clarityChoice() {
        var overrides = root.shellStyle.overrides || ({})
        var hasCustom = false
        for (var index = 0; index < root.clarityKeys.length; ++index) {
            if (overrides[root.clarityKeys[index]] !== undefined && overrides[root.clarityKeys[index]] !== null && String(overrides[root.clarityKeys[index]]) !== "") {
                hasCustom = true
                break
            }
        }
        if (!hasCustom)
            return "preset"

        var choices = ["solid", "balanced", "clear"]
        for (var choiceIndex = 0; choiceIndex < choices.length; ++choiceIndex) {
            var choice = choices[choiceIndex]
            var values = root.clarityValues(choice)
            var matches = true
            for (var keyIndex = 0; keyIndex < root.clarityKeys.length; ++keyIndex) {
                var key = root.clarityKeys[keyIndex]
                var expected = key === "tooltip.background-alpha" ? values.tooltip
                    : key === "notifications.background-alpha" ? values.notifications
                    : key === "polkit.background-alpha" ? values.polkit
                    : values.base
                if (String(overrides[key] || "") !== expected) {
                    matches = false
                    break
                }
            }
            if (matches)
                return choice
        }
        return "custom"
    }

    function chooseClarity(key) {
        var next = root.overridesCopy()
        for (var index = 0; index < root.clarityKeys.length; ++index) {
            var token = root.clarityKeys[index]
            if (key === "preset") {
                delete next[token]
                continue
            }
            var values = root.clarityValues(key)
            next[token] = token === "tooltip.background-alpha" ? values.tooltip
                : token === "notifications.background-alpha" ? values.notifications
                : token === "polkit.background-alpha" ? values.polkit
                : values.base
        }
        root.emitStyle(root.currentPreset(), next)
    }

    function groupedTokenValue(keys) {
        for (var index = 0; index < keys.length; ++index) {
            var value = root.tokenValue(keys[index])
            if (value !== "")
                return value
        }
        return ""
    }

    function opacityPercent(keys) {
        var value = Number(root.groupedTokenValue(keys))
        return isFinite(value) ? String(Math.round(value * 100)) : ""
    }

    function setOpacityPercent(keys, percent) {
        var value = Math.max(0.0, Math.min(1.0, Number(percent) / 100.0))
        if (!isFinite(value))
            return
        var next = root.overridesCopy()
        var formatted = value.toFixed(2)
        for (var index = 0; index < keys.length; ++index)
            next[keys[index]] = formatted
        root.emitStyle(root.currentPreset(), next)
    }

    function clearTokenGroup(keys) {
        var next = root.overridesCopy()
        for (var index = 0; index < keys.length; ++index)
            delete next[keys[index]]
        root.emitStyle(root.currentPreset(), next)
    }

    function setOverride(key, value) {
        var next = root.overridesCopy()
        var clean = String(value === undefined || value === null ? "" : value).trim()
        if (clean === "")
            delete next[key]
        else
            next[key] = clean
        root.emitStyle(root.currentPreset(), next)
    }

    function clearToken(key) {
        root.setOverride(key, "")
    }

    function overrideValue(key) {
        var value = (root.shellStyle.overrides || ({ }))[key]
        return value === undefined || value === null ? "" : String(value)
    }

    function addRawOverride() {
        var section = rawSectionInput.text.trim()
        var key = rawKeyInput.text.trim()
        var value = rawValueInput.text.trim()
        if (section === "" || key === "" || value === "") {
            root.rawMessage = "Enter a section, key, and value."
            return
        }
        if (!/^[A-Za-z0-9_-]+$/.test(section) || !/^[A-Za-z0-9_-]+$/.test(key)) {
            root.rawMessage = "Use simple section.key names."
            return
        }
        root.setOverride(section + "." + key, value)
        root.rawMessage = "Custom token staged."
        rawValueInput.text = ""
    }

    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body
        width: root.width
        spacing: Style.space(10)

        Text {
            Layout.fillWidth: true
            text: "SHELL / CHOOSE A LOOK"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.0
        }

        Text {
            Layout.fillWidth: true
            text: "A preset is a complete starting recipe, not a lock. Advanced controls below can replace its surface layers, borders, and feedback details; Reset returns only that control to the selected recipe."
            color: Color.foreground
            opacity: 0.66
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            Repeater {
                model: root.recipes
                delegate: DesktopOptionCard {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(78)
                    title: modelData.title
                    description: modelData.description
                    selected: root.currentPreset() === modelData.key
                    onClicked: root.applyPreset(modelData.key)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Style.space(8)
                        spacing: Style.space(2)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.eyebrow
                            color: Color.accent
                            opacity: 0.72
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }
                    }
                }
            }
        }

        BorderSurface {
            Layout.fillWidth: true
            implicitHeight: summaryColumn.implicitHeight + Style.space(18)
            color: Util.alpha(Color.accent, 0.08)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Util.alpha(Color.accent, 0.72), 1)

            ColumnLayout {
                id: summaryColumn
                anchors.fill: parent
                anchors.margins: Style.space(9)
                spacing: Style.space(3)
                Text {
                    Layout.fillWidth: true
                    text: root.currentPreset() === "glass" ? "GLASS PRESET ACTIVE" : "DEFAULT PRESET ACTIVE"
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: root.currentPreset() === "glass"
                        ? root.presetMeaning("glass")
                        : root.presetMeaning("default")
                    color: Color.foreground
                    opacity: 0.64
                    wrapMode: Text.WordWrap
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Style.space(5)
                    Repeater {
                        model: root.presetRecipeRows(root.currentPreset())
                        delegate: BorderSurface {
                            required property string modelData
                            implicitWidth: chipLabel.implicitWidth + Style.space(12)
                            implicitHeight: chipLabel.implicitHeight + Style.space(6)
                            color: Util.alpha(Color.foreground, 0.05)
                            radius: Math.max(Style.space(3), Style.cornerRadius / 3)
                            borderSpec: Border.flat(Util.alpha(Color.accent, 0.28), 1)
                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: Color.foreground
                                opacity: 0.78
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }
                    }
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(38)
            text: root.showAdvanced ? "Hide advanced Shell controls" : "Advanced Shell controls"
            foreground: Color.foreground
            background: Util.alpha(Color.foreground, 0.045)
            accent: Color.accent
            bordered: true
            onClicked: root.showAdvanced = !root.showAdvanced
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showAdvanced
            spacing: Style.space(9)

            Text {
                Layout.fillWidth: true
                text: "SHELL ADJUSTMENTS"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
            }
            Text {
                Layout.fillWidth: true
                text: "Every choice is written through the native shell compiler. Surface, border, tooltip, and notification controls change the recipe fields; clarity and numeric values become explicit shell tokens."
                color: Color.foreground
                opacity: 0.62
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Text {
                Layout.fillWidth: true
                text: "SURFACE CLARITY"
                color: Color.foreground
                opacity: 0.52
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(7)
                rowSpacing: Style.space(7)

                Repeater {
                    model: root.clarityOptions
                    delegate: DesktopOptionCard {
                        required property var modelData
                        Layout.fillWidth: true
                        compact: true
                        title: modelData.title
                        description: modelData.description
                        selected: root.clarityChoice() === modelData.key
                        onClicked: root.chooseClarity(modelData.key)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "SHELL CHARACTER"
                color: Color.foreground
                opacity: 0.52
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
            }

            Text {
                Layout.fillWidth: true
                text: "These controls are independent of opacity. They are the visible parts of the selected recipe, and you can override any of them without losing the preset's other values."
                color: Color.foreground
                opacity: 0.62
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Text {
                Layout.fillWidth: true
                text: "SURFACE LAYERS"
                color: Color.foreground
                opacity: 0.52
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(7)
                rowSpacing: Style.space(7)
                Repeater {
                    model: root.surfaceOptions
                    delegate: DesktopOptionCard {
                        required property var modelData
                        Layout.fillWidth: true
                        compact: true
                        title: modelData.title
                        description: modelData.description
                        selected: (root.shellStyle.surface || (root.currentPreset() === "glass" ? "layered" : "flat")) === modelData.key
                        onClicked: root.chooseShell("surface", modelData.key)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "BORDERS + ACTIVE DETAIL"
                color: Color.foreground
                opacity: 0.52
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(7)
                rowSpacing: Style.space(7)
                Repeater {
                    model: root.detailOptions
                    delegate: DesktopOptionCard {
                        required property var modelData
                        Layout.fillWidth: true
                        compact: true
                        title: modelData.title
                        description: modelData.description
                        selected: (root.shellStyle.detail || "native") === modelData.key
                        onClicked: root.chooseShell("detail", modelData.key)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(7)
                rowSpacing: Style.space(7)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "TOOLTIP DETAIL"; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Repeater {
                        model: root.tooltipOptions
                        delegate: DesktopOptionCard {
                            required property var modelData
                            Layout.fillWidth: true
                            compact: true
                            title: modelData.title
                            description: modelData.description
                            selected: (root.shellStyle.tooltip || "native") === modelData.key
                            onClicked: root.chooseShell("tooltip", modelData.key)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "NOTIFICATION DETAIL"; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Repeater {
                        model: root.notificationOptions
                        delegate: DesktopOptionCard {
                            required property var modelData
                            Layout.fillWidth: true
                            compact: true
                            title: modelData.title
                            description: modelData.description
                            selected: (root.shellStyle.notifications || "native") === modelData.key
                            onClicked: root.chooseShell("notifications", modelData.key)
                        }
                    }
                }
            }

            ShellRangeField {
                Layout.fillWidth: true
                label: "Surface opacity"
                description: "Bar, menus, launcher, and popups. Range: 0%–100%; 0% is fully transparent and 100% is fully solid. This is separate from Shell spacing below."
                value: root.opacityPercent(root.surfaceOpacityKeys)
                fallback: root.currentPreset() === "glass" ? 72 : 88
                minimum: 0
                maximum: 100
                step: 1
                decimals: 0
                suffix: "%"
                integer: true
                modified: root.surfaceOpacityKeys.some(function(key) { return root.overrideValue(key) !== "" })
                onValueEdited: function(value) { root.setOpacityPercent(root.surfaceOpacityKeys, value) }
                onResetRequested: root.clearTokenGroup(root.surfaceOpacityKeys)
            }

            ShellRangeField {
                Layout.fillWidth: true
                label: "Feedback opacity"
                description: "Tooltips, notifications, security prompts, and the lock screen. Range: 0%–100%; 0% is fully transparent."
                value: root.opacityPercent(root.feedbackOpacityKeys)
                fallback: root.currentPreset() === "glass" ? 87 : 90
                minimum: 0
                maximum: 100
                step: 1
                decimals: 0
                suffix: "%"
                integer: true
                modified: root.feedbackOpacityKeys.some(function(key) { return root.overrideValue(key) !== "" })
                onValueEdited: function(value) { root.setOpacityPercent(root.feedbackOpacityKeys, value) }
                onResetRequested: root.clearTokenGroup(root.feedbackOpacityKeys)
            }

            ShellRangeField {
                Layout.fillWidth: true
                label: "Shell spacing"
                description: "Scale the room between shell controls and popup rows. Range: 0.80×–1.20×; this is not an opacity control."
                value: root.overrideValue("spacing.scale")
                fallback: 1.0
                minimum: 0.80
                maximum: 1.20
                step: 0.01
                decimals: 2
                suffix: "×"
                modified: root.overrideValue("spacing.scale") !== ""
                onValueEdited: function(value) { root.setOverride("spacing.scale", value) }
                onResetRequested: root.clearToken("spacing.scale")
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(34)
                text: root.showExpertTokens ? "Hide expert shell tokens" : "Expert shell tokens"
                foreground: Color.foreground
                background: Util.alpha(Color.foreground, 0.045)
                accent: Color.accent
                bordered: true
                onClicked: root.showExpertTokens = !root.showExpertTokens
            }

            BorderSurface {
                Layout.fillWidth: true
                visible: root.showExpertTokens
                implicitHeight: customColumn.implicitHeight + Style.space(18)
                color: Util.alpha(Color.foreground, 0.025)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Util.alpha(Color.foreground, 0.18), 1)

                ColumnLayout {
                    id: customColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(7)

                    Text {
                        Layout.fillWidth: true
                        text: "CUSTOM TOKENS · PRESET VALUES INCLUDED"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "The list shows the effective contract for the selected preset. PRESET values are generated; CUSTOM values override them."
                        color: Color.foreground
                        opacity: 0.58
                        wrapMode: Text.WordWrap
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Repeater {
                        model: root.effectiveTokenKeys()
                        delegate: RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: Style.space(6)
                            Text {
                                Layout.fillWidth: true
                                text: modelData + "  " + root.tokenValue(modelData)
                                color: Color.foreground
                                opacity: 0.78
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.tokenSource(modelData)
                                color: root.tokenSource(modelData) === "CUSTOM" ? Color.accent : Color.foreground
                                opacity: root.tokenSource(modelData) === "NATIVE" ? 0.42 : 0.78
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }
                            Button {
                                visible: root.tokenSource(modelData) === "CUSTOM"
                                Layout.preferredWidth: Style.space(42)
                                Layout.preferredHeight: Style.space(24)
                                text: "Reset"
                                fontSize: Style.font.caption
                                foreground: Color.foreground
                                background: Util.alpha(Color.foreground, 0.045)
                                accent: Color.accent
                                bordered: true
                                onClicked: root.clearToken(modelData)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(5)
                        TextInput {
                            id: rawSectionInput
                            Layout.preferredWidth: Style.space(84)
                            Layout.preferredHeight: Style.space(32)
                            text: "popups"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            selectByMouse: true
                            clip: true
                        }
                        TextInput {
                            id: rawKeyInput
                            Layout.preferredWidth: Style.space(100)
                            Layout.preferredHeight: Style.space(32)
                            text: "background-alpha"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            selectByMouse: true
                            clip: true
                        }
                        TextInput {
                            id: rawValueInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(32)
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            selectByMouse: true
                            clip: true
                            Keys.onReturnPressed: root.addRawOverride()
                        }
                        Button {
                            Layout.preferredWidth: Style.space(48)
                            Layout.preferredHeight: Style.space(32)
                            text: "Add"
                            foreground: Contrast.textFor(Color.accent, Color.background, Color.foreground)
                            background: Color.accent
                            accent: Color.accent
                            bordered: false
                            onClicked: root.addRawOverride()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.rawMessage !== ""
                        text: root.rawMessage
                        color: Color.accent
                        opacity: 0.78
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }
}
