import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast
import "../../bar/BarSizing.js" as BarSizing
import "../features/style-editor" as StyleEditor

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
    readonly property int barAutoHideDelayMs: 5000
    readonly property var barAutoHideOptions: [
        { key: "off", title: "Off" }, { key: "on", title: "On" }
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
    readonly property var clockStyleOptions: [
        { key: "native", title: "Native" },
        { key: "neon", title: "Neon Seven-Segment" },
        { key: "matrix", title: "Dot Matrix" },
        { key: "lcd", title: "Retro LCD" }
    ]
    readonly property var barTopologyOptions: [
        { key: "continuous", title: "Continuous" }, { key: "floating", title: "Floating" },
        { key: "sections", title: "Sections" }, { key: "islands", title: "Islands" },
        { key: "dock", title: "Dock" }, { key: "split", title: "Split" },
        { key: "minimal", title: "Minimal" }, { key: "notch", title: "Notch" }, { key: "rail", title: "Rail" }
    ]
    property bool barSizeAdvancedExpanded: false

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
        var clock = current.clock || ({})
        var dock = current.dock || ({})
        var result = {
            version: 2,
            preset: current.preset || (root.barStyle.spec ? "custom" : "native"),
            engine: current.engine || "auto",
            topology: current.topology || (root.barStyle.visibility === "islands" ? "sections" : root.barStyle.form === "docked" ? "sections" : "continuous"),
            position: current.position || "top",
            surface: { treatment: surface.treatment || "preset", role: surface.role || root.barStyle.surface || "native", opacity: surface.opacity !== undefined ? surface.opacity : 1, blur: Number(surface.blur || 0), border_role: surface.border_role || "none", border_opacity: Number(surface.border_opacity || 0), border_width: Number(surface.border_width || 0), shadow: surface.shadow || "none" },
            geometry: { density: geometry.density || root.barStyle.density || "native", thickness: Number(geometry.thickness || 0), edge_offset: Number(geometry.edge_offset || 0), outer_margin: Number(geometry.outer_margin || 0), inner_padding: Number(geometry.inner_padding || 0), section_gap: Number(geometry.section_gap !== undefined ? geometry.section_gap : 8), widget_gap: Number(geometry.widget_gap || 0), radius: Number(geometry.radius || 0), length_mode: geometry.length_mode || "full", length_value: Number(geometry.length_value || 0), alignment: geometry.alignment || "center" },
            attention: { mode: (current.attention && current.attention.mode) || root.barStyle.attention || "semantic" },
            behavior: { visibility: behavior.visibility || "always", exclusive_zone: behavior.exclusive_zone || "reserve", hover_expand: behavior.hover_expand === true, hide_delay_ms: Number(behavior.hide_delay_ms || root.barAutoHideDelayMs), reveal_delay_ms: Number(behavior.reveal_delay_ms || 50), edge_sensor: Number(behavior.edge_sensor || 3), keep_visible_while_popup_open: behavior.keep_visible_while_popup_open !== false },
            regions: {
                left: { mode: regions.left && regions.left.mode ? regions.left.mode : "native" },
                center: { mode: regions.center && regions.center.mode ? regions.center.mode : "native" },
                right: { mode: regions.right && regions.right.mode ? regions.right.mode : "native" }
            },
            workspace: {
                mode: current.workspace && current.workspace.mode ? current.workspace.mode : "native",
                glyphs: current.workspace && current.workspace.glyphs ? current.workspace.glyphs : []
            },
            clock: {
                style: ["native", "neon", "matrix", "lcd"].indexOf(String(clock.style || "native")) >= 0
                    ? String(clock.style || "native") : "native"
            },
            dock: {
                closed: ["workspace", "ellipsis", "clock", "glyph"].indexOf(String(dock.closed || "ellipsis")) >= 0
                    ? String(dock.closed || "ellipsis") : "ellipsis",
                glyph: String(dock.glyph || "✦")
            },
            motion: { preset: motion.preset || "native", duration_ms: Number(motion.duration_ms || 180), easing: motion.easing || "out_cubic" }
        }
        if (result.behavior.visibility === "auto_hide")
            result.behavior.hide_delay_ms = root.barAutoHideDelayMs
        return root.normalizeBarSpecEngine(result)
    }

    function barSpecValue(group, fallback) {
        var spec = root.barSpec()
        var value = group === "surface" ? spec.surface.role : group === "density" ? spec.geometry.density : group === "attention" ? spec.attention.mode : spec[group]
        return value || fallback
    }

    function clockStyleValue() {
        var clock = root.barSpec().clock || ({})
        var style = String(clock.style || "native")
        return ["native", "neon", "matrix", "lcd"].indexOf(style) >= 0 ? style : "native"
    }

    function chooseClockStyle(key) {
        var spec = root.barSpec()
        var style = String(key || "native")
        spec.clock = { style: ["native", "neon", "matrix", "lcd"].indexOf(style) >= 0 ? style : "native" }
        root.publishBarSpec(spec)
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

    function barAutoHideValue() {
        return root.barSpec().behavior.visibility === "auto_hide" ? "on" : "off"
    }

    function chooseBarAutoHide(key) {
        var spec = root.barSpec()
        spec.preset = "custom"
        spec.behavior.visibility = key === "on" ? "auto_hide" : "always"
        spec.behavior.hide_delay_ms = root.barAutoHideDelayMs
        root.publishBarSpec(spec)
    }

    function barIsVertical(spec) {
        var position = String(spec && spec.position || "top")
        return position === "left" || position === "right"
    }

    function barBaseSizeForDensity(density, spec) {
        return BarSizing.baseSize(
            density,
            root.barIsVertical(spec),
            Style.bar.sizeHorizontal,
            Style.bar.sizeVertical,
            Style.barScaleWithFont,
            Style.fontScale
        )
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
        var clock = spec.clock || ({})
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
        var nativeClock = (clock.style || "native") === "native"
        var needsAdapter = !nativeTopology || !nativeSurface || !nativeGeometry || !nativeBehavior || !nativeRegions || !nativeWorkspace || !nativeClock || !nativeMotion
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
            oldBehavior.visibility = spec.behavior.visibility === "auto_hide" ? "auto-hide"
                : spec.behavior.visibility === "fullscreen" ? "fullscreen-only"
                : spec.behavior.visibility === "hover" ? "intelligent" : "always"
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
        spec.preset = key
        spec.engine = "auto"
        spec.topology = "continuous"
        spec.position = "top"
        spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "none", border_opacity: 0, border_width: 0, shadow: "none" }
        spec.geometry = { density: BarSizing.presetDensity(key), thickness: 0, edge_offset: 0, outer_margin: 0, inner_padding: 0, section_gap: 8, widget_gap: 0, radius: 0, length_mode: "full", length_value: 0, alignment: "center" }
        spec.behavior = { visibility: "always", exclusive_zone: "reserve", hover_expand: false, hide_delay_ms: root.barAutoHideDelayMs, reveal_delay_ms: 50, edge_sensor: 3, keep_visible_while_popup_open: true }
        spec.regions = { left: { mode: "native" }, center: { mode: "native" }, right: { mode: "native" } }
        spec.workspace = { mode: "native", glyphs: [] }
        spec.dock = { closed: "ellipsis", glyph: "✦" }
        spec.motion = { preset: "native", duration_ms: 180, easing: "out_cubic" }
        switch (key) {
        case "float": spec.topology = "floating"; spec.surface = { role: "background", opacity: 0.88, blur: 0, border_role: "foreground", border_opacity: 0.3, border_width: 1, shadow: "raised" }; spec.geometry.edge_offset = 8; spec.geometry.outer_margin = 8; spec.geometry.radius = 14; break
        case "float-expanded": spec.topology = "floating"; spec.surface = { role: "background", opacity: 0.88, blur: 0, border_role: "foreground", border_opacity: 0.3, border_width: 1, shadow: "raised" }; spec.geometry.density = "native"; spec.geometry.edge_offset = 8; spec.geometry.outer_margin = 8; spec.geometry.radius = 14; spec.behavior.hover_expand = true; break
        case "sections": spec.topology = "sections"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "accent", border_opacity: 0.35, border_width: 1, shadow: "flat" }; spec.geometry.section_gap = 10; spec.geometry.radius = 14; spec.regions = { left: { mode: "island" }, center: { mode: "island" }, right: { mode: "island" } }; break
        case "islands": spec.engine = "omagen"; spec.topology = "islands"; spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "foreground", border_opacity: 0.35, border_width: 1, shadow: "none" }; spec.geometry.radius = 14; spec.regions = { left: { mode: "island" }, center: { mode: "island" }, right: { mode: "island" } }; break
        case "dock": spec.engine = "omagen"; spec.topology = "dock"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "foreground", border_opacity: 0.25, border_width: 1, shadow: "floating" }; spec.geometry.length_mode = "content"; spec.geometry.alignment = "center"; spec.geometry.radius = 16; spec.behavior.visibility = "auto_hide"; spec.behavior.hover_expand = true; break
        case "minimal": spec.engine = "omagen"; spec.topology = "minimal"; spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "foreground", border_opacity: 0.35, border_width: 1, shadow: "none" }; spec.behavior.hover_expand = true; spec.motion = { preset: "smooth", duration_ms: 260, easing: "out_cubic" }; break
        case "split": spec.engine = "omagen"; spec.topology = "split"; spec.surface.role = "dark"; break
        case "notch": spec.engine = "omagen"; spec.topology = "notch"; spec.surface.role = "dark"; spec.geometry.radius = 14; break
        case "rail": spec.engine = "omagen"; spec.topology = "rail"; spec.position = "left"; spec.surface.role = "dark"; break
        }
		spec.surface.treatment = "preset"
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

    function description(section, group, key) {
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
        if (group === "clock") return "Change the clock face while retaining the native clock's calendar, format cycling, timezone action, and panel routing."
        if (group === "reveal") return "How the replacement bar is summoned while the native bar remains the fallback for unmarked themes."
        return "Native keeps transparency; Show islands exposes the supported docked section surfaces."
    }

    function optionDescription(section, group, key) {
        var descriptions = {
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
                autoHide: {
                    off: "Keep the bar visible until the native bar toggle is used.",
                    on: "Hide the bar after 5 seconds without pointer activity; move to the screen edge to reveal it."
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
                clock: {
                    native: "Keep Omarchy's native clock face and rendering.",
                    neon: "Use beveled seven-segment digits with a theme-accent glow.",
                    matrix: "Use a compact LED dot-matrix face that scales cleanly on vertical rails.",
                    lcd: "Use a restrained retro LCD capsule while keeping date formats readable."
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
            implicitHeight: root.activeTab === 0 ? windowPage.implicitHeight : root.activeTab === 1 ? shellPage.implicitHeight : root.activeTab === 2 ? barColumn.implicitHeight : animationPage.implicitHeight

            Item {
                id: windowPage
                implicitHeight: windowEditor.implicitHeight

                StyleEditor.WindowEditor {
                    id: windowEditor
                    width: parent.width
                    desktopStyle: root.desktopStyle
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    onStyleEdited: root.stylesChanged(root.shellStyle, desktopStyle, root.barStyle, root.animationsStyle)
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
                        text: "Choose a bar preset, clock face, then tune its size. Placement, ordering, input, and clock behavior stay with Quattro."
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
                                    title: "Clock"
                                    subtitle: "Change the face while preserving the native clock behavior"
                                    options: root.clockStyleOptions
                                    selectedKey: root.clockStyleValue()
                                    optionDescriptions: root.barOptionDescriptions("clock", root.clockStyleOptions)
                                    onChoiceSelected: root.chooseClockStyle(key)
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

                                BarChoiceGroup {
                                    Layout.fillWidth: true
                                    title: "Auto hide"
                                    subtitle: "Hide the bar after 5 seconds of idle time"
                                    options: root.barAutoHideOptions
                                    selectedKey: root.barAutoHideValue()
                                    optionDescriptions: root.barOptionDescriptions("autoHide", root.barAutoHideOptions)
                                    onChoiceSelected: root.chooseBarAutoHide(key)
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

                                BarDockControls {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    Layout.minimumHeight: 0
                                    visible: root.barSpec().topology === "dock"
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
                id: animationPage
                implicitHeight: animationsEditor.implicitHeight

                StyleEditor.AnimationsEditor {
                    id: animationsEditor
                    width: parent.width
                    animationsStyle: root.animationsStyle
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    onStyleEdited: root.stylesChanged(root.shellStyle, root.desktopStyle, root.barStyle, animationsStyle)
                }
            }
        }
    }
}
