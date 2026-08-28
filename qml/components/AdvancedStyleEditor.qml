import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// Live Canvas editor for the four native composition documents.  The
// choices remain staged in the session until the parent sends them through
// the preview transaction; this keeps Window, Shell, and Bar changes on their
// real owners instead of simulating them only inside a card.
Item {
    id: root

    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null })
    property var animationsStyle: ({ version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false })
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent
    property int activeTab: 0
    property int barPage: 0

    signal stylesChanged(var shellStyle, var desktopStyle, var barStyle, var animationsStyle)
    signal sectionChanged(int index)

    onActiveTabChanged: root.sectionChanged(root.activeTab)

    readonly property var tabs: [
        { title: "Window", key: "window", eyebrow: "HYPRLAND" },
        { title: "Shell", key: "shell", eyebrow: "QUICKSHELL" },
        { title: "Bar", key: "bar", eyebrow: "QUATTRO BAR" },
        { title: "Animations", key: "animations", eyebrow: "HYPRLAND" }
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
        { key: "native", title: "Native" }, { key: "shadow", title: "Soft dim" }, { key: "shadow_only", title: "Shadow · Preserve transparency" },
        { key: "frosted_light", title: "Frosted · Light" }, { key: "frosted_balanced", title: "Frosted · Balanced" },
        { key: "frosted_rich", title: "Frosted · Rich" }
    ]
    readonly property var activeOptions: [
        { key: "native", title: "Native" }, { key: "frosted_light", title: "Frosted · Light" },
        { key: "frosted_balanced", title: "Frosted · Balanced" }, { key: "frosted_rich", title: "Frosted · Rich" }
    ]
    readonly property var animationOptions: [
        { key: "native", title: "Native" }, { key: "smooth", title: "Smooth" },
        { key: "snappy", title: "Precision" }, { key: "digital", title: "Digital" },
        { key: "spring", title: "Spring" }, { key: "minimal", title: "Minimal" }, { key: "none", title: "Off" }
    ]
    readonly property var workspaceAnimationOptions: [
        { key: "native", title: "Native" }, { key: "fade", title: "Fade" }, { key: "slide", title: "Slide" }, { key: "slidefade", title: "Slide + fade" }, { key: "none", title: "Off" }
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
    readonly property var barPaneOptions: [
        { key: "preset", title: "Preset default" },
        { key: "opaque", title: "Opaque" },
        { key: "metal", title: "Metal" },
        { key: "glass", title: "Glass · blurred" },
        { key: "clear", title: "Clear" }
    ]
    // Size is the first post-preset customization. The BarSpec keeps the
    // compatibility field named density because that is the native Quattro
    // token contract, while the editor presents the user-facing choice as
    // Default / Compact / Comfortable.
    readonly property var barSizeOptions: [
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
    readonly property var barProfileFormOptions: [
        { key: "continuous", title: "Continuous" }, { key: "floating", title: "Floating" },
        { key: "sections", title: "Sections" }, { key: "split", title: "Split" },
        { key: "islands", title: "Islands" }, { key: "dock", title: "Dock" },
        { key: "minimal", title: "Minimal" }, { key: "notch", title: "Notch" }, { key: "rail", title: "Rail" }
    ]
    readonly property var barProfileVisibilityOptions: [
        { key: "always", title: "Always" }, { key: "auto-hide", title: "Auto-hide" },
        { key: "fullscreen-only", title: "Fullscreen" }, { key: "intelligent", title: "Intelligent" }
    ]
    readonly property var barProfileRevealOptions: [
        { key: "edge", title: "Edge reveal" }, { key: "hover-zone", title: "Hover zone" },
        { key: "hotkey", title: "Hotkey" }
    ]
    readonly property var barProfileExpansionOptions: [
        { key: "none", title: "Fixed" }, { key: "hover", title: "Hover" },
        { key: "focus", title: "Focus" }, { key: "adaptive", title: "Adaptive" }
    ]
    readonly property var barProfileWorkspaceOptions: [
        { key: "native", title: "Native" }, { key: "dots", title: "Dots" },
        { key: "numbers", title: "Numbers" }, { key: "labels", title: "Labels" },
        { key: "segmented", title: "Segmented" }, { key: "window-aware", title: "Window aware" },
        { key: "overview", title: "Overview" }
    ]
    readonly property var barPresetOptions: [
        { key: "native", title: "Default" },
        { key: "float", title: "Float Compact" },
        { key: "float-expanded", title: "Float Expanded" },
        { key: "islands", title: "Islands" },
        { key: "dock", title: "Dock" },
        { key: "minimal", title: "Minimal" }
    ]
    readonly property var barTopologyOptions: [
        { key: "continuous", title: "Continuous" }, { key: "floating", title: "Floating" },
        { key: "sections", title: "Sections" }, { key: "islands", title: "Islands" },
        { key: "dock", title: "Dock" }, { key: "split", title: "Split" },
        { key: "minimal", title: "Minimal" }, { key: "notch", title: "Notch" }, { key: "rail", title: "Rail" }
    ]
    property int stagedBorderSize: root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1
    property int stagedBorderSpeed: Number(root.desktopStyle.borderSpeed || 36)
    property bool borderSizeEditing: false
    property bool speedEditing: false
    property bool barSizeAdvancedExpanded: false

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
            preset: root.shellStyle.preset || "default",
            surface: root.shellStyle.surface || "flat",
            detail: root.shellStyle.detail || "native",
            tooltip: root.shellStyle.tooltip || "native",
            notifications: root.shellStyle.notifications || "native",
            overrides: root.shellStyle.overrides || ({})
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
            visibility: root.barStyle.visibility || "native",
            profile: root.barStyle.profile || null,
            spec: root.barStyle.spec || null
        }
        next[group] = key
        var spec = root.barSpec()
		// Size is a composable override, not a new bar recipe. Keep the
		// selected preset visible when the user changes only its density.
		if (group !== "density")
			spec.preset = "custom"
        if (group === "surface") spec.surface.role = key
        if (group === "density") {
            spec.geometry.density = key
            // Selecting a named size returns control to the density preset.
            // An explicit thickness belongs to the advanced override and must
            // not silently mask Compact/Default/Comfortable.
            spec.geometry.thickness = 0
        }
        if (group === "attention") spec.attention.mode = key
        next.spec = spec
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function barSpec() {
        var current = root.barStyle.spec || ({})
        var surface = current.surface || ({})
        var geometry = current.geometry || ({})
        var behavior = current.behavior || ({})
        var regions = current.regions || ({})
        var motion = current.motion || ({})
        var result = {
            version: 2,
            preset: current.preset || (root.barStyle.spec ? "custom" : "native"),
            engine: current.engine || "auto",
            topology: current.topology || (root.barStyle.visibility === "islands" ? "sections" : root.barStyle.form === "docked" ? "sections" : "continuous"),
            position: current.position || "top",
            surface: { treatment: surface.treatment || "preset", role: surface.role || root.barStyle.surface || "native", opacity: surface.opacity !== undefined ? surface.opacity : 1, blur: Number(surface.blur || 0), border_role: surface.border_role || "none", border_opacity: Number(surface.border_opacity || 0), border_width: Number(surface.border_width || 0), shadow: surface.shadow || "none" },
            geometry: { density: geometry.density || root.barStyle.density || "native", thickness: Number(geometry.thickness || 0), edge_offset: Number(geometry.edge_offset || 0), outer_margin: Number(geometry.outer_margin || 0), inner_padding: Number(geometry.inner_padding || 0), section_gap: Number(geometry.section_gap !== undefined ? geometry.section_gap : 8), widget_gap: Number(geometry.widget_gap || 0), radius: Number(geometry.radius || 0), length_mode: geometry.length_mode || "full", length_value: Number(geometry.length_value || 0), alignment: geometry.alignment || "center" },
            attention: { mode: (current.attention && current.attention.mode) || root.barStyle.attention || "semantic" },
            behavior: { visibility: behavior.visibility || "always", exclusive_zone: behavior.exclusive_zone || "reserve", hover_expand: behavior.hover_expand === true, hide_delay_ms: Number(behavior.hide_delay_ms || 500), reveal_delay_ms: Number(behavior.reveal_delay_ms || 50), edge_sensor: Number(behavior.edge_sensor || 3), keep_visible_while_popup_open: behavior.keep_visible_while_popup_open !== false },
            regions: {
                left: { mode: regions.left && regions.left.mode ? regions.left.mode : "native" },
                center: { mode: regions.center && regions.center.mode ? regions.center.mode : "native" },
                right: { mode: regions.right && regions.right.mode ? regions.right.mode : "native" }
            },
            workspace: {
                mode: current.workspace && current.workspace.mode ? current.workspace.mode : "native",
                glyphs: current.workspace && current.workspace.glyphs ? current.workspace.glyphs : []
            },
            motion: { preset: motion.preset || "native", duration_ms: Number(motion.duration_ms || 180), easing: motion.easing || "out_cubic" }
        }
        return root.normalizeBarSpecEngine(result)
    }

    function barSpecValue(group, fallback) {
        var spec = root.barSpec()
        var value = group === "surface" ? spec.surface.role : group === "density" ? spec.geometry.density : group === "attention" ? spec.attention.mode : spec[group]
        return value || fallback
    }

    function barPaneValue() {
        var treatment = String(root.barSpec().surface.treatment || "preset")
        return root.barPaneOptions.some(function(option) { return option.key === treatment }) ? treatment : "preset"
    }

    function barPaneDefaultsForPreset(preset) {
        switch (String(preset || "native")) {
        case "float":
        case "float-expanded":
            return { role: "background", opacity: 0.88, blur: 0 }
        case "sections":
            return { role: "dark", opacity: 0.9, blur: 0 }
        case "dock":
            return { role: "dark", opacity: 0.9, blur: 0 }
        case "split":
        case "notch":
        case "rail":
            return { role: "dark", opacity: 1, blur: 0 }
        case "islands":
        case "minimal":
        case "native":
        default:
            return { role: "native", opacity: 1, blur: 0 }
        }
    }

    function applyBarPaneTreatment(spec, key) {
        var treatment = String(key || "preset")
        var values = treatment === "preset"
            ? root.barPaneDefaultsForPreset(spec.preset)
            : treatment === "opaque"
            ? { role: "background", opacity: 1, blur: 0 }
            : treatment === "metal"
            ? { role: "dark", opacity: 0.94, blur: 0 }
            : treatment === "glass"
            ? { role: "background", opacity: 0.72, blur: 1 }
            : { role: "transparent", opacity: 0.18, blur: 0 }
        spec.surface.treatment = treatment
        spec.surface.role = values.role
        spec.surface.opacity = values.opacity
        spec.surface.blur = values.blur
    }

    function chooseBarPane(key) {
        var spec = root.barSpec()
        root.applyBarPaneTreatment(spec, key)
        root.publishBarSpec(spec)
    }

    function barIsVertical(spec) {
        var position = String(spec && spec.position || "top")
        return position === "left" || position === "right"
    }

    function barBaseSizeForDensity(density, spec) {
        if (density === "compact") return root.barIsVertical(spec) ? 24 : 22
        if (density === "comfortable") return root.barIsVertical(spec) ? 32 : 30
        return root.barIsVertical(spec) ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
    }

    function barStructuralPadding(spec) {
        var topology = String(spec && spec.topology || "continuous")
        // Dock adds cross-axis capsule padding. Vertical Islands uses the
        // same widened rail footprint; horizontal Islands keeps barSize as
        // its visible height.
        return topology === "dock" || (topology === "islands" && root.barIsVertical(spec))
            ? Style.space(16) : 0
    }

    function barResolvedBaseSize(spec) {
        var geometry = spec && spec.geometry ? spec.geometry : ({})
        var thickness = Number(geometry.thickness || 0)
        return thickness > 0
            ? Math.round(thickness)
            : root.barBaseSizeForDensity(String(geometry.density || "native"), spec)
    }

    function barAdvancedSizeValue() {
        var spec = root.barSpec()
        return root.barResolvedBaseSize(spec) + root.barStructuralPadding(spec)
    }

    function barAdvancedSizeFallback() {
        var spec = root.barSpec()
        var density = String(spec.geometry && spec.geometry.density || "native")
        return root.barBaseSizeForDensity(density, spec) + root.barStructuralPadding(spec)
    }

    function barAdvancedSizeMinimum() {
        var spec = root.barSpec()
        return root.barBaseSizeForDensity("compact", spec) + root.barStructuralPadding(spec)
    }

    function barAdvancedSizeMaximum() {
        return 128 + root.barStructuralPadding(root.barSpec())
    }

    function barAdvancedSizeIsCustom() {
        var spec = root.barSpec()
        return Number(spec.geometry && spec.geometry.thickness || 0) > 0
    }

    function barSizeOptionTitle(key) {
        var spec = root.barSpec()
        var label = key === "compact" ? "Compact" : key === "comfortable" ? "Comfortable" : "Default"
        var renderedSize = root.barBaseSizeForDensity(key, spec) + root.barStructuralPadding(spec)
        return label + " · " + renderedSize + " px"
    }

    function barSizeOptionsWithPixels() {
        return [
            { key: "native", title: root.barSizeOptionTitle("native") },
            { key: "compact", title: root.barSizeOptionTitle("compact") },
            { key: "comfortable", title: root.barSizeOptionTitle("comfortable") }
        ]
    }

    function barPresetValue() {
        var preset = String(root.barSpec().preset || "custom")
        // Older generated state called this recipe glass-islands. Keep that
        // state selectable while presenting the user-facing preset simply as
        // Islands.
        return preset === "glass-islands" ? "islands" : preset
    }

    function normalizeBarSpecEngine(spec) {
        var nativeTopology = spec.topology === "continuous"
        var surface = spec.surface || ({})
        var geometry = spec.geometry || ({})
        var behavior = spec.behavior || ({})
        var motion = spec.motion || ({})
        var regions = spec.regions || ({})
        var workspace = spec.workspace || ({})
        var nativeSurface = ["native", "background", "dark", "light", "accent", "transparent"].indexOf(surface.role) >= 0
            && (surface.border_role || "none") === "none"
            && Number(surface.border_opacity || 0) === 0
            && Number(surface.border_width || 0) === 0
            && (surface.shadow || "none") === "none"
        var nativeGeometry = (spec.position || "top") === "top"
            && Number(geometry.edge_offset || 0) === 0
            && Number(geometry.outer_margin || 0) === 0
            && Number(geometry.inner_padding || 0) === 0
            && Number(geometry.section_gap !== undefined ? geometry.section_gap : 8) === 8
            && Number(geometry.widget_gap || 0) === 0
            && Number(geometry.radius || 0) === 0
            && (geometry.length_mode || "full") === "full"
            && Number(geometry.length_value || 0) === 0
            && (geometry.alignment || "center") === "center"
        var nativeBehavior = (behavior.visibility || "always") === "always" && behavior.exclusive_zone === "reserve" && behavior.hover_expand !== true
        var nativeMotion = (motion.preset || "native") === "native"
            && Number(motion.duration_ms !== undefined ? motion.duration_ms : 180) === 180
            && (motion.easing || "out_cubic") === "out_cubic"
        var nativeRegions = ["left", "center", "right"].every(function(region) {
            return !regions[region] || (regions[region].mode || "native") === "native"
        })
        var nativeWorkspace = (workspace.mode || "native") === "native" && (!workspace.glyphs || workspace.glyphs.length === 0)
        var needsAdapter = !nativeTopology || !nativeSurface || !nativeGeometry || !nativeBehavior || !nativeRegions || !nativeWorkspace || !nativeMotion
        if (!needsAdapter && spec.engine === "omagen")
            spec.engine = "auto"
        if (needsAdapter && spec.engine === "native")
            spec.engine = "auto"
        if (!spec.engine)
            spec.engine = needsAdapter ? "omagen" : "auto"
        if (needsAdapter && spec.engine === "auto")
            spec.engine = "omagen"
        return spec
    }

    function publishBarSpec(spec) {
        spec = root.normalizeBarSpecEngine(spec)
        var topologyForm = spec.topology
        var profile = {
            schema_version: 1,
            ownership: "overlay",
            implementation: "native",
            bar: { id: "omarchy.bar" },
            behavior: { form: topologyForm, visibility: "always", reveal: "edge", expansion: "none", workspace: "native" }
        }
        var replacement = spec.engine === "omagen" || spec.topology !== "continuous"
        if (replacement) {
            var oldBehavior = root.barStyle.profile && root.barStyle.profile.behavior
                ? JSON.parse(JSON.stringify(root.barStyle.profile.behavior)) : ({})
            oldBehavior.form = topologyForm
            oldBehavior.expansion = spec.behavior.hover_expand ? "hover" : "none"
            profile = { schema_version: 1, ownership: "overlay", implementation: "replacement", bar: { id: "pretty.omagen.bar" }, behavior: oldBehavior }
        }
        var next = {
            surface: ["dark", "light", "accent"].indexOf(spec.surface.role) >= 0 ? spec.surface.role : root.barStyle.surface || "native",
            density: spec.geometry.density || root.barStyle.density || "native",
            attention: spec.attention.mode || root.barStyle.attention || "semantic",
            form: ["continuous", "floating", "minimal"].indexOf(spec.topology) >= 0 ? "continuous" : "docked",
            visibility: spec.topology === "sections" || spec.topology === "islands" ? "islands" : "native",
            profile: profile,
            spec: spec
        }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseBarThickness(value) {
        var spec = root.barSpec()
        var padding = root.barStructuralPadding(spec)
        var minimum = root.barAdvancedSizeMinimum()
        var maximum = root.barAdvancedSizeMaximum()
        var rendered = Math.max(minimum, Math.min(maximum, Math.round(Number(value))))
        var baseMinimum = root.barBaseSizeForDensity("compact", spec)
        spec.geometry.thickness = Math.max(baseMinimum, Math.round(rendered - padding))
        root.publishBarSpec(spec)
    }

    function resetBarThickness() {
        var spec = root.barSpec()
        spec.geometry.thickness = 0
        root.publishBarSpec(spec)
    }

    function chooseBarSpec(group, key) {
        var spec = root.barSpec()
		spec.preset = "custom"
        if (group === "surface") {
            spec.surface.role = key
            if (key === "transparent") spec.surface.opacity = 0
        } else if (group === "density") {
            spec.geometry.density = key
            spec.geometry.thickness = 0
        } else if (group === "attention") {
            spec.attention.mode = key
        } else {
            spec[group] = key
        }
        if (group === "topology") {
            spec.position = key === "rail" ? "left" : "top"
            if (key === "minimal")
                spec.behavior.hover_expand = true
        }
        if (group === "topology")
            spec.engine = ["continuous", "minimal"].indexOf(key) >= 0 ? "auto" : "omagen"
        spec = root.normalizeBarSpecEngine(spec)
        var topologyForm = spec.topology
        var profile = {
            schema_version: 1,
            ownership: "overlay",
            implementation: "native",
            bar: { id: "omarchy.bar" },
            behavior: { form: topologyForm, visibility: "always", reveal: "edge", expansion: "none", workspace: "native" }
        }
        if (spec.topology !== "continuous") {
            var oldBehavior = root.barStyle.profile && root.barStyle.profile.behavior ? JSON.parse(JSON.stringify(root.barStyle.profile.behavior)) : ({})
            oldBehavior.form = topologyForm
            oldBehavior.expansion = spec.behavior.hover_expand ? "hover" : "none"
            profile = { schema_version: 1, ownership: "overlay", implementation: "replacement", bar: { id: "pretty.omagen.bar" }, behavior: oldBehavior }
        }
        var next = {
            surface: key === "dark" || key === "light" || key === "accent" ? key : root.barStyle.surface || "native",
            density: spec.geometry.density || root.barStyle.density || "native",
            attention: spec.attention.mode || root.barStyle.attention || "semantic",
            form: ["continuous", "floating", "minimal"].indexOf(spec.topology) >= 0 ? "continuous" : "docked",
            visibility: spec.topology === "sections" || spec.topology === "islands" ? "islands" : "native",
            profile: profile,
            spec: spec
        }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseBarPreset(key) {
        if (key === "custom")
            return
        var spec = root.barSpec()
		var currentDensity = spec.geometry && spec.geometry.density
			? String(spec.geometry.density)
			: String(root.barStyle.density || "native")
		var explicitDensity = currentDensity !== "native" ? currentDensity : ""
		spec.preset = key
        spec.engine = "auto"
        spec.topology = "continuous"
        spec.position = "top"
        spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "none", border_opacity: 0, border_width: 0, shadow: "none" }
        spec.geometry = { density: "native", thickness: 0, edge_offset: 0, outer_margin: 0, inner_padding: 0, section_gap: 8, widget_gap: 0, radius: 0, length_mode: "full", length_value: 0, alignment: "center" }
        spec.behavior = { visibility: "always", exclusive_zone: "reserve", hover_expand: false, hide_delay_ms: 500, reveal_delay_ms: 50, edge_sensor: 3, keep_visible_while_popup_open: true }
        spec.regions = { left: { mode: "native" }, center: { mode: "native" }, right: { mode: "native" } }
        spec.workspace = { mode: "native", glyphs: [] }
        spec.motion = { preset: "native", duration_ms: 180, easing: "out_cubic" }
        switch (key) {
        case "float": spec.topology = "floating"; spec.surface = { role: "background", opacity: 0.88, blur: 0, border_role: "foreground", border_opacity: 0.3, border_width: 1, shadow: "raised" }; spec.geometry.density = "compact"; spec.geometry.edge_offset = 8; spec.geometry.outer_margin = 8; spec.geometry.radius = 14; break
        case "float-expanded": spec.topology = "floating"; spec.surface = { role: "background", opacity: 0.88, blur: 0, border_role: "foreground", border_opacity: 0.3, border_width: 1, shadow: "raised" }; spec.geometry.density = "native"; spec.geometry.edge_offset = 8; spec.geometry.outer_margin = 8; spec.geometry.radius = 14; spec.behavior.hover_expand = true; break
        case "sections": spec.topology = "sections"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "accent", border_opacity: 0.35, border_width: 1, shadow: "flat" }; spec.geometry.section_gap = 10; spec.geometry.radius = 14; spec.regions = { left: { mode: "island" }, center: { mode: "island" }, right: { mode: "island" } }; break
        case "islands": spec.engine = "omagen"; spec.topology = "islands"; spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "foreground", border_opacity: 0.35, border_width: 1, shadow: "none" }; spec.geometry.radius = 14; spec.regions = { left: { mode: "island" }, center: { mode: "island" }, right: { mode: "island" } }; break
        case "dock": spec.engine = "omagen"; spec.topology = "dock"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "foreground", border_opacity: 0.25, border_width: 1, shadow: "floating" }; spec.geometry.length_mode = "content"; spec.geometry.alignment = "center"; spec.geometry.radius = 16; spec.behavior.visibility = "auto_hide"; spec.behavior.hover_expand = true; break
        case "minimal": spec.engine = "omagen"; spec.topology = "minimal"; spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "foreground", border_opacity: 0.35, border_width: 1, shadow: "none" }; spec.geometry.density = "compact"; spec.behavior.hover_expand = true; spec.motion = { preset: "smooth", duration_ms: 260, easing: "out_cubic" }; break
        case "split": spec.engine = "omagen"; spec.topology = "split"; spec.surface.role = "dark"; break
        case "notch": spec.engine = "omagen"; spec.topology = "notch"; spec.surface.role = "dark"; spec.geometry.radius = 14; break
        case "rail": spec.engine = "omagen"; spec.topology = "rail"; spec.position = "left"; spec.surface.role = "dark"; break
        }
		spec.surface.treatment = "preset"
		// Presets provide their own default density, but an explicit Compact or
		// Comfortable choice is a user override and must survive preset changes.
		if (explicitDensity !== "")
			spec.geometry.density = explicitDensity
        var profile = {
            schema_version: 1,
            ownership: "overlay",
            implementation: "native",
            bar: { id: "omarchy.bar" },
            behavior: { form: "continuous", visibility: "always", reveal: "edge", expansion: "none", workspace: "native" }
        }

        if (spec.topology !== "continuous") {
			var behavior = { form: spec.topology, visibility: spec.behavior.visibility === "auto_hide" ? "auto-hide" : "always", reveal: "edge", expansion: spec.behavior.hover_expand ? "hover" : "none", workspace: "native" }
			profile = { schema_version: 1, ownership: "overlay", implementation: "replacement", bar: { id: "pretty.omagen.bar" }, behavior: behavior }
        }
        var next = { surface: ["native", "dark", "light", "accent"].indexOf(spec.surface.role) >= 0 ? spec.surface.role : "native", density: spec.geometry.density, attention: root.barStyle.attention || "semantic", form: ["continuous", "floating", "minimal"].indexOf(spec.topology) >= 0 ? "continuous" : "docked", visibility: spec.topology === "sections" || spec.topology === "islands" ? "islands" : "native", profile: profile, spec: spec }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseBarProfile(group, key) {
        var current = root.barStyle.profile || ({})
        var behavior = JSON.parse(JSON.stringify(current.behavior || ({})))
        behavior[group] = key
        var profile = {
            schema_version: 1,
            ownership: "overlay",
            implementation: "replacement",
            bar: { id: "pretty.omagen.bar" },
            behavior: behavior
        }
        if (group === "form") {
            profile.behavior.form = key
            profile.behavior.visibility = behavior.visibility || "always"
            profile.behavior.reveal = behavior.reveal || "edge"
            profile.behavior.expansion = behavior.expansion || "none"
            profile.behavior.workspace = behavior.workspace || "native"
            if (key === "continuous") {
                profile.implementation = "native"
                profile.bar = { id: "omarchy.bar" }
            }
        }
        var nextSpec = root.barStyle.spec ? root.barSpec() : null
        if (nextSpec) {
            if (group === "form") {
                var topologyByForm = { continuous: "continuous", floating: "floating", sections: "sections", split: "split", islands: "islands", dock: "dock", rail: "rail", minimal: "minimal", notch: "notch" }
                nextSpec.topology = topologyByForm[key] || nextSpec.topology
                nextSpec.position = key === "rail" ? "left" : "top"
            } else if (group === "visibility") {
                var visibilityByProfile = { always: "always", "auto-hide": "auto_hide", "fullscreen-only": "fullscreen", intelligent: "hover" }
                nextSpec.behavior.visibility = visibilityByProfile[key] || nextSpec.behavior.visibility
            } else if (group === "expansion") {
                nextSpec.behavior.hover_expand = key !== "none"
            }
            nextSpec = root.normalizeBarSpecEngine(nextSpec)
        }
        var next = {
            surface: root.barStyle.surface || "native",
            density: root.barStyle.density || "native",
            attention: root.barStyle.attention || "semantic",
            form: ["continuous", "floating", "minimal"].indexOf(key) >= 0 ? "continuous" : "docked",
            visibility: key === "islands" || key === "sections" ? "islands" : (root.barStyle.visibility || "native"),
            profile: profile,
            spec: nextSpec
        }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function barProfileValue(group, fallback) {
        var profile = root.barStyle.profile || null
        var behavior = profile && profile.behavior ? profile.behavior : null
        if (behavior && behavior[group])
            return behavior[group]
        if (root.barStyle.spec) {
            var spec = root.barSpec()
            if (group === "form")
                return spec.topology === "continuous" || spec.topology === "floating" ? "continuous" : spec.topology
            if (group === "visibility")
                return spec.behavior.visibility === "auto_hide" ? "auto-hide" : spec.behavior.visibility === "fullscreen" ? "fullscreen-only" : spec.behavior.visibility === "hover" ? "intelligent" : "always"
            if (group === "expansion")
                return spec.behavior.hover_expand === true ? "hover" : "none"
        }
        return fallback
    }

    function barOptionDescriptions(group, options) {
        var descriptions = {}
        for (var index = 0; index < options.length; index++)
            descriptions[options[index].key] = root.optionDescription("bar", group, options[index].key)
        return descriptions
    }

    readonly property var motionPresetOptions: [
        { key: "native", title: "Native", description: "Keep the current Quattro motion baseline." },
        { key: "snappy", title: "Precision", description: "Near-full-size window entrances, immediate focus, and fade-led workspace changes." },
        { key: "smooth", title: "Floating Flow", description: "Deeper soft window entrances, gliding workspaces, and a long glass-like settle." },
        { key: "spring", title: "Spring", description: "Spring curves for window movement and settling." },
        { key: "cinematic", title: "Cinematic", description: "Slower entrances with fade-led layer motion." },
        { key: "minimal", title: "Minimal", description: "Fade-led motion with no bounce or travel." },
        { key: "cyberpunk", title: "Cyberpunk Glitch", description: "Digital window deformation, mechanical focus, spatial workspace cuts, and a 1250 ms event-driven RGB tear." }
    ]

    function motionBase() {
        var a = root.animationsStyle || ({})
        var glitch = a.glitch || "none"
        if (glitch === "flicker") glitch = "medium"
		var rawEffect = a.screenEffect || a.screen_effect || null
		var screenEffect = rawEffect ? {
			id: rawEffect.id || "none", strength: rawEffect.strength || "medium",
			durationMs: Number(rawEffect.durationMs !== undefined ? rawEffect.durationMs : rawEffect.duration_ms || 0),
			triggers: (rawEffect.triggers || []).slice(), coalesce: rawEffect.coalesce !== false
		} : null
        return {
            version: Number(a.version || 1), preset: a.preset || "native",
            window: a.window || "native", windowOpen: a.windowOpen || a.window_open || "popin", windowClose: a.windowClose || a.window_close || "popin", windowMove: a.windowMove || a.window_move || "native",
            windowAmount: Number(a.windowAmount !== undefined ? a.windowAmount : a.window_amount || 87), windowOpacity: Number(a.windowOpacity !== undefined ? a.windowOpacity : a.window_opacity !== undefined ? a.window_opacity : 100), windowSpeed: Number(a.windowSpeed !== undefined ? a.windowSpeed : a.window_speed || 4),
            workspace: a.workspace || "native", workspaceAxis: a.workspaceAxis || a.workspace_axis || "horizontal", workspaceTravel: Number(a.workspaceTravel !== undefined ? a.workspaceTravel : a.workspace_travel || 18),
            specialWorkspace: a.specialWorkspace || a.special_workspace || "inherit", focus: a.focus || "native", layers: a.layers || "native", curve: a.curve || "bezier",
			border: a.border || "native", borderSpeed: Number(a.borderSpeed || a.border_speed || 36), glitch: glitch, screenEffect: screenEffect, reducedMotion: a.reducedMotion === true || a.reduced_motion === true
        }
    }

	function effectiveScreenEffect() {
		var current = root.motionBase()
		if (current.screenEffect)
			return current.screenEffect
		if (current.glitch !== "none")
			return { id: "rgb-tear", strength: current.glitch, durationMs: 1250, triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"], coalesce: true }
		return { id: "none", strength: "medium", durationMs: 0, triggers: [], coalesce: true }
	}

	function defaultEffect(id, strength) {
		if (id === "spectral-shift")
			return { id: id, strength: strength || "medium", durationMs: 500, triggers: ["window-open", "window-close", "workspace", "panel"], coalesce: true }
		if (id === "phosphor-scan")
			return { id: id, strength: strength || "medium", durationMs: 850, triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"], coalesce: true }
		return { id: "rgb-tear", strength: strength || "medium", durationMs: 1250, triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"], coalesce: true }
	}

	function chooseScreenEffect(id) {
		var next = root.motionBase()
		var current = root.effectiveScreenEffect()
		next.preset = "custom"
		if (id === "none") { next.glitch = "none"; next.screenEffect = null }
		else if (id === "rgb-tear") { next.glitch = current.strength || "medium"; next.screenEffect = null }
		else { next.glitch = "none"; next.screenEffect = root.defaultEffect(id, current.strength) }
		root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
	}

	function chooseEffectStrength(strength) {
		var next = root.motionBase()
		var effect = root.effectiveScreenEffect()
		next.preset = "custom"
		if (effect.id === "rgb-tear") { next.glitch = strength; next.screenEffect = null }
		else if (effect.id !== "none") { effect.strength = strength; next.glitch = "none"; next.screenEffect = effect }
		root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
	}

	function editEffectDuration(value) {
		var next = root.motionBase()
		var effect = root.effectiveScreenEffect()
		if (effect.id === "none") return
		effect.durationMs = Math.max(100, Math.min(5000, Math.round(Number(value))))
		next.preset = "custom"; next.glitch = "none"; next.screenEffect = effect
		root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
	}

	function toggleEffectTrigger(trigger) {
		var next = root.motionBase()
		var effect = root.effectiveScreenEffect()
		if (effect.id === "none") return
		var index = effect.triggers.indexOf(trigger)
		if (index >= 0) effect.triggers.splice(index, 1); else effect.triggers.push(trigger)
		next.preset = "custom"; next.glitch = "none"; next.screenEffect = effect
		root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
	}

    function chooseMotionPreset(name) {
        var next = motionBase()
        next.preset = name
        next.window = "native"; next.windowOpen = "popin"; next.windowClose = "popin"; next.windowMove = "native"; next.windowAmount = 87; next.windowOpacity = 100; next.windowSpeed = 4
		next.workspace = "native"; next.workspaceAxis = "horizontal"; next.workspaceTravel = 18; next.specialWorkspace = "inherit"; next.focus = "native"; next.layers = "native"; next.curve = "bezier"; next.glitch = "none"; next.screenEffect = null
        if (name === "snappy") { next.window = "snappy"; next.workspace = "fade"; next.windowMove = "quick"; next.windowAmount = 97; next.windowSpeed = 1; next.workspaceTravel = 5; next.focus = "quick"; next.layers = "fade"; next.curve = "precision" }
        else if (name === "smooth") { next.window = "smooth"; next.workspace = "slidefade"; next.windowMove = "smooth"; next.windowAmount = 82; next.windowSpeed = 4; next.workspaceTravel = 22; next.specialWorkspace = "fade"; next.focus = "smooth"; next.layers = "fade"; next.curve = "glass" }
        else if (name === "spring") { next.window = "spring"; next.workspace = "slidefade"; next.windowMove = "spring"; next.curve = "spring"; next.workspaceTravel = 18; next.focus = "smooth"; next.layers = "fade" }
        else if (name === "cinematic") { next.window = "cinematic"; next.windowClose = "gnomed"; next.workspace = "slidefade"; next.windowAmount = 76; next.windowSpeed = 5; next.workspaceTravel = 28; next.specialWorkspace = "slide"; next.focus = "smooth"; next.layers = "slide" }
        else if (name === "minimal") { next.window = "minimal"; next.windowOpen = "fade"; next.windowClose = "fade"; next.windowMove = "none"; next.workspace = "fade"; next.windowAmount = 100; next.windowSpeed = 1; next.workspaceTravel = 5; next.focus = "quick"; next.layers = "fade"; next.curve = "precision" }
        else if (name === "cyberpunk") { next.window = "digital"; next.windowOpen = "gnomed"; next.windowClose = "slide"; next.windowMove = "digital"; next.workspace = "slide"; next.windowAmount = 94; next.windowOpacity = 82; next.windowSpeed = 2; next.workspaceTravel = 12; next.specialWorkspace = "slidevert"; next.focus = "digital"; next.layers = "slide"; next.curve = "digital"; next.border = "static"; next.glitch = "medium" }
		if (next.reducedMotion) { next.window = "none"; next.workspace = "none"; next.border = "static"; next.glitch = "none"; next.screenEffect = null }
        root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
    }

    function chooseAnimations(group, key) {
        var next = motionBase()
        if (group === "specialWorkspace") group = "specialWorkspace"
        next[group] = key
        next.preset = "custom"
		if (next.reducedMotion) { next.window = "none"; next.workspace = "none"; next.border = "static"; next.glitch = "none"; next.screenEffect = null }
        root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, next)
    }

    function editMotionNumber(group, value) {
        var next = motionBase()
        next.preset = "custom"
        next[group] = Number(value)
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
            if (key === "blur" || key.indexOf("frosted_") === 0) return "Frosted backdrop blurs what is behind a translucent window surface. It does not blur opaque application text or controls."
            if (key === "shadow") return "Soft dim keeps inactive windows readable while making the focused window clearer."
            if (key === "shadow_only") return "Adds a transparent inactive compositor shadow while preserving Omarchy and application opacity."
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
        if (group === "preset") {
            if (key === "dock") return "A centered content-sized capsule that expands along the bar axis while the full edge remains the hover and drag host."
            return key === "custom" ? "Keep the current structural choices while editing them below." : "Apply a complete recipe, including a clean placement and behavior baseline."
        }
        if (group === "topology") return key === "rail" ? "Use a vertical reader at the left edge; choosing another topology restores the top placement." : "Choose the structural shape independently from the recipe controls."
        if (group === "form") return "Continuous keeps the native surface; advanced shapes select the Omagen replacement host while preserving your shell.json layout."
        if (group === "visibility") return "Visibility is staged with the theme profile and restored with the user's bar state."
        if (group === "expansion") return "Choose whether the themed bar expands fixed content on hover, focus, or available space."
        if (group === "workspace") return "Workspace presentation is a theme profile; native workspace actions remain authoritative."
        if (group === "reveal") return "How the replacement bar is summoned while the native bar remains the fallback for unmarked themes."
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
                    shadow_only: "Add a transparent compositor shadow without overriding inactive opacity or dimming content.",
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
                pane: {
                    preset: "Keep the selected bar preset's own pane recipe; this is the reset target.",
                    opaque: "Use a solid theme background for maximum contrast and no backdrop blur.",
                    metal: "Use a near-opaque dark neutral pane for a restrained metal-like finish without compositor blur.",
                    glass: "Use a translucent theme tint with real Hyprland layer blur behind the bar.",
                    clear: "Use a mostly transparent pane without blur for maximum wallpaper visibility and low GPU cost."
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
                    docked: "Use the Omagen replacement host for docked sections while retaining native widget entries."
                },
                visibility: {
                    native: "Keep the native bar visibility and transparency.",
                    islands: "Show the supported docked section surfaces as separate islands."
                },
                reveal: {
                    edge: "Reveal the hidden bar by touching the screen edge.",
                    "hover-zone": "Reveal the hidden bar from a small hover target at the edge.",
                    hotkey: "Reveal the hidden bar only through the configured shell shortcut."
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
            text: "ADVANCED CONTROLS"
            color: root.accentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
        }
        Text {
            Layout.fillWidth: true
            text: "Tune one of the four engines independently. The selected Look & Feel recipe remains the starting point."
            color: root.foregroundColor
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
                    foreground: root.activeTab === index ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                    background: root.activeTab === index ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                    accent: root.accentColor
                    bordered: true
                    onClicked: root.activeTab = index
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: root.activeTab
            implicitHeight: root.activeTab === 0 ? windowColumn.implicitHeight : root.activeTab === 1 ? shellPage.implicitHeight : root.activeTab === 2 ? barColumn.implicitHeight : animationColumn.implicitHeight

            Item {
                implicitHeight: windowColumn.implicitHeight
                ColumnLayout {
                    id: windowColumn
                    width: parent.width
                    spacing: Style.space(5)
                    Text { Layout.fillWidth: true; text: "HYPRLAND WINDOW EFFECTS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: "Window appearance is written to hyprland.lua for the compositor."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { Layout.fillWidth: true; text: "BORDER STYLE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.borderOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "borderStyle", modelData.key); selected: root.desktopStyle.borderStyle === modelData.key; onClicked: root.chooseDesktop("borderStyle", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "BORDER THICKNESS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        Text { text: "BORDER"; color: root.foregroundColor; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        PanelSlider {
                            id: borderSlider
                            Layout.fillWidth: true
                            minimum: 0
                            maximum: 13
                            step: 1
                            integer: true
                            value: root.borderSliderPosition()
                            tickCount: 14
                            trackColor: Util.alpha(root.foregroundColor, 0.2)
                            fillColor: root.accentColor
                            knobColor: root.accentColor
                            tickColor: root.backgroundColor
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
                                color: root.accentColor
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
                                color: Util.alpha(root.backgroundColor, 0.48)
                                border.width: 1
                                border.color: borderSizeInput.activeFocus ? root.accentColor : Color.popups.border
                            }
                            TextInput {
                                id: borderSizeInput
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(6)
                                anchors.rightMargin: Style.space(6)
                                visible: root.borderSizeEditing
                                color: root.foregroundColor
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
                    Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "SPIN SPEED"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "Controls the full gradient cycle. Lower seconds move faster."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    RowLayout {
                        visible: root.desktopStyle.borderStyle === "spin"
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        Text { text: "SPEED"; color: root.foregroundColor; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                        PanelSlider {
                            id: speedSlider
                            Layout.fillWidth: true
                            minimum: 10
                            maximum: 100
                            step: 1
                            integer: true
                            value: root.stagedBorderSpeed
                            tickCount: 10
                            trackColor: Util.alpha(root.foregroundColor, 0.2)
                            fillColor: root.accentColor
                            knobColor: root.accentColor
                            tickColor: root.backgroundColor
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
                                color: root.accentColor
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
                                color: Util.alpha(root.backgroundColor, 0.48)
                                border.width: 1
                                border.color: speedInput.activeFocus ? root.accentColor : Color.popups.border
                            }
                            TextInput {
                                id: speedInput
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(6)
                                anchors.rightMargin: Style.space(6)
                                visible: root.speedEditing
                                color: root.foregroundColor
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
                    Text { Layout.fillWidth: true; text: "SHAPE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.shapeOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "shape", modelData.key); selected: root.desktopStyle.shape === modelData.key; onClicked: root.chooseDesktop("shape", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "SPACING"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.spacingOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "spacing", modelData.key); selected: root.desktopStyle.spacing === modelData.key; onClicked: root.chooseDesktop("spacing", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "DEPTH"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.depthOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "depth", modelData.key); selected: root.desktopStyle.depth === modelData.key; onClicked: root.chooseDesktop("depth", modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "ACTIVE WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Active and inactive opacity/dim choices are independent. Hyprland uses one shared blur kernel, so the focused window's frosted choice sets the blur strength when active glass is enabled."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.activeOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Focused-window opacity and backdrop treatment."; selected: (root.desktopStyle.activeStyle || "native") === modelData.key; onClicked: root.chooseActive(modelData.key) } }
                    }
                    Text { Layout.fillWidth: true; text: "INACTIVE WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: root.description("window", "inactiveStyle", root.desktopStyle.inactiveStyle || "native"); color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout {
                        Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
                        Repeater { model: root.inactiveOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("window", "inactiveStyle", modelData.key); selected: (root.desktopStyle.inactiveStyle || "native") === modelData.key || (modelData.key === "frosted_balanced" && root.desktopStyle.inactiveStyle === "blur"); onClicked: root.chooseDesktop("inactiveStyle", modelData.key) } }
                    }
                }
            }

            Item {
                id: shellPage
                implicitHeight: shellLab.implicitHeight

                ShellLab {
                    id: shellLab
                    width: parent.width
                    shellStyle: root.shellStyle
                    onStyleChanged: root.stylesChanged(shellStyle, root.desktopStyle, root.barStyle, root.animationsStyle)
                }
            }

            Item {
                implicitHeight: barColumn.implicitHeight
                ColumnLayout {
                    id: barColumn
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                        Layout.fillWidth: true
                        text: "BAR INSPECTOR"
                        color: root.accentColor
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Choose a bar preset, then tune its size. Native widgets, placement, ordering, and input stay with Quattro."
                        color: root.foregroundColor
                        opacity: 0.62
                        wrapMode: Text.WordWrap
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(5)

                        Repeater {
                            model: ["Composition"]
                            delegate: Button {
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(38)
                                text: modelData
                                foreground: root.barPage === index ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor) : root.foregroundColor
                                background: root.barPage === index ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                                accent: root.accentColor
                                selected: root.barPage === index
                                bordered: true
                                onClicked: root.barPage = index
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: root.barPage
                        implicitHeight: barCompositionPage.implicitHeight

                        Item {
                            id: barCompositionPage
                            implicitHeight: barCompositionColumn.implicitHeight

                            ColumnLayout {
                                id: barCompositionColumn
                                width: parent.width
                                spacing: Style.space(8)

                                BarChoiceGroup {
                                    Layout.fillWidth: true
                                    title: "Preset"
                                    subtitle: "Choose the bar's complete recipe"
                                    options: root.barPresetOptions
                                    selectedKey: root.barPresetValue()
                                    optionDescriptions: root.barOptionDescriptions("preset", root.barPresetOptions)
                                    onChoiceSelected: root.chooseBarPreset(key)
                                }

                                BarChoiceGroup {
                                    Layout.fillWidth: true
                                    title: "Size"
                                    subtitle: "Choose a size mode with its rendered pixel height"
                                    options: root.barSizeOptionsWithPixels()
                                    selectedKey: root.barSpecValue("density", "native")
                                    selectedTitleOverride: root.barAdvancedSizeIsCustom() ? root.barAdvancedSizeValue() + " px" : ""
                                    optionDescriptions: root.barOptionDescriptions("density", root.barSizeOptions)
                                    onChoiceSelected: root.chooseBar("density", key)
                                }

                                BarChoiceGroup {
                                    Layout.fillWidth: true
                                    title: "Pane"
                                    subtitle: "Choose the bar background treatment"
                                    options: root.barPaneOptions
                                    selectedKey: root.barPaneValue()
                                    optionDescriptions: root.barOptionDescriptions("pane", root.barPaneOptions)
                                    onChoiceSelected: root.chooseBarPane(key)
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: Style.space(2)
                                    color: Util.alpha(root.foregroundColor, 0.16)
                                }

                                BarWorkspaceControls {
                                    Layout.fillWidth: true
                                    spec: root.barSpec()
                                    onSpecEdited: root.publishBarSpec(spec)
                                }

                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Style.space(34)
                                    text: root.barSizeAdvancedExpanded ? "Hide advanced size" : "Show advanced size"
                                    foreground: root.foregroundColor
                                    accent: root.accentColor
                                    background: root.barSizeAdvancedExpanded ? Util.alpha(root.accentColor, 0.1) : Util.alpha(root.foregroundColor, 0.045)
                                    bordered: true
                                    onClicked: root.barSizeAdvancedExpanded = !root.barSizeAdvancedExpanded
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.barSizeAdvancedExpanded ? implicitHeight : 0
                                    Layout.minimumHeight: 0
                                    visible: root.barSizeAdvancedExpanded
                                    spacing: Style.space(5)

                                    ShellRangeField {
                                        Layout.fillWidth: true
                                        label: "Resolved bar size"
                                        description: "Set an explicit pixel size for this preset. The minimum is " + root.barAdvancedSizeMinimum() + " px so the preset's smallest layout remains usable."
                                        value: String(root.barAdvancedSizeValue())
                                        fallback: root.barAdvancedSizeFallback()
                                        minimum: root.barAdvancedSizeMinimum()
                                        maximum: root.barAdvancedSizeMaximum()
                                        step: 1
                                        decimals: 0
                                        suffix: " px"
                                        resetText: "Reset to " + root.barAdvancedSizeFallback() + " px"
                                        integer: true
                                        modified: root.barAdvancedSizeIsCustom()
                                        onValueEdited: root.chooseBarThickness(value)
                                        onResetRequested: root.resetBarThickness()
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.barAdvancedSizeIsCustom()
                                            ? "Custom size is active. Reset returns to the selected size mode."
                                            : "The selected size mode is active. Dragging this control creates a custom override."
                                        color: root.foregroundColor
                                        opacity: 0.5
                                        wrapMode: Text.WordWrap
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                    }
                                }
                            }
                        }

                    }
                }
            }

            Item {
                implicitHeight: animationColumn.implicitHeight
                ColumnLayout {
                    id: animationColumn
                    width: parent.width
                    spacing: Style.space(8)
                    Text { Layout.fillWidth: true; text: "MOTION LAB"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
                    Text { Layout.fillWidth: true; text: "A semantic compositor recipe. Owner: Hyprland. Fallback: Native. These controls stage a MotionSpec; Test Live still applies the real Hyprland theme transaction, and Demo remains an explicit separate action. Continuous loops and experimental effects are intentionally outside this first slice."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(3); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "MOTION STYLE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.motionPresetOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.description; selected: root.animationsStyle.preset === modelData.key; onClicked: root.chooseMotionPreset(modelData.key) } } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { Layout.fillWidth: true; text: "Open and close have separate character: opening can be expressive while closing stays decisive."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "popin", title: "Open · Pop" }, { key: "slide", title: "Open · Slide" }, { key: "gnomed", title: "Open · Gnome" }, { key: "fade", title: "Open · Fade" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland window entrance style."; selected: root.animationsStyle.windowOpen === modelData.key; onClicked: root.chooseAnimations("windowOpen", modelData.key) } } }
                    GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "popin", title: "Close · Pop" }, { key: "slide", title: "Close · Slide" }, { key: "gnomed", title: "Close · Gnome" }, { key: "fade", title: "Close · Fade" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland window exit style."; selected: root.animationsStyle.windowClose === modelData.key; onClicked: root.chooseAnimations("windowClose", modelData.key) } } }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Move · Native" }, { key: "smooth", title: "Move · Smooth" }, { key: "quick", title: "Move · Precision" }, { key: "digital", title: "Move · Digital" }, { key: "spring", title: "Move · Spring" }, { key: "none", title: "Move · Off" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Tiled rearrangement, dragging, and resize response."; selected: root.animationsStyle.windowMove === modelData.key; onClicked: root.chooseAnimations("windowMove", modelData.key) } } }
                    ShellRangeField { Layout.fillWidth: true; label: "Window starting scale"; description: "Pop-in styles start at this percentage of the final size."; value: String(root.animationsStyle.windowAmount || 87); fallback: 87; minimum: 60; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowAmount", value); onResetRequested: root.editMotionNumber("windowAmount", fallback) }
                    ShellRangeField { Layout.fillWidth: true; label: "Window entrance opacity"; description: "Start only the opening window at this opacity, then release it to the user's normal opacity. Cyberpunk uses 82%."; value: String(root.animationsStyle.windowOpacity !== undefined ? root.animationsStyle.windowOpacity : 100); fallback: 100; minimum: 60; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowOpacity", value); onResetRequested: root.editMotionNumber("windowOpacity", fallback) }
                    ShellRangeField { Layout.fillWidth: true; label: "Window response"; description: "Hyprland animation duration scale; higher values feel slower."; value: String(root.animationsStyle.windowSpeed || 4); fallback: 4; minimum: 1; maximum: 10; step: 1; decimals: 0; suffix: " ds"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("windowSpeed", value); onResetRequested: root.editMotionNumber("windowSpeed", fallback) }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "WORKSPACES"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.workspaceAnimationOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Workspace switching transition owned by Hyprland."; selected: root.animationsStyle.workspace === modelData.key; onClicked: root.chooseAnimations("workspace", modelData.key) } } }
                    GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "horizontal", title: "Horizontal" }, { key: "vertical", title: "Vertical" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Direction for slide and slide-fade travel."; selected: root.animationsStyle.workspaceAxis === modelData.key; onClicked: root.chooseAnimations("workspaceAxis", modelData.key) } } }
                    ShellRangeField { Layout.fillWidth: true; label: "Workspace travel"; description: "Percentage of the screen used by slide and slide-fade transitions."; value: String(root.animationsStyle.workspaceTravel || 18); fallback: 18; minimum: 5; maximum: 100; step: 1; decimals: 0; suffix: "%"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editMotionNumber("workspaceTravel", value); onResetRequested: root.editMotionNumber("workspaceTravel", fallback) }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "FOCUS / SHELL"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Focus · Native" }, { key: "quick", title: "Focus · Quick" }, { key: "smooth", title: "Focus · Smooth" }, { key: "digital", title: "Focus · Digital" }, { key: "none", title: "Focus · Off" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.key === "digital" ? "A mechanical neon border, shadow, and dim response without retriggering the desktop shader." : "Focus fade, dim, and shadow transitions."; selected: root.animationsStyle.focus === modelData.key; onClicked: root.chooseAnimations("focus", modelData.key) } } }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "inherit", title: "Special · Native" }, { key: "fade", title: "Special · Fade" }, { key: "slide", title: "Special · Slide" }, { key: "slidevert", title: "Special · Vertical" }, { key: "slidefade", title: "Special · Slide + fade" }, { key: "none", title: "Special · Off" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Scratchpad / special workspace transition."; selected: root.animationsStyle.specialWorkspace === modelData.key; onClicked: root.chooseAnimations("specialWorkspace", modelData.key) } } }
                    GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "native", title: "Layers · Native" }, { key: "fade", title: "Layers · Fade" }, { key: "slide", title: "Layers · Slide" }, { key: "none", title: "Layers · Off" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Hyprland layer/shell entrance and exit motion."; selected: root.animationsStyle.layers === modelData.key; onClicked: root.chooseAnimations("layers", modelData.key) } } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "BORDER MOTION"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: root.borderAnimationOptions; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Animated focus-border treatment."; selected: root.animationsStyle.border === modelData.key; onClicked: root.chooseAnimations("border", modelData.key) } } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
					Text { Layout.fillWidth: true; text: "SCREEN EFFECT"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
					Text { Layout.fillWidth: true; text: "Finite Hyprland screen shaders. They activate only around selected events, restore the previous shader afterward, and remain idle between signals."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
					GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [
						{ key: "none", title: "Effect · Off", description: "Keep the whole desktop stable." },
						{ key: "rgb-tear", title: "RGB Tear", description: "Cyberpunk horizontal tearing and chromatic separation." },
						{ key: "spectral-shift", title: "Spectral Shift", description: "Smooth diagonal prism refraction without tearing." },
						{ key: "phosphor-scan", title: "Phosphor Scan", description: "CRT scanlines, a sync sweep, and restrained phosphor lift." }
					]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: modelData.description; selected: root.effectiveScreenEffect().id === modelData.key; onClicked: root.chooseScreenEffect(modelData.key) } } }
					GridLayout { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "low", title: "Low" }, { key: "medium", title: "Medium" }, { key: "strong", title: "Strong" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: "Strength · " + modelData.title; description: "Bounded shader intensity."; selected: root.effectiveScreenEffect().strength === modelData.key; onClicked: root.chooseEffectStrength(modelData.key) } } }
					ShellRangeField { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; label: "Signal duration"; description: "How long the finite screen effect remains active after an event."; value: String(root.effectiveScreenEffect().durationMs || 500); fallback: root.effectiveScreenEffect().id === "rgb-tear" ? 1250 : root.effectiveScreenEffect().id === "phosphor-scan" ? 850 : 500; minimum: 100; maximum: 5000; step: 50; decimals: 0; suffix: " ms"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.editEffectDuration(value); onResetRequested: root.editEffectDuration(fallback) }
					Text { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; text: "TRIGGERS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
					GridLayout { Layout.fillWidth: true; visible: root.effectiveScreenEffect().id !== "none"; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [
						{ key: "window-open", title: "Window open" }, { key: "window-close", title: "Window close" }, { key: "workspace", title: "Workspace" },
						{ key: "panel", title: "Panel" }, { key: "notification", title: "Notification" }, { key: "urgent", title: "Urgent" }
					]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Trigger this finite signal."; selected: root.effectiveScreenEffect().triggers.indexOf(modelData.key) >= 0; onClicked: root.toggleEffectTrigger(modelData.key) } } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: Style.space(4); color: Util.alpha(root.foregroundColor, 0.16) }
                    Text { Layout.fillWidth: true; text: "TIMING & ACCESSIBILITY"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(7); rowSpacing: Style.space(7); Repeater { model: [{ key: "bezier", title: "Balanced curve" }, { key: "glass", title: "Glass curve" }, { key: "precision", title: "Precision curve" }, { key: "digital", title: "Digital curve" }, { key: "spring", title: "Spring curve" }]; delegate: DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Reusable curve family for the selected compositor motion."; selected: root.animationsStyle.curve === modelData.key; onClicked: root.chooseAnimations("curve", modelData.key) } } }
                    DesktopOptionCard { Layout.fillWidth: true; compact: true; title: root.animationsStyle.reducedMotion === true ? "Reduced motion · On" : "Reduced motion · Off"; description: "Disable compositor motion while keeping surfaces and layout unchanged."; selected: root.animationsStyle.reducedMotion === true; onClicked: root.chooseAnimations("reducedMotion", !(root.animationsStyle.reducedMotion === true)) }
                }
            }
        }
    }
}
