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

    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null })
    property var animationsStyle: ({ window: "native", workspace: "native", border: "native", borderSpeed: 36, reducedMotion: false })
    property int activeTab: 0

    signal stylesChanged(var shellStyle, var desktopStyle, var barStyle, var animationsStyle)
    signal sectionChanged(int index)

    onActiveTabChanged: root.sectionChanged(root.activeTab)

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
        { key: "native", title: "Native" }, { key: "float", title: "Float" },
        { key: "sections", title: "Sections" }, { key: "glass-islands", title: "Glass islands" },
        { key: "dock", title: "Dock" }, { key: "minimal", title: "Minimal" },
        { key: "split", title: "Split" }, { key: "notch", title: "Notch" }, { key: "rail", title: "Rail" }
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
        if (group === "surface") spec.surface.role = key
        if (group === "density") spec.geometry.density = key
        if (group === "attention") spec.attention.mode = key
        next.spec = spec
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function barSpec() {
        var current = root.barStyle.spec || ({})
        var surface = current.surface || ({})
        var geometry = current.geometry || ({})
        var behavior = current.behavior || ({})
        var motion = current.motion || ({})
        var result = {
            version: 2,
            engine: current.engine || "auto",
            topology: current.topology || (root.barStyle.visibility === "islands" ? "sections" : root.barStyle.form === "docked" ? "sections" : "continuous"),
            position: current.position || "top",
            surface: { role: surface.role || root.barStyle.surface || "native", opacity: surface.opacity !== undefined ? surface.opacity : 1, blur: Number(surface.blur || 0), border_role: surface.border_role || "none", border_opacity: Number(surface.border_opacity || 0), border_width: Number(surface.border_width || 0), shadow: surface.shadow || "none" },
            geometry: { density: geometry.density || root.barStyle.density || "native", thickness: Number(geometry.thickness || 0), edge_offset: Number(geometry.edge_offset || 0), outer_margin: Number(geometry.outer_margin || 0), inner_padding: Number(geometry.inner_padding || 0), section_gap: Number(geometry.section_gap !== undefined ? geometry.section_gap : 8), widget_gap: Number(geometry.widget_gap || 0), radius: Number(geometry.radius || 0), length_mode: geometry.length_mode || "full", length_value: Number(geometry.length_value || 0) },
            attention: { mode: (current.attention && current.attention.mode) || root.barStyle.attention || "semantic" },
            behavior: { visibility: behavior.visibility || "always", exclusive_zone: behavior.exclusive_zone || "reserve", hover_expand: behavior.hover_expand === true, hide_delay_ms: Number(behavior.hide_delay_ms || 500), reveal_delay_ms: Number(behavior.reveal_delay_ms || 50), edge_sensor: Number(behavior.edge_sensor || 3), keep_visible_while_popup_open: behavior.keep_visible_while_popup_open !== false },
            motion: { preset: motion.preset || "native", duration_ms: Number(motion.duration_ms || 180), easing: motion.easing || "out_cubic" }
        }
        return root.normalizeBarSpecEngine(result)
    }

    function barSpecValue(group, fallback) {
        var spec = root.barSpec()
        var value = group === "surface" ? spec.surface.role : group === "density" ? spec.geometry.density : group === "attention" ? spec.attention.mode : spec[group]
        return value || fallback
    }

    function barPresetValue() {
        var topology = root.barSpecValue("topology", "continuous")
        var mapping = { floating: "float", islands: "glass-islands" }
        if (mapping[topology])
            return mapping[topology]
        for (var index = 0; index < root.barPresetOptions.length; index++) {
            if (root.barPresetOptions[index].key === topology)
                return topology
        }
        return "native"
    }

    function normalizeBarSpecEngine(spec) {
        var nativeTopology = ["continuous", "minimal"].indexOf(spec.topology) >= 0
        var surface = spec.surface || ({})
        var geometry = spec.geometry || ({})
        var behavior = spec.behavior || ({})
        var motion = spec.motion || ({})
        var nativeSurface = ["native", "background", "dark", "light", "accent", "transparent"].indexOf(surface.role) >= 0
            && Number(surface.blur || 0) === 0
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
        var nativeBehavior = (behavior.visibility || "always") === "always" && behavior.exclusive_zone === "reserve" && behavior.hover_expand !== true
        var nativeMotion = (motion.preset || "native") === "native"
            && Number(motion.duration_ms !== undefined ? motion.duration_ms : 180) === 180
            && (motion.easing || "out_cubic") === "out_cubic"
        var needsAdapter = !nativeTopology || !nativeSurface || !nativeGeometry || !nativeBehavior || !nativeMotion
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

    function chooseBarSpec(group, key) {
        var spec = root.barSpec()
        if (group === "surface") {
            spec.surface.role = key
            if (key === "transparent") spec.surface.opacity = 0
        } else if (group === "density") {
            spec.geometry.density = key
        } else if (group === "attention") {
            spec.attention.mode = key
        } else {
            spec[group] = key
        }
        if (group === "topology")
            spec.engine = ["continuous", "minimal"].indexOf(key) >= 0 ? "auto" : "omagen"
        root.normalizeBarSpecEngine(spec)
        var next = {
            surface: key === "dark" || key === "light" || key === "accent" ? key : root.barStyle.surface || "native",
            density: spec.geometry.density || root.barStyle.density || "native",
            attention: spec.attention.mode || root.barStyle.attention || "semantic",
            form: ["continuous", "floating", "minimal"].indexOf(spec.topology) >= 0 ? "continuous" : "docked",
            visibility: spec.topology === "sections" || spec.topology === "islands" ? "islands" : root.barStyle.visibility || "native",
            profile: root.barStyle.profile || null,
            spec: spec
        }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseBarPreset(key) {
        var spec = root.barSpec()
        spec.engine = "auto"
        spec.topology = "continuous"
        spec.surface = { role: "native", opacity: 1, blur: 0, border_role: "none", border_opacity: 0, border_width: 0, shadow: "none" }
        spec.geometry = { density: "native", thickness: 0, edge_offset: 0, outer_margin: 0, inner_padding: 0, section_gap: 8, widget_gap: 0, radius: 0, length_mode: "full", length_value: 0 }
        spec.behavior.visibility = "always"
        switch (key) {
        case "float": spec.topology = "floating"; spec.surface = { role: "background", opacity: 0.88, blur: 0, border_role: "foreground", border_opacity: 0.3, border_width: 1, shadow: "raised" }; spec.geometry.edge_offset = 8; spec.geometry.outer_margin = 8; spec.geometry.radius = 14; break
        case "sections": spec.topology = "sections"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "accent", border_opacity: 0.35, border_width: 1, shadow: "flat" }; spec.geometry.section_gap = 10; spec.geometry.radius = 14; break
        case "glass-islands": spec.engine = "omagen"; spec.topology = "islands"; spec.surface = { role: "dark", opacity: 0.72, blur: 18, border_role: "foreground", border_opacity: 0.35, border_width: 1, shadow: "floating" }; spec.geometry.radius = 14; break
        case "dock": spec.engine = "omagen"; spec.topology = "dock"; spec.surface = { role: "dark", opacity: 0.9, blur: 0, border_role: "foreground", border_opacity: 0.25, border_width: 1, shadow: "floating" }; spec.geometry.length_mode = "content"; spec.geometry.radius = 16; spec.behavior.visibility = "auto_hide"; break
        case "minimal": spec.topology = "minimal"; spec.surface = { role: "transparent", opacity: 0, blur: 0, border_role: "none", border_opacity: 0, border_width: 0, shadow: "none" }; spec.geometry.density = "compact"; break
        case "split": spec.engine = "omagen"; spec.topology = "split"; spec.surface.role = "dark"; break
        case "notch": spec.engine = "omagen"; spec.topology = "notch"; spec.surface.role = "dark"; spec.geometry.radius = 14; break
        case "rail": spec.engine = "omagen"; spec.topology = "rail"; spec.position = "left"; spec.surface.role = "dark"; break
        }
        var behavior = root.barStyle.profile && root.barStyle.profile.behavior ? root.barStyle.profile.behavior : ({})
        behavior = JSON.parse(JSON.stringify(behavior))
        behavior.form = ["continuous", "sections", "split", "islands", "dock", "rail"].indexOf(spec.topology) >= 0 ? spec.topology : "continuous"
        behavior.visibility = spec.behavior.visibility === "auto_hide" ? "auto-hide" : "always"
        var profile = { schema_version: 1, ownership: "overlay", implementation: spec.engine === "omagen" ? "adapter" : "native", behavior: behavior }
        var next = { surface: ["native", "dark", "light", "accent"].indexOf(spec.surface.role) >= 0 ? spec.surface.role : "native", density: spec.geometry.density, attention: root.barStyle.attention || "semantic", form: ["continuous", "floating", "minimal"].indexOf(spec.topology) >= 0 ? "continuous" : "docked", visibility: spec.topology === "sections" || spec.topology === "islands" ? "islands" : "native", profile: profile, spec: spec }
        root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
    }

    function chooseBarProfile(group, key) {
        var current = root.barStyle.profile || ({})
        var behavior = JSON.parse(JSON.stringify(current.behavior || ({})))
        behavior[group] = key
        var profile = {
            schema_version: 1,
            ownership: current.ownership || "overlay",
            implementation: current.implementation || "adapter",
            behavior: behavior
        }
        if (group === "form") {
            profile.behavior.form = key
            profile.behavior.visibility = behavior.visibility || "always"
            profile.behavior.reveal = behavior.reveal || "edge"
            profile.behavior.expansion = behavior.expansion || "none"
            profile.behavior.workspace = behavior.workspace || "native"
        }
        var nextSpec = root.barStyle.spec ? root.barSpec() : null
        if (nextSpec) {
            if (group === "form") {
                var topologyByForm = { continuous: "continuous", floating: "floating", sections: "sections", split: "split", islands: "islands", dock: "dock", rail: "rail", minimal: "minimal", notch: "notch" }
                nextSpec.topology = topologyByForm[key] || nextSpec.topology
            } else if (group === "visibility") {
                var visibilityByProfile = { always: "always", "auto-hide": "auto_hide", "fullscreen-only": "fullscreen", intelligent: "hover" }
                nextSpec.behavior.visibility = visibilityByProfile[key] || nextSpec.behavior.visibility
            } else if (group === "expansion") {
                nextSpec.behavior.hover_expand = key !== "none"
            }
            root.normalizeBarSpecEngine(nextSpec)
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
                return spec.topology === "continuous" || spec.topology === "floating" || spec.topology === "minimal" ? "continuous" : spec.topology
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
        if (group === "form") return "Continuous keeps one native surface; Split, Islands, Dock, and Rail are theme-bounded additive compositions."
        if (group === "visibility") return "Visibility is staged with the theme profile and restored with the user's bar state."
        if (group === "expansion") return "Choose whether the themed bar expands fixed content on hover, focus, or available space."
        if (group === "workspace") return "Workspace presentation is a theme profile; native workspace actions remain authoritative."
        if (group === "reveal") return "How a hidden theme-bound bar is summoned without changing the native bar's ownership."
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
            implicitHeight: root.activeTab === 0 ? windowColumn.implicitHeight : root.activeTab === 1 ? shellPage.implicitHeight : root.activeTab === 2 ? barColumn.implicitHeight : animationColumn.implicitHeight

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
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Shape the bar in groups. Native widgets and placement stay with Quattro; this profile only stages the theme-bound surface behavior."
                        color: Color.foreground
                        opacity: 0.62
                        wrapMode: Text.WordWrap
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }

                    BorderSurface {
                        Layout.fillWidth: true
                        implicitHeight: barSummaryColumn.implicitHeight + Style.space(20)
                        color: Util.alpha(Color.accent, 0.09)
                        radius: Math.max(Style.space(6), Style.cornerRadius / 2)
                        borderSpec: Border.flat(Util.alpha(Color.accent, 0.55), 1)

                        ColumnLayout {
                            id: barSummaryColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(10)
                            spacing: Style.space(3)

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: ["continuous", "minimal"].indexOf(root.barSpecValue("topology", "continuous")) >= 0 && root.barSpec().engine !== "omagen" && !root.barStyle.profile
                                        ? "NATIVE BAR · INHERITED" : "THEME PROFILE · ADAPTER"
                                    color: Color.accent
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    font.letterSpacing: 0.65
                                }
                                Text {
                                    text: root.barSpecValue("topology", "continuous").toUpperCase()
                                    color: Color.foreground
                                    opacity: 0.78
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.barStyle.profile
                                    ? "Changes are reversible and scoped to this theme session."
                                    : "No theme-owned bar behavior is staged yet."
                                color: Color.foreground
                                opacity: 0.62
                                wrapMode: Text.WordWrap
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Preset"
                        subtitle: "Compose a BarSpec without changing widget ownership"
                        options: root.barPresetOptions
                        selectedKey: root.barPresetValue()
                        optionDescriptions: root.barOptionDescriptions("preset", root.barPresetOptions)
                        onChoiceSelected: root.chooseBarPreset(key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Topology"
                        subtitle: "Native continuous/minimal; additive adapter for other shapes"
                        options: root.barTopologyOptions
                        selectedKey: root.barSpecValue("topology", "continuous")
                        optionDescriptions: root.barOptionDescriptions("topology", root.barTopologyOptions)
                        onChoiceSelected: root.chooseBarSpec("topology", key)
                    }

                    BarSpecControls {
                        Layout.fillWidth: true
                        spec: root.barSpec()
                        onSpecEdited: function(spec) {
                            root.normalizeBarSpecEngine(spec)
                            var next = {
                                surface: root.barStyle.surface || "native",
                                density: root.barStyle.density || "native",
                                attention: root.barStyle.attention || "semantic",
                                form: root.barStyle.form || "continuous",
                                visibility: root.barStyle.visibility || "native",
                                profile: root.barStyle.profile || null,
                                spec: spec
                            }
                            root.stylesChanged(root.shellStyle, root.desktopStyle, next, root.animationsStyle)
                        }
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Native surface"
                        subtitle: "Quattro token readers"
                        options: root.barSurfaceOptions
                        selectedKey: root.barSpecValue("surface", "native")
                        optionDescriptions: root.barOptionDescriptions("surface", root.barSurfaceOptions)
                        onChoiceSelected: root.chooseBar("surface", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Density"
                        subtitle: "Spacing and height"
                        options: root.barDensityOptions
                        selectedKey: root.barSpecValue("density", "native")
                        optionDescriptions: root.barOptionDescriptions("density", root.barDensityOptions)
                        onChoiceSelected: root.chooseBar("density", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Attention"
                        subtitle: "Warnings and status"
                        options: root.attentionOptions
                        selectedKey: root.barSpecValue("attention", "semantic")
                        optionDescriptions: root.barOptionDescriptions("attention", root.attentionOptions)
                        onChoiceSelected: root.chooseBar("attention", key)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "THEME-BOUNDED BEHAVIOR"
                        color: Color.foreground
                        opacity: 0.5
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Composition"
                        subtitle: "Continuous, split, islands, dock, or rail"
                        options: root.barProfileFormOptions
                        selectedKey: root.barProfileValue("form", "continuous")
                        optionDescriptions: root.barOptionDescriptions("form", root.barProfileFormOptions)
                        onChoiceSelected: root.chooseBarProfile("form", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Visibility"
                        subtitle: "When the themed layer is present"
                        options: root.barProfileVisibilityOptions
                        selectedKey: root.barProfileValue("visibility", "always")
                        optionDescriptions: root.barOptionDescriptions("visibility", root.barProfileVisibilityOptions)
                        onChoiceSelected: root.chooseBarProfile("visibility", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Reveal"
                        subtitle: "How a hidden bar returns"
                        options: root.barProfileRevealOptions
                        selectedKey: root.barProfileValue("reveal", "edge")
                        optionDescriptions: root.barOptionDescriptions("reveal", root.barProfileRevealOptions)
                        onChoiceSelected: root.chooseBarProfile("reveal", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Expansion"
                        subtitle: "Fixed, hover, focus, or adaptive"
                        options: root.barProfileExpansionOptions
                        selectedKey: root.barProfileValue("expansion", "none")
                        optionDescriptions: root.barOptionDescriptions("expansion", root.barProfileExpansionOptions)
                        onChoiceSelected: root.chooseBarProfile("expansion", key)
                    }

                    BarChoiceGroup {
                        Layout.fillWidth: true
                        title: "Workspace presentation"
                        subtitle: "Visual treatment; native actions stay intact"
                        options: root.barProfileWorkspaceOptions
                        selectedKey: root.barProfileValue("workspace", "native")
                        optionDescriptions: root.barOptionDescriptions("workspace", root.barProfileWorkspaceOptions)
                        onChoiceSelected: root.chooseBarProfile("workspace", key)
                    }

                    BorderSurface {
                        Layout.fillWidth: true
                        implicitHeight: barBoundaryColumn.implicitHeight + Style.space(16)
                        color: Util.alpha(Color.foreground, 0.025)
                        radius: Math.max(Style.space(5), Style.cornerRadius / 2)
                        borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.58), 1)

                        ColumnLayout {
                            id: barBoundaryColumn
                            anchors.fill: parent
                            anchors.margins: Style.space(9)
                            spacing: Style.space(2)
                            Text { Layout.fillWidth: true; text: "OWNERSHIP"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.7 }
                            Text { Layout.fillWidth: true; text: "The profile is applied additively and the user's shell.json plus native hidden-bar state are snapshotted for exact restore."; color: Color.foreground; opacity: 0.62; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
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
