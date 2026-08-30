import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components" as Components
import "AnimationStyle.js" as AnimationStyle

// Motion/Hyprland editor. All edits remain staged until the parent forwards
// styleEdited to the shared Live Canvas preview transaction.
Item {
    id: root

    property var animationsStyle: ({})
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent
    property string windowBorderStyle: "solid"
    readonly property bool borderMotionAvailable: ["spin", "neon"].indexOf(root.windowBorderStyle) >= 0
    // Axis and travel only affect Hyprland's spatial workspace styles. Native
    // and Fade deliberately do not consume them, so make that dependency
    // visible instead of presenting controls that appear editable but cannot
    // change the generated theme.
    readonly property bool workspaceSlideControlsAvailable: ["slide", "slidefade", "spring"].indexOf(String(root.animationsStyle.workspace || "")) >= 0
    signal styleEdited(var animationsStyle)

    readonly property var motionPresetOptions: [
        { key: "native", title: "Native", description: "Keep the current Quattro motion baseline." },
        { key: "snappy", title: "Precision", description: "Near-full-size window entrances, immediate focus, and fade-led workspace changes." },
        { key: "smooth", title: "Floating Flow", description: "Deeper soft window entrances, gliding workspaces, and a long glass-like settle." },
        { key: "spring", title: "Spring", description: "Spring curves for window movement and settling." },
        { key: "cinematic", title: "Cinematic", description: "Slower entrances with fade-led layer motion." },
        { key: "minimal", title: "Minimal", description: "Fade-led motion with no bounce or travel." },
        { key: "cyberpunk", title: "Cyberpunk Glitch", description: "Digital window deformation, mechanical focus, spatial workspace cuts, and a 1250 ms event-driven RGB tear." }
    ]
    readonly property var workspaceAnimationOptions: [
        { key: "native", title: "Native" }, { key: "fade", title: "Fade" }, { key: "slide", title: "Slide" }, { key: "slidefade", title: "Slide + fade" }, { key: "none", title: "Off" }
    ]
    readonly property var borderAnimationOptions: [
        { key: "native", title: "Native" }, { key: "static", title: "Static" }, { key: "spin", title: "Spin" }
    ]

    implicitHeight: animationColumn.implicitHeight

    function effectiveScreenEffect() {
        return AnimationStyle.effectiveScreenEffect(root.animationsStyle)
    }

    function chooseScreenEffect(id) {
        root.styleEdited(AnimationStyle.chooseScreenEffect(root.animationsStyle, id))
    }

    function chooseEffectStrength(strength) {
        root.styleEdited(AnimationStyle.chooseEffectStrength(root.animationsStyle, strength))
    }

    function editEffectDuration(value) {
        var next = AnimationStyle.editEffectDuration(root.animationsStyle, value)
        if (next !== null) root.styleEdited(next)
    }

    function toggleEffectTrigger(trigger) {
        var next = AnimationStyle.toggleEffectTrigger(root.animationsStyle, trigger)
        if (next !== null) root.styleEdited(next)
    }

    function chooseMotionPreset(name) {
        root.styleEdited(AnimationStyle.chooseMotionPreset(root.animationsStyle, name))
    }

    function chooseAnimations(group, key) {
        if (group === "border" && !root.borderMotionAvailable)
            return
        root.styleEdited(AnimationStyle.chooseAnimations(root.animationsStyle, group, key))
    }

    function editMotionNumber(group, value) {
        root.styleEdited(AnimationStyle.editMotionNumber(root.animationsStyle, group, value))
    }

    ColumnLayout {
        id: animationColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

        Text { Layout.fillWidth: true; text: "MOTION LAB"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
        Text { Layout.fillWidth: true; text: "A semantic compositor recipe. Owner: Hyprland. Fallback: Native. These controls stage a MotionSpec; Test Live still applies the real Hyprland theme transaction, and Demo remains an explicit separate action. Continuous loops and experimental effects are intentionally outside this first slice."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(3); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "MOTION STYLE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.motionPresetOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.description; selected: root.animationsStyle.preset === modelData.key; onClicked: root.chooseMotionPreset(modelData.key) } } }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; text: "Open and close have separate character: opening can be expressive while closing stays decisive."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "popin", title: "Open · Pop" }, { key: "slide", title: "Open · Slide" }, { key: "gnomed", title: "Open · Gnome" }, { key: "fade", title: "Open · Fade" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland window entrance style."; selected: root.animationsStyle.windowOpen === modelData.key; onClicked: root.chooseAnimations("windowOpen", modelData.key) } } }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "popin", title: "Close · Pop" }, { key: "slide", title: "Close · Slide" }, { key: "gnomed", title: "Close · Gnome" }, { key: "fade", title: "Close · Fade" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland window exit style."; selected: root.animationsStyle.windowClose === modelData.key; onClicked: root.chooseAnimations("windowClose", modelData.key) } } }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Move · Native" }, { key: "smooth", title: "Move · Smooth" }, { key: "quick", title: "Move · Precision" }, { key: "digital", title: "Move · Digital" }, { key: "spring", title: "Move · Spring" }, { key: "none", title: "Move · Off" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Tiled rearrangement, dragging, and resize response."; selected: root.animationsStyle.windowMove === modelData.key; onClicked: root.chooseAnimations("windowMove", modelData.key) } } }
        Components.ShellRangeField { Layout.fillWidth: true; label: "Window starting scale"; description: "Pop-in styles start at this percentage of the final size."; value: String(root.animationsStyle.windowAmount || 87); fallback: 87; minimum: 60; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowAmount", value); onResetRequested: root.editMotionNumber("windowAmount", fallback) }
        Components.ShellRangeField { Layout.fillWidth: true; label: "Window entrance opacity"; description: "Start only the opening window at this opacity, then release it to the user's normal opacity. Cyberpunk uses 82%."; value: String(root.animationsStyle.windowOpacity !== undefined ? root.animationsStyle.windowOpacity : 100); fallback: 100; minimum: 60; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowOpacity", value); onResetRequested: root.editMotionNumber("windowOpacity", fallback) }
        Components.ShellRangeField { Layout.fillWidth: true; label: "Window response"; description: "Hyprland animation duration scale; higher values feel slower."; value: String(root.animationsStyle.windowSpeed || 4); fallback: 4; minimum: 1; maximum: 10; step: 1; decimals: 0; suffix: " ds"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowSpeed", value); onResetRequested: root.editMotionNumber("windowSpeed", fallback) }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "WORKSPACES"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.workspaceAnimationOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Workspace switching transition owned by Hyprland."; selected: root.animationsStyle.workspace === modelData.key; onClicked: root.chooseAnimations("workspace", modelData.key) } } }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "horizontal", title: "Horizontal" }, { key: "vertical", title: "Vertical" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; opacity: root.workspaceSlideControlsAvailable ? 1 : 0.48; enabled: root.workspaceSlideControlsAvailable; title: modelData.title; description: root.workspaceSlideControlsAvailable ? "Direction for slide and slide-fade travel." : "Choose Workspace → Slide or Slide + fade first."; selected: root.animationsStyle.workspaceAxis === modelData.key; onClicked: root.chooseAnimations("workspaceAxis", modelData.key) } } }
        Components.ShellRangeField { Layout.fillWidth: true; opacity: root.workspaceSlideControlsAvailable ? 1 : 0.48; enabled: root.workspaceSlideControlsAvailable; label: "Workspace travel"; description: root.workspaceSlideControlsAvailable ? "Percentage of the screen used by slide and slide-fade transitions." : "Choose Workspace → Slide or Slide + fade first."; value: String(root.animationsStyle.workspaceTravel || 18); fallback: 18; minimum: 5; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("workspaceTravel", value); onResetRequested: root.editMotionNumber("workspaceTravel", fallback) }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "FOCUS / SHELL"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Focus · Native" }, { key: "quick", title: "Focus · Quick" }, { key: "smooth", title: "Focus · Smooth" }, { key: "digital", title: "Focus · Digital" }, { key: "none", title: "Focus · Off" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.key === "digital" ? "A mechanical neon border, shadow, and dim response without retriggering the desktop shader." : "Focus fade, dim, and shadow transitions."; selected: root.animationsStyle.focus === modelData.key; onClicked: root.chooseAnimations("focus", modelData.key) } } }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "inherit", title: "Special · Native" }, { key: "fade", title: "Special · Fade" }, { key: "slide", title: "Special · Slide" }, { key: "slidevert", title: "Special · Vertical" }, { key: "slidefade", title: "Special · Slide + fade" }, { key: "none", title: "Special · Off" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Scratchpad / special workspace transition."; selected: root.animationsStyle.specialWorkspace === modelData.key; onClicked: root.chooseAnimations("specialWorkspace", modelData.key) } } }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Layers · Native" }, { key: "fade", title: "Layers · Fade" }, { key: "slide", title: "Layers · Slide" }, { key: "none", title: "Layers · Off" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland layer/shell entrance and exit motion."; selected: root.animationsStyle.layers === modelData.key; onClicked: root.chooseAnimations("layers", modelData.key) } } }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "BORDER MOTION"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; text: root.borderMotionAvailable ? "Border Motion is active for Spin and Neon Window Border Style." : "Border Motion is available only when Window → Border Style is Spin or Neon."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.borderAnimationOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; opacity: root.borderMotionAvailable ? 1 : 0.48; enabled: root.borderMotionAvailable; title: modelData.title; description: root.borderMotionAvailable ? "Animated focus-border treatment." : "Choose Spin or Neon in Window → Border Style first."; selected: root.animationsStyle.border === modelData.key; onClicked: root.chooseAnimations("border", modelData.key) } } }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "SCREEN EFFECT"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; text: "Finite Hyprland screen shaders. They activate only around selected events, restore the previous shader afterward, and remain idle between signals."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "none", title: "Effect · Off", description: "Keep the whole desktop stable." }, { key: "rgb-tear", title: "RGB Tear", description: "Cyberpunk horizontal tearing and chromatic separation." }, { key: "spectral-shift", title: "Spectral Shift", description: "Smooth diagonal prism refraction without tearing." }, { key: "phosphor-scan", title: "Phosphor Scan", description: "CRT scanlines, a sync sweep, and restrained phosphor lift." }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.description; selected: root.effectiveScreenEffect().id === modelData.key; onClicked: root.chooseScreenEffect(modelData.key) } } }
        GridLayout { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "low", title: "Low" }, { key: "medium", title: "Medium" }, { key: "strong", title: "Strong" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Strength · " + modelData.title; description: "Bounded shader intensity."; selected: root.effectiveScreenEffect().strength === modelData.key; onClicked: root.chooseEffectStrength(modelData.key) } } }
        Components.ShellRangeField { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; label: "Signal duration"; description: "How long the finite screen effect remains active after an event."; value: String(root.effectiveScreenEffect().durationMs || 500); fallback: root.effectiveScreenEffect().id === "rgb-tear" ? 1250 : root.effectiveScreenEffect().id === "phosphor-scan" ? 850 : 500; minimum: 100; maximum: 5000; step: 50; decimals: 0; suffix: " ms"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editEffectDuration(value); onResetRequested: root.editEffectDuration(fallback) }
        Text { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; text: "TRIGGERS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "window-open", title: "Window open" }, { key: "window-close", title: "Window close" }, { key: "workspace", title: "Workspace" }, { key: "panel", title: "Panel" }, { key: "notification", title: "Notification" }, { key: "urgent", title: "Urgent" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Trigger this finite signal."; selected: root.effectiveScreenEffect().triggers.indexOf(modelData.key) >= 0; onClicked: root.toggleEffectTrigger(modelData.key) } } }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
        Text { Layout.fillWidth: true; text: "TIMING & ACCESSIBILITY"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "bezier", title: "Balanced curve" }, { key: "glass", title: "Glass curve" }, { key: "precision", title: "Precision curve" }, { key: "digital", title: "Digital curve" }, { key: "spring", title: "Spring curve" }]; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Reusable curve family for the selected compositor motion."; selected: root.animationsStyle.curve === modelData.key; onClicked: root.chooseAnimations("curve", modelData.key) } } }
        Components.DesktopOptionCard { Layout.fillWidth: true; compact: true; title: root.animationsStyle.reducedMotion === true ? "Reduced motion · On" : "Reduced motion · Off"; description: "Disable compositor motion while keeping surfaces and layout unchanged."; selected: root.animationsStyle.reducedMotion === true; onClicked: root.chooseAnimations("reducedMotion", !(root.animationsStyle.reducedMotion === true)) }
    }
}
