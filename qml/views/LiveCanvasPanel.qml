import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components
import "../components/Contrast.js" as Contrast
import "live-canvas" as Wizard

PanelWindow {
    id: root

    // Durable session, preview, Demo, Apply, and rollback state remain owned
    // by Omagen.qml and its controllers. This surface only renders pages and
    // emits intent.
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
    property var lookFeel: ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    property var lookFeelRecipe: null
    property var lookFeelCatalog: []
    property bool lookFeelBusy: false
    property bool lookFeelPresetBusy: false
    property bool lookFeelCatalogLoading: false
    property string lookFeelCatalogError: ""
    property var terminalTranslucency: ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" })
    property real terminalPresetOpacity: 0.82
    property bool glitchEnabled: false
    property int glitchEpoch: 0
    property string errorMessage: ""
    property string selectedVariant: "source"
    property string monitorName: ""
    property string sourceImage: ""
    property bool workflowStep: false
    property string workflowMode: "fast"
    property bool workflowSelected: false
    property int workflowCursorIndex: -1
    property string suggestedThemeName: "omagen-theme"
    property string sourceThemeName: ""
    property var variants: []
    property var palettes: ({})
    property var stagedColors: ({})
    property var colorOverridesByVariant: ({})
    property bool colorPreviewLive: false

    // Agent 1 wizard contract. Omagen.qml should bind these to the wizard
    // controller aliases. Defaults keep this view lintable in isolation while
    // that root seam is integrated.
    property int wizardStep: 0
    property int wizardStepCount: 5
    property bool wizardCanGoBack: false
    property bool wizardCanGoNext: false
    property string wizardNextLabel: "Next"
    property string wizardAdvancedChoice: "undecided"
    property bool wizardLookFeelDecided: false
    property bool wizardOperationBusy: false
    property bool wizardPaletteSelected: false
    // Agent 1 may bind this to the begin-session transition. The fallback
    // preserves safe standalone rendering until that contract is connected.
    property bool wizardCanContinueWorkflow: root.workflowSelected && !root.operationBusy

    readonly property bool operationBusy: root.generationBusy || root.previewBusy || root.demoBusy || root.cancelBusy || root.applyBusy || root.lookFeelBusy || root.lookFeelPresetBusy || root.wizardOperationBusy
    readonly property color foregroundColor: Color.foreground
    readonly property color backgroundColor: Color.background
    readonly property color accentColor: Color.accent
    readonly property var stepLabels: root.workflowStep
        ? ["Workflow", "Palette", "Look & Feel", "Advanced", "Demo", "Finish"]
        : ["Palette", "Look & Feel", "Advanced", "Demo", "Finish"]
    readonly property string operationText: root.generationBusy
        ? "Preparing palette directions…"
        : root.previewBusy
            ? "Previewing the latest choice on the real desktop…"
            : root.lookFeelBusy
                ? "Resolving the selected Look & Feel…"
                : root.lookFeelPresetBusy
                    ? "Saving the Look & Feel preset…"
                    : root.demoBusy
                        ? (root.demoActive ? "Stopping the session-owned Demo…" : "Opening the session-owned Demo…")
                        : root.cancelBusy
                            ? "Restoring the original desktop and closing this session…"
                            : root.applyBusy
                                ? "Saving the selected theme…"
                                : ""

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
    signal testLiveRequested()
    signal lookFeelPresetRequested(string preset)
    signal saveLookFeelPresetRequested(string name)
    signal lookFeelCatalogRetryRequested()
    signal lookFeelResetRequested(string scope)
    signal terminalIntentChanged(var terminal)
    signal applyRequested(string variant, string name, bool generateUnlock, bool capturePreview, bool replaceSource, bool saveLookFeelPreset, string lookFeelPresetName)

    // Wizard signals are intent-only. The panel does not own navigation,
    // session cleanup, preview requests, or backend commands.
    signal goBackRequested()
    signal goNextRequested()
    signal advancedChoiceRequested(string choice)
    signal lookFeelSelectedRequested()
    signal lookFeelSkippedRequested()
    signal demoSkippedRequested()
    signal restoreAndCloseRequested()
    signal workflowModeSelected(string mode)
    signal workflowContinueRequested()

    function openLookFeelPresetDialog(name) {
        root.errorMessage = ""
        lookFeelPresetDialog.openForPreset(name)
    }

    function closeLookFeelPresetDialog() {
        lookFeelPresetDialog.close()
    }

    visible: root.active
    screen: root.resolveScreen()
    color: "transparent"
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.hideRequested()
    }
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagen-live-canvas"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; right: true }
    margins { top: Style.bar.sizeHorizontal + Style.space(12) }
    implicitWidth: Math.min(Style.space(620), Math.max(Style.space(420), (root.screen ? root.screen.width : Style.space(900)) - Style.space(48)))
    implicitHeight: Math.min(Style.space(820), Math.max(Style.space(520), (root.screen ? root.screen.height : Style.space(760)) - Style.bar.sizeHorizontal - Style.space(24)))

    function resolveScreen() {
        const screens = Quickshell.screens || []
        for (let index = 0; index < screens.length; index++) {
            if (screens[index].name === root.monitorName)
                return screens[index]
        }
        return null
    }

    function selectedVariantLabel() {
        for (let index = 0; index < root.variants.length; index++) {
            if (root.variants[index].variant === root.selectedVariant)
                return root.variants[index].label || root.selectedVariant
        }
        return root.selectedVariant
    }

    function selectedPresetLabel() {
        const selected = String(root.lookFeel.preset || "omarchy-native")
        const customized = root.lookFeel.customized || ({})
        const isCustomized = Object.keys(customized).some(function(key) { return customized[key] === true })
        let base = selected === "omarchy-native" ? "Keep native" : selected
        for (let index = 0; index < root.lookFeelCatalog.length; index++) {
            if (root.lookFeelCatalog[index].id === selected)
                base = root.lookFeelCatalog[index].name || selected
        }
        return isCustomized ? "Custom (based on " + base + ")" : base
    }

    function copyOverrideColors(value) {
        const result = {}
        for (const key in (value || {}))
            result[key] = String(value[key])
        return result
    }

    function overridesForVariant(variant) {
        return root.copyOverrideColors(root.colorOverridesByVariant[variant] || ({}))
    }

    function storeOverridesForVariant(variant, overrides) {
        const next = {}
        for (const key in root.colorOverridesByVariant)
            next[key] = root.colorOverridesByVariant[key]
        const copied = root.copyOverrideColors(overrides)
        if (Object.keys(copied).length > 0)
            next[variant] = copied
        else
            delete next[variant]
        root.colorOverridesByVariant = next
    }

    function setStagedColors(overrides, variant) {
        const target = variant || root.selectedVariant
        const copied = root.copyOverrideColors(overrides)
        root.storeOverridesForVariant(target, copied)
        if (target === root.selectedVariant)
            root.stagedColors = copied
        root.colorPreviewLive = false
    }

    function previewPaletteColors(overrides) {
        const target = root.selectedVariant
        root.setStagedColors(overrides || ({}), target)
        root.colorTestLiveRequested(
            target,
            root.overridesForVariant(target),
            root.shellStyleForVariant(target),
            root.desktopStyle,
            root.barStyleForVariant(target),
            root.animationsStyle
        )
    }

    function markColorsLive() {
        root.colorPreviewLive = Object.keys(root.stagedColors).length > 0
    }

    function copyShellStyle(value) {
        value = value || ({})
        const overrides = {}
        for (const key in (value.overrides || {}))
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
        const customized = root.lookFeel.customized || ({})
        const inherited = root.lookFeelRecipe && root.lookFeelRecipe.shell && customized.shell !== true
            ? root.lookFeelRecipe.shell : root.shellStyle
        return root.copyShellStyle(inherited)
    }

    function barStyleForVariant(_variant) { return root.barStyle }
    function resetApplyDialog() {
        themeNameDialog.reset()
        lookFeelPresetDialog.reset()
    }

    function openApplyDialog() {
        root.errorMessage = ""
        themeNameDialog.openWith(root.suggestedThemeName)
    }
    function clearColorSession() {
        root.stagedColors = ({})
        root.colorOverridesByVariant = ({})
        root.colorPreviewLive = false
    }
    function showPaletteDirections() {}

    Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.popups.background, 0.96)
        border.width: keyCatcher.activeFocus ? Math.max(1, Style.space(2)) : 1
        border.color: keyCatcher.activeFocus ? root.accentColor : Color.popups.border

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
            enabled: true
            onCloseRequested: root.hideRequested()
            onMoveRequested: function(dx, dy) {
                if (dy !== 0)
                    scrollArea.scrollBy(dy > 0 ? Style.space(36) : -Style.space(36))
            }

            // PanelKeyCatcher owns focus so Escape and the arrow keys work
            // even when no editor control is focused. Forward page travel
            // here as well; otherwise PageUp/PageDown never reaches the
            // Flickable below and the lower Advanced controls appear absent.
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_PageDown) {
                    scrollArea.scrollBy(scrollArea.height * 0.85)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    scrollArea.scrollBy(-scrollArea.height * 0.85)
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    scrollArea.scrollBy(-scrollArea.contentHeight)
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    scrollArea.scrollBy(scrollArea.contentHeight)
                    event.accepted = true
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(18)
            spacing: Style.space(12)
            z: 1

            Wizard.WizardChrome {
                id: chrome
                Layout.fillWidth: true
                step: root.workflowStep
                    ? 0
                    : Math.max(0, Math.min(root.wizardStep, root.stepLabels.length - 1))
                stepCount: root.workflowStep ? root.stepLabels.length : root.wizardStepCount
                steps: root.stepLabels
                busy: root.operationBusy
                operationText: root.operationText
                errorText: root.errorMessage
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                subtitle: root.generationBusy
                    ? "Generating directions from the selected image…"
                    : root.workflowStep
                        ? "Choose the level of control before palette generation begins."
                        : "A reversible desktop preview, one clear decision at a time · " + (root.monitorName || "focused monitor")
                onHideRequested: root.hideRequested()
            }

            Flickable {
                id: scrollArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageColumn.implicitHeight + Style.space(4)
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                focus: true
                activeFocusOnTab: true

                function scrollBy(delta) {
                    cancelFlick()
                    const maximum = Math.max(0, contentHeight - height)
                    contentY = Math.max(0, Math.min(maximum, contentY + delta))
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_PageDown) {
                        scrollBy(height * 0.85)
                        event.accepted = true
                    } else if (event.key === Qt.Key_PageUp) {
                        scrollBy(-height * 0.85)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        scrollBy(Style.space(36))
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        scrollBy(-Style.space(36))
                        event.accepted = true
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                WheelHandler {
                    onWheel: function(event) {
                        if (!scrollArea.interactive || event.angleDelta.y === 0)
                            return
                        scrollArea.scrollBy(-event.angleDelta.y / 2)
                        event.accepted = true
                    }
                }

                ColumnLayout {
                    id: pageColumn
                    x: Style.space(1)
                    y: Style.space(2)
                    width: scrollArea.width - Style.space(2)
                    // Flickable does not size its content item from implicit
                    // size. Keep the layout's actual height in sync so the
                    // Advanced editor exposes its complete Window/Shell/Bar/
                    // Animations content instead of reporting only the
                    // visible viewport height.
                    height: implicitHeight
                    spacing: Style.space(10)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? workflowStepPage.implicitHeight : 0
                        visible: root.workflowStep

                        Wizard.WorkflowStep {
                            id: workflowStepPage
                            width: parent.width
                            sourceImage: root.sourceImage
                            workflowMode: root.workflowMode
                            workflowSelected: root.workflowSelected
                            cursorIndex: root.workflowCursorIndex
                            busy: root.operationBusy
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onWorkflowModeSelected: root.workflowModeSelected(mode)
                        }
                    }

                    Item {
                        id: paletteStepPage
                        Layout.fillWidth: true
                        implicitHeight: visible ? paletteStep.implicitHeight : 0
                        Layout.preferredHeight: visible ? paletteStep.implicitHeight : 0
                        visible: !root.workflowStep && root.wizardStep === 0

                        Wizard.PaletteStep {
                            id: paletteStep
                            width: parent.width
                            variants: root.variants
                            palettes: root.palettes
                            selectedVariant: root.selectedVariant
                            paletteSelected: root.wizardPaletteSelected || root.workspaceReady && root.selectedVariant !== ""
                            previewBusy: root.previewBusy
                            generationBusy: root.generationBusy
                            controlsEnabled: !root.operationBusy
                            stagedColors: root.stagedColors
                            colorPreviewLive: root.colorPreviewLive
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onVariantRequested: root.variantRequested(variant)
                            onColorOverridesCommitted: root.previewPaletteColors(overrides)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? lookFeelStep.implicitHeight : 0
                        visible: !root.workflowStep && root.wizardStep === 1

                        Wizard.LookFeelStep {
                            id: lookFeelStep
                            width: parent.width
                            catalog: root.lookFeelCatalog
                            lookFeel: root.lookFeel
                            recipe: root.lookFeelRecipe
                            decided: root.wizardLookFeelDecided
                            catalogLoading: root.lookFeelCatalogLoading
                            catalogError: root.lookFeelCatalogError
                            busy: root.lookFeelBusy
                            previewBusy: root.previewBusy
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onPresetRequested: function(preset) {
                                root.lookFeelPresetRequested(preset)
                                root.lookFeelSelectedRequested()
                            }
                            onSkipRequested: {
                                root.lookFeelSkippedRequested()
                                root.lookFeelPresetRequested("omarchy-native")
                            }
                            onCatalogRetryRequested: root.lookFeelCatalogRetryRequested()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? advancedStep.implicitHeight : 0
                        visible: !root.workflowStep && root.wizardStep === 2

                        Wizard.AdvancedStep {
                            id: advancedStep
                            width: parent.width
                            choice: root.wizardAdvancedChoice
                            controlsEnabled: !root.operationBusy
                            shellStyle: root.shellStyleForVariant(root.selectedVariant)
                            desktopStyle: root.desktopStyle
                            barStyle: root.barStyleForVariant(root.selectedVariant)
                            animationsStyle: root.animationsStyle
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onChoiceRequested: root.advancedChoiceRequested(choice)
                            onStylesChanged: function(nextShell, nextDesktop, nextBar, nextAnimations) {
                                root.advancedStylesChanged(nextShell, nextDesktop, nextBar, nextAnimations)
                            }
                            onTestLiveRequested: root.testLiveRequested()
                            onSectionChanged: scrollArea.contentY = 0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? demoStep.implicitHeight : 0
                        visible: !root.workflowStep && root.wizardStep === 3

                        Wizard.DemoStep {
                            id: demoStep
                            width: parent.width
                            demoActive: root.demoActive
                            demoBusy: root.demoBusy
                            demoMode: root.demoMode
                            monitorName: root.monitorName
                            errorMessage: root.errorMessage
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onStartRequested: root.startDemoRequested()
                            onStopRequested: root.closeCanvasRequested()
                            onSkipRequested: root.demoSkippedRequested()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? finishStep.implicitHeight : 0
                        visible: !root.workflowStep && root.wizardStep === 4

                        Wizard.FinishStep {
                            id: finishStep
                            width: parent.width
                            selectedVariant: root.selectedVariant
                            selectedVariantLabel: root.selectedVariantLabel()
                            selectedPreset: root.selectedPresetLabel()
                            advancedChoice: root.wizardAdvancedChoice
                            demoActive: root.demoActive
                            previewBusy: root.previewBusy
                            applyBusy: root.applyBusy
                            cancelBusy: root.cancelBusy
                            lookFeelBusy: root.lookFeelBusy
                            lookFeelPresetBusy: root.lookFeelPresetBusy
                            foregroundColor: root.foregroundColor
                            backgroundColor: root.backgroundColor
                            accentColor: root.accentColor
                            onApplyRequested: {
                                root.openApplyDialog()
                            }
                            onSavePresetRequested: root.openLookFeelPresetDialog(root.suggestedThemeName)
                            onRestoreAndCloseRequested: root.restoreAndCloseRequested()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(58)
                color: Util.alpha(Color.popups.background, 0.98)
                border.width: 1
                border.color: Color.popups.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(8)

                    Button {
                        Layout.preferredWidth: Style.space(106)
                        Layout.preferredHeight: Style.space(38)
                        text: "Back"
                        foreground: root.foregroundColor
                        accent: root.accentColor
                        background: Util.alpha(root.foregroundColor, 0.045)
                        bordered: true
                        enabled: root.wizardCanGoBack && !root.operationBusy
                        onClicked: root.goBackRequested()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.operationText !== ""
                            ? root.operationText
                            : root.workflowStep
                                ? "Workflow · choose Fast or In-depth"
                                : "Step " + (root.wizardStep + 1) + " of " + root.wizardStepCount
                        color: root.foregroundColor
                        opacity: 0.55
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Button {
                        Layout.preferredWidth: Style.space(170)
                        Layout.preferredHeight: Style.space(38)
                        visible: root.workflowStep || root.wizardStep < root.stepLabels.length - 1
                        text: root.workflowStep ? "Continue to Palette  →" : root.wizardNextLabel
                        foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        accent: root.accentColor
                        background: root.accentColor
                        bordered: true
                        enabled: root.workflowStep
                            ? root.wizardCanContinueWorkflow && !root.operationBusy
                            : root.wizardCanGoNext && !root.operationBusy
                        onClicked: root.workflowStep
                            ? root.workflowContinueRequested()
                            : root.goNextRequested()
                    }
                }
            }
        }
    }

    Components.ThemeNameDialog {
        id: themeNameDialog
        anchors.fill: parent
        busy: root.applyBusy
        errorMessage: root.errorMessage
        themeEditMode: root.sourceThemeName !== ""
        sourceThemeName: root.sourceThemeName
        onConfirmed: function(name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName) {
            root.applyRequested(root.selectedVariant, name, generateUnlock, capturePreview, replaceSource, saveLookFeelPreset, lookFeelPresetName)
        }
    }

    Components.ThemeNameDialog {
        id: lookFeelPresetDialog
        anchors.fill: parent
        busy: root.lookFeelPresetBusy
        errorMessage: root.errorMessage
        onPresetConfirmed: root.saveLookFeelPresetRequested(name)
    }

    onActiveChanged: if (active)
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })

    onSelectedVariantChanged: {
        root.stagedColors = root.overridesForVariant(root.selectedVariant)
        root.colorPreviewLive = false
    }
}
