import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// The Shell engine is an additive editor for the real Quattro shell.toml
// readers. Quick composition presets remain available, while every explicit
// field below writes only a section.key override and leaves other Omarchy
// defaults untouched.
Item {
    id: root

    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property int activePage: 0
    property string rawMessage: ""
    property bool showAdvanced: false
    property string lastRecipe: "native"

    signal styleChanged(var shellStyle)

    readonly property var pages: [
        { title: "Start", eyebrow: "QUICK SETUP" },
        { title: "Surfaces", eyebrow: "POPUPS + MENUS" },
        { title: "States", eyebrow: "CONTROLS" },
        { title: "Scale", eyebrow: "TYPE + SPACING" },
        { title: "Feedback", eyebrow: "ALERTS + SECURITY" },
        { title: "Advanced", eyebrow: "DIRECT READER" }
    ]
    readonly property var recipes: [
        { key: "native", title: "Native", eyebrow: "START CLEAN", description: "Keep the active Omarchy theme and user shell defaults." },
        { key: "comfortable", title: "Comfortable", eyebrow: "ROOM TO BREATHE", description: "Slightly larger type, controls, and popup rows." },
        { key: "compact", title: "Compact", eyebrow: "MORE ON SCREEN", description: "Tighter spacing and smaller controls for dense workflows." },
        { key: "contrast", title: "High contrast", eyebrow: "EASIER TO READ", description: "Stronger focus, selection, tooltip, and notification states." }
    ]
    readonly property var stateModes: [
        { key: "native", title: "Native", description: "Keep the theme's control states." },
        { key: "focus", title: "Clear focus", description: "Make keyboard focus obvious." },
        { key: "selection", title: "Strong selection", description: "Make selected rows and tabs pop." }
    ]
    readonly property var densityModes: [
        { key: "native", title: "Theme default", description: "Let the active theme decide." },
        { key: "comfortable", title: "Comfortable", description: "More breathing room in shell controls." },
        { key: "compact", title: "Compact", description: "Fit more rows and controls on screen." }
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

    function overridesCopy() {
        var next = {}
        for (var key in (root.shellStyle.overrides || {}))
            next[key] = String(root.shellStyle.overrides[key])
        return next
    }

    function emitStyle(nextOverrides, surface, detail, tooltip, notifications) {
        root.lastRecipe = ""
        root.styleChanged({
            surface: surface === undefined ? (root.shellStyle.surface || "flat") : surface,
            detail: detail === undefined ? (root.shellStyle.detail || "native") : detail,
            tooltip: tooltip === undefined ? (root.shellStyle.tooltip || "native") : tooltip,
            notifications: notifications === undefined ? (root.shellStyle.notifications || "native") : notifications,
            overrides: nextOverrides
        })
    }

    function setOverride(key, value) {
        var next = root.overridesCopy()
        var clean = String(value === undefined || value === null ? "" : value).trim()
        if (clean === "")
            delete next[key]
        else
            next[key] = clean
        root.emitStyle(next)
    }

    function overrideValue(key) {
        var value = (root.shellStyle.overrides || {})[key]
        return value === undefined || value === null ? "" : String(value)
    }

    function applyRecipe(key) {
        var next = {}
        var surface = "flat"
        var detail = "native"
        var tooltip = "native"
        var notifications = "native"
        if (key === "comfortable") {
            next["font.base-size"] = "13"
            next["spacing.scale"] = "1.08"
            next["spacing.control-height"] = "32"
            next["spacing.control-gap"] = "9"
            next["spacing.popup-row-height"] = "32"
        } else if (key === "compact") {
            next["font.base-size"] = "11"
            next["spacing.scale"] = "0.92"
            next["spacing.control-height"] = "26"
            next["spacing.control-gap"] = "6"
            next["spacing.popup-row-height"] = "26"
        } else if (key === "contrast") {
            detail = "focus"
            tooltip = "accent"
            notifications = "accent"
            next["controls.focus-color"] = "accent"
            next["controls.focus-fill-alpha"] = "0.18"
            next["controls.focus-border-width"] = "2"
            next["controls.selected-color"] = "accent"
            next["controls.selected-fill-alpha"] = "0.22"
            next["tooltip.border-alpha"] = "1.0"
            next["notifications.border-alpha"] = "1.0"
        }
        root.emitStyle(next, surface, detail, tooltip, notifications)
        root.lastRecipe = key
    }

    function toggleAdvanced() {
        root.showAdvanced = !root.showAdvanced
    }

    function mergeOverrides(changes, removals) {
        var next = root.overridesCopy()
        for (var i = 0; i < removals.length; ++i)
            delete next[removals[i]]
        for (var key in changes)
            next[key] = String(changes[key])
        root.emitStyle(next)
    }

    function applyStateMode(key) {
        var keys = [
            "controls.focus-color", "controls.focus-fill-alpha", "controls.focus-border-width",
            "controls.selected-color", "controls.selected-fill-alpha", "controls.selected-border-width"
        ]
        var changes = {}
        if (key === "focus") {
            changes["controls.focus-color"] = "accent"
            changes["controls.focus-fill-alpha"] = "0.18"
            changes["controls.focus-border-width"] = "2"
        } else if (key === "selection") {
            changes["controls.selected-color"] = "accent"
            changes["controls.selected-fill-alpha"] = "0.22"
            changes["controls.selected-border-width"] = "1"
        }
        root.mergeOverrides(changes, keys)
    }

    function applyDensityMode(key) {
        var keys = ["font.base-size", "spacing.scale", "spacing.control-height", "spacing.control-gap", "spacing.popup-row-height"]
        var changes = {}
        if (key === "comfortable") {
            changes["font.base-size"] = "13"
            changes["spacing.scale"] = "1.08"
            changes["spacing.control-height"] = "32"
            changes["spacing.control-gap"] = "9"
            changes["spacing.popup-row-height"] = "32"
        } else if (key === "compact") {
            changes["font.base-size"] = "11"
            changes["spacing.scale"] = "0.92"
            changes["spacing.control-height"] = "26"
            changes["spacing.control-gap"] = "6"
            changes["spacing.popup-row-height"] = "26"
        }
        root.mergeOverrides(changes, keys)
    }

    function recipeSummary(key) {
        if (key === "comfortable") return "font.base-size 13 · spacing.scale 1.08 · 32px controls · 32px popup rows"
        if (key === "compact") return "font.base-size 11 · spacing.scale 0.92 · 26px controls · 26px popup rows"
        if (key === "contrast") return "focus accent · 2px focus edge · stronger selection · accent feedback"
        if (key === "native") return "No additive overrides · active theme and user shell.toml stay authoritative"
        return "Custom tweaks · values below are the current staged reader tokens"
    }

    function optionDescription(key) {
        var descriptions = {
            "popups.background-alpha": "Opacity of shared popup cards and bar flyouts.",
            "popups.border-width": "Border width for popup surfaces; supports a scalar or side list.",
            "menu.scrim-alpha": "Dim layer behind menu, clipboard, and emoji surfaces.",
            "launcher.selected-background-alpha": "Selected launcher-row fill without changing launcher layout.",
            "controls.normal-fill-alpha": "Idle fill for buttons, tabs, dropdowns, and other shared controls.",
            "controls.focus-border-width": "Keyboard focus border width; keep this visible for accessibility.",
            "font.base-size": "Root shell type size. This is separate from monitor scale and GTK scaling.",
            "spacing.scale": "Proportional shell spacing multiplier. Individual tokens below can override it.",
            "spacing.control-height": "Height of shared shell controls, not application windows.",
            "tooltip.border-width": "Tooltip border width for the native PanelToolTip reader.",
            "notifications.countdown": "Notification countdown color; accepts a palette role or hex color.",
            "lock.background-alpha": "Opacity of the lock input surface; authentication behavior remains native.",
            "polkit.scrim-alpha": "Dim layer behind the native authentication prompt.",
            "image-picker.selected-border-alpha": "Selected carousel slice emphasis in the native image picker."
        }
        return descriptions[key] || "Native Quattro shell.toml value."
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
            root.rawMessage = "Use letters, numbers, hyphens, or underscores only."
            return
        }
        root.setOverride(section + "." + key, value)
        root.rawMessage = "Override staged: [" + section + "] " + key
        rawValueInput.text = ""
    }

    function clearRawOverride(key) {
        root.setOverride(key, "")
        root.rawMessage = "Override removed: " + key
    }

    function sectionFields(keys) {
        return keys
    }

    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        Text {
            Layout.fillWidth: true
            text: "SHELL / MAKE IT FEEL RIGHT"
            color: Color.foreground
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
        }
        Text {
            Layout.fillWidth: true
            text: "Start with a direction. Open the detailed controls only when you know what you want to tune."
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
                model: root.pages
                delegate: Button {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(42)
                    text: modelData.title
                    fontSize: Style.font.caption
                    foreground: root.activePage === index ? Color.background : Color.foreground
                    background: root.activePage === index ? Color.accent : Util.alpha(Color.foreground, 0.045)
                    accent: Color.accent
                    bordered: true
                    tooltipText: modelData.eyebrow
                    onClicked: root.activePage = index
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: root.activePage
            implicitHeight: root.activePage === 0 ? startPage.implicitHeight
                : root.activePage === 1 ? surfacesPage.implicitHeight
                : root.activePage === 2 ? controlsPage.implicitHeight
                : root.activePage === 3 ? scalePage.implicitHeight
                : root.activePage === 4 ? feedbackPage.implicitHeight
                : rawPage.implicitHeight

            Item {
                id: startPage
                implicitHeight: startColumn.implicitHeight
                ColumnLayout {
                    id: startColumn
                    width: parent.width
                    spacing: Style.space(7)

                    Text { Layout.fillWidth: true; text: "START HERE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: "You do not need to understand shell.toml to make the shell feel different. Pick a direction below, then use the other pages only for refinement."; color: Color.foreground; opacity: 0.68; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Style.space(6)
                        rowSpacing: Style.space(6)
                        Repeater {
                            model: root.recipes
                            delegate: DesktopOptionCard {
                                required property var modelData
                                Layout.fillWidth: true
                                compact: true
                                title: modelData.title
                                description: modelData.description
                                selected: modelData.key === "native" ? Object.keys(root.shellStyle.overrides || {}).length === 0 && root.shellStyle.surface === "flat" && root.shellStyle.detail === "native" : root.lastRecipe === modelData.key
                                onClicked: root.applyRecipe(modelData.key)
                            }
                        }
                    }

                    BorderSurface {
                        Layout.fillWidth: true
                        implicitHeight: summaryColumn.implicitHeight + Style.space(16)
                        color: Util.alpha(Color.foreground, 0.035)
                        radius: Math.max(Style.space(5), Style.cornerRadius / 2)
                        borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.62), 1)
                        ColumnLayout {
                            id: summaryColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            spacing: Style.space(3)
                            Text { Layout.fillWidth: true; text: Object.keys(root.shellStyle.overrides || {}).length === 0 ? "NATIVE DEFAULTS ACTIVE" : Object.keys(root.shellStyle.overrides || {}).length + " ADDITIVE TOKENS STAGED"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                            Text { Layout.fillWidth: true; text: "Nothing is permanent until Test Live / Apply. Clearing a field returns that value to Omarchy."; color: Color.foreground; opacity: 0.62; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                    }

                    Text { Layout.fillWidth: true; text: "CURRENT PRESET / TWEAK IT"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: root.recipeSummary(root.lastRecipe); color: Color.accent; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { Layout.fillWidth: true; text: "These are the few structural values that change the shell's feel most. Sliders stage real Quattro tokens. Palette colours stay owned by the Palette engine."; color: Color.foreground; opacity: 0.62; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Style.space(12)
                        rowSpacing: Style.space(8)
                        ShellRangeField {
                            Layout.fillWidth: true
                            label: "Density"
                            description: "Overall shell spacing multiplier."
                            value: root.overrideValue("spacing.scale")
                            fallback: 1.0
                            minimum: 0.82
                            maximum: 1.18
                            step: 0.01
                            decimals: 2
                            suffix: "×"
                            onValueEdited: function(value) { root.setOverride("spacing.scale", value) }
                            onResetRequested: root.setOverride("spacing.scale", "")
                        }
                        ShellRangeField {
                            Layout.fillWidth: true
                            label: "Text size"
                            description: "Shell base type size, not monitor scale."
                            value: root.overrideValue("font.base-size")
                            fallback: 12
                            minimum: 10
                            maximum: 16
                            step: 1
                            integer: true
                            suffix: "px"
                            onValueEdited: function(value) { root.setOverride("font.base-size", value) }
                            onResetRequested: root.setOverride("font.base-size", "")
                        }
                        ShellRangeField {
                            Layout.fillWidth: true
                            label: "Control height"
                            description: "Buttons, tabs, toggles, and shared rows."
                            value: root.overrideValue("spacing.control-height")
                            fallback: 28
                            minimum: 22
                            maximum: 38
                            step: 1
                            integer: true
                            suffix: "px"
                            onValueEdited: function(value) { root.setOverride("spacing.control-height", value) }
                            onResetRequested: root.setOverride("spacing.control-height", "")
                        }
                        ShellRangeField {
                            Layout.fillWidth: true
                            label: "Surface opacity"
                            description: "Popup card opacity; 1.0 is fully opaque."
                            value: root.overrideValue("popups.background-alpha")
                            fallback: 1.0
                            minimum: 0.55
                            maximum: 1.0
                            step: 0.01
                            decimals: 2
                            onValueEdited: function(value) { root.setOverride("popups.background-alpha", value) }
                            onResetRequested: root.setOverride("popups.background-alpha", "")
                        }
                    }

                    Text { Layout.fillWidth: true; text: "Colours follow the active theme palette here. Native shell colour tokens remain available in Advanced when you intentionally want to override shell.toml."; color: Color.foreground; opacity: 0.5; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }

                    Button { Layout.fillWidth: true; Layout.preferredHeight: Style.space(36); text: root.showAdvanced ? "Hide detailed controls" : "Show detailed controls"; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.toggleAdvanced() }
                    Text { Layout.fillWidth: true; text: "Tip: Surfaces changes how the shell looks. States changes how it responds. Scale changes density. Feedback changes attention and security surfaces."; color: Color.foreground; opacity: 0.5; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }

            Item {
                id: surfacesPage
                implicitHeight: surfacesColumn.implicitHeight
                ColumnLayout {
                    id: surfacesColumn
                    width: parent.width
                    spacing: Style.space(6)
                    Text { Layout.fillWidth: true; text: "SURFACE COMPOSITION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "These quick choices shape popup, menu, launcher, and control hierarchy without replacing Quattro's surfaces."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Button { Layout.fillWidth: true; Layout.preferredHeight: Style.space(34); text: root.showAdvanced ? "Hide surface tokens" : "Fine-tune surfaces"; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.toggleAdvanced() }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Style.space(5)
                        rowSpacing: Style.space(5)
                        Repeater { model: root.surfaceOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Surface · " + modelData.title; description: "Popup, menu, launcher, and control surface hierarchy."; selected: root.shellStyle.surface === modelData.key; onClicked: root.emitStyle(root.overridesCopy(), modelData.key) } }
                        Repeater { model: root.detailOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Detail · " + modelData.title; description: "Border language for controls, menus, and notifications."; selected: root.shellStyle.detail === modelData.key; onClicked: root.emitStyle(root.overridesCopy(), undefined, modelData.key) } }
                    }

                    Text { Layout.fillWidth: true; text: "POPUPS + MENU ROWS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(8); rowSpacing: Style.space(7)
                        Layout.preferredHeight: root.showAdvanced ? implicitHeight : 0
                        Layout.minimumHeight: 0
                        visible: root.showAdvanced
                        Repeater {
                            model: [
                                { key: "popups.background", label: "Popup background", placeholder: "#hex or palette role" },
                                { key: "popups.background-alpha", label: "Popup background alpha", placeholder: "0.0 – 1.0" },
                                { key: "popups.border", label: "Popup border", placeholder: "accent, foreground, or #hex" },
                                { key: "popups.border-width", label: "Popup border width", placeholder: "1 or 0 0 0 2" },
                                { key: "menu.scrim-alpha", label: "Menu scrim alpha", placeholder: "0.0 – 1.0" },
                                { key: "menu.selected-background-alpha", label: "Menu selection alpha", placeholder: "0.0 – 1.0" },
                                { key: "menu.selected-text", label: "Menu selected text", placeholder: "accent or #hex" },
                                { key: "menu.selected-border-width", label: "Menu selected edge", placeholder: "0 or 0 0 0 3" },
                                { key: "launcher.scrim-alpha", label: "Launcher scrim alpha", placeholder: "0.0 – 1.0" },
                                { key: "launcher.selected-background-alpha", label: "Launcher selection alpha", placeholder: "0.0 – 1.0" },
                                { key: "launcher.selected-text", label: "Launcher selected text", placeholder: "accent or #hex" },
                                { key: "launcher.selected-border-width", label: "Launcher selected edge", placeholder: "0 or 0 0 0 3" }
                            ]
                            delegate: ShellValueField {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                description: root.optionDescription(modelData.key)
                                value: root.overrideValue(modelData.key)
                                placeholder: modelData.placeholder
                                onValueEdited: function(value) { root.setOverride(modelData.key, value) }
                                onResetRequested: root.setOverride(modelData.key, "")
                            }
                        }
                    }
                }
            }

            Item {
                id: controlsPage
                implicitHeight: controlsColumn.implicitHeight
                ColumnLayout {
                    id: controlsColumn
                    width: parent.width
                    spacing: Style.space(6)
                    Text { Layout.fillWidth: true; text: "CONTROL STATE CHROME"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Tune the shared Button, Dropdown, Toggle, tab, slider, and focus-state readers. Keep focus and selected states distinguishable."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Button { Layout.fillWidth: true; Layout.preferredHeight: Style.space(34); text: root.showAdvanced ? "Hide state tokens" : "Fine-tune states"; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.toggleAdvanced() }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: Style.space(5)
                        rowSpacing: Style.space(5)
                        Repeater {
                            model: root.stateModes
                            delegate: DesktopOptionCard {
                                required property var modelData
                                Layout.fillWidth: true
                                compact: true
                                title: modelData.title
                                description: modelData.description
                                selected: modelData.key === "native" ? root.overrideValue("controls.focus-color") === "" && root.overrideValue("controls.selected-color") === "" : modelData.key === "focus" ? root.overrideValue("controls.focus-color") !== "" : root.overrideValue("controls.selected-color") !== ""
                                onClicked: root.applyStateMode(modelData.key)
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(8); rowSpacing: Style.space(7)
                        Layout.preferredHeight: root.showAdvanced ? implicitHeight : 0
                        Layout.minimumHeight: 0
                        visible: root.showAdvanced
                        Repeater {
                            model: [
                                { key: "controls.normal-color", label: "Normal color", placeholder: "foreground or #hex" },
                                { key: "controls.normal-fill-alpha", label: "Normal fill alpha", placeholder: "0.0 – 1.0" },
                                { key: "controls.hover-cursor-color", label: "Hover / cursor color", placeholder: "foreground or accent" },
                                { key: "controls.hover-cursor-fill-alpha", label: "Hover / cursor fill", placeholder: "0.0 – 1.0" },
                                { key: "controls.focus-color", label: "Focus color", placeholder: "accent or #hex" },
                                { key: "controls.focus-fill-alpha", label: "Focus fill alpha", placeholder: "0.0 – 1.0" },
                                { key: "controls.selected-color", label: "Selected color", placeholder: "accent or #hex" },
                                { key: "controls.selected-fill-alpha", label: "Selected fill alpha", placeholder: "0.0 – 1.0" },
                                { key: "controls.pressed-fill-alpha", label: "Pressed fill alpha", placeholder: "0.0 – 1.0" },
                                { key: "controls.selection-fill-alpha", label: "Text selection alpha", placeholder: "0.0 – 1.0" },
                                { key: "controls.normal-border-width", label: "Normal border width", placeholder: "0" },
                                { key: "controls.hover-cursor-border-width", label: "Hover border width", placeholder: "0" },
                                { key: "controls.focus-border-width", label: "Focus border width", placeholder: "1" },
                                { key: "controls.selected-border-width", label: "Selected border width", placeholder: "0 or 1" }
                            ]
                            delegate: ShellValueField {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                description: root.optionDescription(modelData.key)
                                value: root.overrideValue(modelData.key)
                                placeholder: modelData.placeholder
                                onValueEdited: function(value) { root.setOverride(modelData.key, value) }
                                onResetRequested: root.setOverride(modelData.key, "")
                            }
                        }
                    }
                }
            }

            Item {
                id: scalePage
                implicitHeight: scaleColumn.implicitHeight
                ColumnLayout {
                    id: scaleColumn
                    width: parent.width
                    spacing: Style.space(6)
                    Text { Layout.fillWidth: true; text: "TYPE + SPACING SCALE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "These are shell-wide structural tokens. They change Quickshell density and typography, not Hyprland monitor scale or application font configuration."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Button { Layout.fillWidth: true; Layout.preferredHeight: Style.space(34); text: root.showAdvanced ? "Hide scale tokens" : "Fine-tune type and spacing"; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.toggleAdvanced() }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: Style.space(5)
                        rowSpacing: Style.space(5)
                        Repeater {
                            model: root.densityModes
                            delegate: DesktopOptionCard {
                                required property var modelData
                                Layout.fillWidth: true
                                compact: true
                                title: modelData.title
                                description: modelData.description
                                selected: modelData.key === "native" ? root.overrideValue("spacing.scale") === "" : modelData.key === "comfortable" ? root.overrideValue("spacing.scale") === "1.08" : root.overrideValue("spacing.scale") === "0.92"
                                onClicked: root.applyDensityMode(modelData.key)
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(8); rowSpacing: Style.space(7)
                        Layout.preferredHeight: root.showAdvanced ? implicitHeight : 0
                        Layout.minimumHeight: 0
                        visible: root.showAdvanced
                        Repeater {
                            model: [
                                { key: "font.base-size", label: "Font base size", placeholder: "12" },
                                { key: "font.caption", label: "Caption size", placeholder: "10" },
                                { key: "font.body-small", label: "Body small size", placeholder: "11" },
                                { key: "font.body", label: "Body size", placeholder: "12" },
                                { key: "font.subtitle", label: "Subtitle size", placeholder: "13" },
                                { key: "font.title", label: "Title size", placeholder: "14" },
                                { key: "font.heading", label: "Heading size", placeholder: "16" },
                                { key: "font.display", label: "Display size", placeholder: "24" },
                                { key: "font.display-large", label: "Display large size", placeholder: "28" },
                                { key: "spacing.scale", label: "Spacing scale", placeholder: "1.0" },
                                { key: "spacing.scale-with-font", label: "Spacing follows font", placeholder: "true / false" },
                                { key: "spacing.control-height", label: "Control height", placeholder: "28" },
                                { key: "spacing.control-gap", label: "Control gap", placeholder: "8" },
                                { key: "spacing.control-padding-x", label: "Control horizontal padding", placeholder: "10" },
                                { key: "spacing.control-padding-y", label: "Control vertical padding", placeholder: "6" },
                                { key: "spacing.popup-row-height", label: "Popup row height", placeholder: "28" },
                                { key: "spacing.row-gap", label: "Row gap", placeholder: "8" },
                                { key: "spacing.panel-padding", label: "Panel padding", placeholder: "18" },
                                { key: "spacing.popup-padding", label: "Popup padding", placeholder: "14" }
                            ]
                            delegate: ShellValueField {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                description: root.optionDescription(modelData.key)
                                value: root.overrideValue(modelData.key)
                                placeholder: modelData.placeholder
                                onValueEdited: function(value) { root.setOverride(modelData.key, value) }
                                onResetRequested: root.setOverride(modelData.key, "")
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "Font family remains a machine preference; use `omarchy font set` so the native shell and applications keep the same fontconfig ownership."; color: Color.foreground; opacity: 0.54; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }

            Item {
                id: feedbackPage
                implicitHeight: feedbackColumn.implicitHeight
                ColumnLayout {
                    id: feedbackColumn
                    width: parent.width
                    spacing: Style.space(6)
                    Text { Layout.fillWidth: true; text: "FEEDBACK + SECURITY SURFACES"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Tooltip, notification, polkit, lock, and image-picker readers stay native. This page only changes their visual tokens and state emphasis."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Button { Layout.fillWidth: true; Layout.preferredHeight: Style.space(34); text: root.showAdvanced ? "Hide feedback tokens" : "Fine-tune feedback"; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.toggleAdvanced() }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Style.space(5)
                        Repeater { model: root.feedbackOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Tooltip · " + modelData.title; description: "Native tooltip border and surface treatment."; selected: root.shellStyle.tooltip === modelData.key; onClicked: root.emitStyle(root.overridesCopy(), undefined, undefined, modelData.key) } }
                        Repeater { model: root.feedbackOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Alerts · " + modelData.title; description: "Native notification border and countdown treatment."; selected: root.shellStyle.notifications === modelData.key; onClicked: root.emitStyle(root.overridesCopy(), undefined, undefined, undefined, modelData.key) } }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(8); rowSpacing: Style.space(7)
                        Layout.preferredHeight: root.showAdvanced ? implicitHeight : 0
                        Layout.minimumHeight: 0
                        visible: root.showAdvanced
                        Repeater {
                            model: [
                                { key: "tooltip.background-alpha", label: "Tooltip background alpha", placeholder: "0.0 – 1.0" },
                                { key: "tooltip.border-alpha", label: "Tooltip border alpha", placeholder: "0.0 – 1.0" },
                                { key: "tooltip.border-width", label: "Tooltip border width", placeholder: "1" },
                                { key: "notifications.background-alpha", label: "Notification background alpha", placeholder: "0.0 – 1.0" },
                                { key: "notifications.border-alpha", label: "Notification border alpha", placeholder: "1.0" },
                                { key: "notifications.border-width", label: "Notification border width", placeholder: "1" },
                                { key: "notifications.countdown", label: "Notification countdown", placeholder: "accent or #hex" },
                                { key: "polkit.background-alpha", label: "Polkit background alpha", placeholder: "1.0" },
                                { key: "polkit.scrim-alpha", label: "Polkit scrim alpha", placeholder: "0.5" },
                                { key: "polkit.border-alpha", label: "Polkit border alpha", placeholder: "1.0" },
                                { key: "lock.background-alpha", label: "Lock background alpha", placeholder: "0.8" },
                                { key: "lock.border-alpha", label: "Lock border alpha", placeholder: "1.0" },
                                { key: "lock.selection-alpha", label: "Lock selection alpha", placeholder: "0.45" },
                                { key: "image-picker.scrim-alpha", label: "Image picker scrim alpha", placeholder: "0.5" },
                                { key: "image-picker.selected-border-alpha", label: "Picker selected border alpha", placeholder: "1.0" },
                                { key: "image-picker.unselected-border-alpha", label: "Picker idle border alpha", placeholder: "0.28" }
                            ]
                            delegate: ShellValueField {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                description: root.optionDescription(modelData.key)
                                value: root.overrideValue(modelData.key)
                                placeholder: modelData.placeholder
                                onValueEdited: function(value) { root.setOverride(modelData.key, value) }
                                onResetRequested: root.setOverride(modelData.key, "")
                            }
                        }
                    }
                }
            }

            Item {
                id: rawPage
                implicitHeight: rawColumn.implicitHeight
                ColumnLayout {
                    id: rawColumn
                    width: parent.width
                    spacing: Style.space(6)
                    Text { Layout.fillWidth: true; text: "ADVANCED SHELL TOKENS"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "For values not promoted into a card yet, add a documented section.key directly. Omagen validates the section and key shape, then the native theme compiler merges it into shell.toml."; color: Color.foreground; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(5)
                        Rectangle {
                            Layout.preferredWidth: Style.space(120); Layout.preferredHeight: Style.space(34)
                            color: Util.alpha(Color.background, 0.38); radius: Math.max(Style.space(4), Style.cornerRadius / 2); border.width: 1; border.color: rawSectionInput.activeFocus ? Color.accent : Color.popups.border
                            TextInput { id: rawSectionInput; anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: TextInput.AlignVCenter }
                            Text { visible: rawSectionInput.text === "" && !rawSectionInput.activeFocus; anchors.fill: rawSectionInput; anchors.leftMargin: Style.space(8); color: Color.foreground; opacity: 0.42; text: "section"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.preferredWidth: Style.space(150); Layout.preferredHeight: Style.space(34)
                            color: Util.alpha(Color.background, 0.38); radius: Math.max(Style.space(4), Style.cornerRadius / 2); border.width: 1; border.color: rawKeyInput.activeFocus ? Color.accent : Color.popups.border
                            TextInput { id: rawKeyInput; anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: TextInput.AlignVCenter }
                            Text { visible: rawKeyInput.text === "" && !rawKeyInput.activeFocus; anchors.fill: rawKeyInput; anchors.leftMargin: Style.space(8); color: Color.foreground; opacity: 0.42; text: "key"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: Style.space(34)
                            color: Util.alpha(Color.background, 0.38); radius: Math.max(Style.space(4), Style.cornerRadius / 2); border.width: 1; border.color: rawValueInput.activeFocus ? Color.accent : Color.popups.border
                            TextInput { id: rawValueInput; anchors.fill: parent; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: TextInput.AlignVCenter }
                            Text { visible: rawValueInput.text === "" && !rawValueInput.activeFocus; anchors.fill: rawValueInput; anchors.leftMargin: Style.space(8); color: Color.foreground; opacity: 0.42; text: "value"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; verticalAlignment: Text.AlignVCenter }
                        }
                        Button { Layout.preferredWidth: Style.space(74); Layout.preferredHeight: Style.space(34); text: "Add"; foreground: Color.background; background: Color.accent; accent: Color.accent; bordered: true; onClicked: root.addRawOverride() }
                    }
                    Text { Layout.fillWidth: true; text: root.rawMessage; visible: root.rawMessage !== ""; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }

                    Text { Layout.fillWidth: true; text: "STAGED OVERRIDES"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Repeater {
                        model: Object.keys(root.shellStyle.overrides || {}).sort()
                        delegate: BorderSurface {
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: Style.space(36)
                            color: Util.alpha(Color.foreground, 0.035)
                            radius: Math.max(Style.space(4), Style.cornerRadius / 2)
                            borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.62), 1)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(8)
                                anchors.rightMargin: Style.space(5)
                                Text { Layout.fillWidth: true; text: modelData + " = " + root.overrideValue(modelData); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                                Button { Layout.preferredWidth: Style.space(52); Layout.preferredHeight: Style.space(26); text: "Clear"; fontSize: Style.font.caption; foreground: Color.foreground; background: Util.alpha(Color.foreground, 0.045); accent: Color.accent; bordered: true; onClicked: root.clearRawOverride(modelData) }
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; visible: Object.keys(root.shellStyle.overrides || {}).length === 0; text: "No additive overrides staged. The active theme and user shell.toml remain authoritative."; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }
        }
    }
}
