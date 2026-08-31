import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// Look & Feel is an orchestration surface above the four native engines. The
// backend supplies catalog entries and resolves recipes; this component only
// presents selection, reset affordances, and the supporting terminal adapter.
Item {
    id: root

    property var catalog: []
    property var lookFeel: ({ preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    property var recipe: null
    property var terminalTranslucency: ({ mode: "preserve", opacity: 1, cellMode: "background" })
    property real presetOpacity: 0.82
    property bool catalogLoading: false
    property string catalogError: ""
    // The canvas owns the staged palette.  Keep a host-theme fallback so this
    // component remains safe when it is rendered outside the Live Canvas.
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent
    property bool busy: false

    signal presetRequested(string preset)
    signal catalogRetryRequested()
    signal resetRequested(string scope)
    signal terminalChanged(var terminal)

    readonly property string selectedPreset: String(root.lookFeel.preset || "omarchy-native")
    readonly property var customized: root.lookFeel.customized || ({})
    readonly property bool isCustomized: Object.keys(root.customized).some(function(key) { return root.customized[key] === true })
    readonly property var terminalModeOptions: [
        { key: "preserve", title: "Preserve" },
        { key: "preset", title: "Preset" },
        { key: "custom", title: "Custom" }
    ]
    readonly property var cellModeOptions: [
        { key: "background", title: "Background" },
        { key: "painted", title: "Painted cells" }
    ]

    implicitHeight: body.implicitHeight

    function catalogName(id) {
        for (var index = 0; index < root.catalog.length; ++index) {
            if (root.catalog[index].id === id)
                return root.catalog[index].name
        }
        return id
    }

    function conciseDescription(value) {
        var description = String(value || "").trim()
        if (description === "")
            return "Native Omarchy defaults."
        var maximumCharacters = 72
        if (description.length <= maximumCharacters)
            return description
        var shortened = description.slice(0, maximumCharacters - 1)
        var lastSpace = shortened.lastIndexOf(" ")
        if (lastSpace > maximumCharacters / 2)
            shortened = shortened.slice(0, lastSpace)
        return shortened + "…"
    }

    function customCount() {
        var count = 0
        for (var key in root.customized) {
            if (root.customized[key] === true)
                count++
        }
        return count
    }

    function summaryText() {
        if (!root.isCustomized)
            return "Preset recipe · all four engines and terminal adapter follow the selected recipe"
        var parts = []
        var labels = { window: "Window", shell: "Shell", bar: "Bar", animations: "Animations", terminal: "Terminal" }
        for (var key in labels) {
            if (root.customized[key] === true)
                parts.push(labels[key] + ": 1 override")
        }
        return "Customized · " + parts.join(" · ")
    }

    function recipeRows() {
        var recipe = root.recipe || ({})
        var window = recipe.window || ({})
        var shell = recipe.shell || ({})
        var bar = recipe.bar || ({})
        var spec = bar.spec || ({})
		var surface = spec.surface || ({})
		var workspacePresentation = spec.workspace || ({})
		var dockPresentation = spec.dock || ({})
        var motion = recipe.animations || ({})
		var screenEffect = motion.screen_effect || motion.screenEffect || null
		var effectName = screenEffect ? String(screenEffect.id || "none") : (motion.glitch && motion.glitch !== "none" ? "rgb-tear" : "none")
		var effectStrength = screenEffect ? String(screenEffect.strength || "medium") : String(motion.glitch === "flicker" ? "medium" : motion.glitch || "medium")
		var effectDuration = screenEffect ? Number(screenEffect.duration_ms !== undefined ? screenEffect.duration_ms : screenEffect.durationMs || 0) : (effectName === "rgb-tear" ? 1250 : effectName === "retro-vhs" ? 1100 : 0)
        var terminal = recipe.terminal || root.terminalTranslucency || ({})
        var shellPreset = String(shell.preset || "default")
        var shellMeaning = shellPreset === "glass"
            ? "72% main surfaces · 88% tooltip/security · 86% notifications · 82% lock · scoped shell backdrop blur"
            : "Theme-native alpha · no shell-specific compositor blur rule"
        return [
            "Shell · " + (shellPreset === "glass" ? "Glass" : "Default") + " / " + (shell.surface || "flat") + " / " + (shell.detail || "native") + " · " + (shell.tooltip || "native") + " tooltips · " + (shell.notifications || "native") + " notifications",
            "Shell material · " + shellMeaning,
            "Window · " + (window.shape || "native") + " shape · " + (window.spacing || "native") + " spacing · " + (window.depth || "native") + " depth · " + (window.active_style || window.activeStyle || "native") + " focused / " + (window.inactive_style || window.inactiveStyle || "native") + " inactive",
			"Bar · " + (spec.preset || bar.form || "native") + " / " + (spec.topology || "native") + " · " + (surface.treatment || "native") + " surface" + (surface.opacity !== undefined ? " · " + Math.round(Number(surface.opacity) * 100) + "%" : "") + (surface.blur ? " · " + surface.blur + " blur" : "") + " · workspaces " + (workspacePresentation.mode || "native") + (workspacePresentation.glyphs && workspacePresentation.glyphs.length ? " [" + workspacePresentation.glyphs.join(" · ") + "]" : "") + (spec.topology === "dock" ? " · closed " + (dockPresentation.closed || "ellipsis") : ""),
			"Motion · " + (motion.preset || "native") + " · windows " + (motion.window || "native") + " · " + Number(motion.windowOpacity !== undefined ? motion.windowOpacity : motion.window_opacity !== undefined ? motion.window_opacity : 100) + "% entrance opacity · workspaces " + (motion.workspace || "native") + " · " + (motion.windowMove || motion.window_move || "native") + " movement" + (effectName !== "none" ? " · " + effectName + " " + effectStrength + " · " + effectDuration + " ms finite screen signal" : ""),
            "Terminal · " + (terminal.mode || "preserve") + " · " + (terminal.opacity !== undefined ? Number(terminal.opacity).toFixed(2) : "1.00") + " opacity · " + (terminal.cell_mode || terminal.cellMode || "background") + " cells"
        ]
    }

    function terminalCopy() {
        var current = root.terminalTranslucency || ({})
        return {
            schemaVersion: Number(current.schemaVersion !== undefined ? current.schemaVersion : current.schema_version || 1),
            mode: String(current.mode || "preserve"),
            opacity: Number(current.opacity !== undefined ? current.opacity : 1),
            cellMode: String(current.cellMode || current.cell_mode || "background")
        }
    }

    function setTerminalMode(mode) {
        var next = root.terminalCopy()
        next.mode = mode
        if (mode === "preserve") {
            next.opacity = 1
            next.cellMode = "background"
        } else if (mode === "preset") {
            // Preset is a deliberate return to the recipe value. Do not carry
            // a previous custom slider value into preset mode.
            next.opacity = Math.max(0.5, Math.min(1, Number(root.presetOpacity)))
        }
        root.terminalChanged(next)
    }

    function setCellMode(mode) {
        var next = root.terminalCopy()
        next.cellMode = mode
        if (next.mode === "preserve")
            next.mode = "custom"
        root.terminalChanged(next)
    }

    function setCustomOpacity(value) {
        var next = root.terminalCopy()
        next.mode = "custom"
        next.opacity = Math.max(0.5, Math.min(1, Number(value)))
        root.terminalChanged(next)
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        Text {
            Layout.fillWidth: true
            text: "LOOK & FEEL PRESETS"
            color: root.accentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
        }

        Text {
            Layout.fillWidth: true
            text: "Choose a complete recipe, then customize Window, Shell, Bar, or Animations independently."
            color: root.foregroundColor
            opacity: 0.62
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(5)
            rowSpacing: Style.space(5)

            Repeater {
                model: root.catalog
                delegate: Button {
                    required property var modelData
                    readonly property color cardTextColor: root.selectedPreset === modelData.id
                        ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        : root.foregroundColor
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(82)
                    text: ""
                    fontSize: Style.font.caption
                    foreground: cardTextColor
                    background: root.selectedPreset === modelData.id
                        ? root.accentColor : Util.alpha(root.foregroundColor, 0.035)
                    accent: root.accentColor
                    // The selected fill is staged palette-owned; do not let
                    // the native Style.selectedColor token override its text.
                    selected: false
                    bordered: true
                    focusable: true
                    tooltipText: modelData.description || ""
                    // Preset selection is latest-intent input. Keep cards
                    // clickable while a resolver or native preview is busy;
                    // LookFeelController and PreviewController retain only
                    // the newest complete request.
                    enabled: true
                    onClicked: root.presetRequested(modelData.id)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: cardTextColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: (modelData.local ? "Local preset · " : "Revision " + modelData.revision + " · ") + root.conciseDescription(modelData.description)
                            color: cardTextColor
                            opacity: root.selectedPreset === modelData.id ? 0.86 : 0.68
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.catalogError !== ""
                ? "Preset catalog unavailable: " + root.catalogError
                : root.catalogLoading || root.catalog.length === 0
                    ? "Loading preset catalog…"
                    : root.catalogName(root.selectedPreset) + " · " + (root.isCustomized ? "Customized" : "Preset")
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
        }

        Button {
            Layout.fillWidth: true
            visible: root.catalogError !== ""
            text: "Retry preset catalog"
            foreground: root.foregroundColor
            accent: root.accentColor
            background: Util.alpha(root.foregroundColor, 0.045)
            bordered: true
            enabled: !root.busy
            onClicked: root.catalogRetryRequested()
        }

        Text {
            Layout.fillWidth: true
            text: root.summaryText()
            color: root.foregroundColor
            opacity: 0.56
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }

        BorderSurface {
            Layout.fillWidth: true
            visible: root.recipe !== null
            implicitHeight: recipeColumn.implicitHeight + Style.space(18)
            color: Util.alpha(root.foregroundColor, 0.028)
            radius: Math.max(Style.space(6), Style.cornerRadius / 2)
            borderSpec: Border.flat(Util.alpha(root.accentColor, 0.28), 1)

            ColumnLayout {
                id: recipeColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(9)
                spacing: Style.space(4)

                Text {
                    Layout.fillWidth: true
                    text: "RESOLVED RECIPE · WHAT TEST LIVE WILL STAGE"
                    color: root.accentColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0.7
                }

                Repeater {
                    model: root.recipeRows()
                    delegate: Text {
                        required property string modelData
                        Layout.fillWidth: true
                        text: "• " + modelData
                        color: root.foregroundColor
                        opacity: 0.68
                        wrapMode: Text.WordWrap
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)
            Repeater {
                model: [
                    { key: "all", title: "Reset all" },
                    { key: "window", title: "Reset Window" },
                    { key: "shell", title: "Reset Shell" },
                    { key: "bar", title: "Reset Bar" },
                    { key: "animations", title: "Reset Motion" }
                ]
                delegate: Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(30)
                    text: modelData.title
                    fontSize: Style.font.caption
                    foreground: root.foregroundColor
                    background: Util.alpha(root.foregroundColor, 0.035)
                    accent: root.accentColor
                    bordered: true
                    enabled: !root.busy && (modelData.key === "all" ? root.isCustomized : root.customized[modelData.key] === true)
                    onClicked: root.resetRequested(modelData.key)
                }
            }
        }

        BorderSurface {
            Layout.fillWidth: true
            implicitHeight: terminalColumn.implicitHeight + Style.space(20)
            color: Util.alpha(root.foregroundColor, 0.035)
            radius: Math.max(Style.space(6), Style.cornerRadius / 2)
            borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.72), 1)

            ColumnLayout {
                id: terminalColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                Text {
                    Layout.fillWidth: true
                    text: "TERMINAL TRANSLUCENCY"
                    color: root.foregroundColor
                    opacity: 0.76
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0.7
                }

                Text {
                    Layout.fillWidth: true
                    text: String(root.terminalTranslucency.mode || "preserve") === "preserve"
                        ? "Preserve leaves each terminal's own opacity in control. Choose Preset or Custom, then Test Live or Apply to stage a shared value."
                        : "Opacity is staged for Ghostty, Alacritty, Kitty, and Foot. New windows read it after the terminal reload; an explicit value in your main terminal config still wins."
                    color: root.foregroundColor
                    opacity: 0.56
                    wrapMode: Text.WordWrap
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                BarChoiceGroup {
                    Layout.fillWidth: true
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    title: "Mode"
                    subtitle: "Preserve, use the selected recipe, or choose a bounded value"
                    options: root.terminalModeOptions
                    selectedKey: String(root.terminalTranslucency.mode || "preserve")
                    columns: 3
                    onChoiceSelected: root.setTerminalMode(key)
                }

                ShellRangeField {
                    Layout.fillWidth: true
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    visible: String(root.terminalTranslucency.mode || "preserve") === "custom"
                    label: "Custom opacity"
                    description: "0.50–1.00. Values below 0.75 may reduce readability."
                    value: String(root.terminalTranslucency.opacity !== undefined ? root.terminalTranslucency.opacity : 1)
                    fallback: 0.82
                    minimum: 0.5
                    maximum: 1
                    step: 0.01
                    decimals: 2
                    suffix: ""
                    modified: true
                    resetText: "Preset"
                    onValueEdited: root.setCustomOpacity(value)
                    onResetRequested: root.setTerminalMode("preset")
                }

                Text {
                    Layout.fillWidth: true
                    visible: String(root.terminalTranslucency.mode || "preserve") === "preset"
                    text: "Selected recipe value: " + Number(root.terminalTranslucency.opacity || 0.82).toFixed(2) + " opacity"
                    color: root.accentColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                BarChoiceGroup {
                    Layout.fillWidth: true
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    title: "Cell mode"
                    subtitle: "Painted cells are unavailable in Kitty's portable contract"
                    options: root.cellModeOptions
                    selectedKey: String(root.terminalTranslucency.cellMode || root.terminalTranslucency.cell_mode || "background")
                    columns: 2
                    onChoiceSelected: root.setCellMode(key)
                }
            }
        }
    }
}
