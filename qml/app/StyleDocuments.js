.pragma library

function normalizeShellStyle(value) {
    value = value || ({})
    var preset = value.preset || "default"
    var surface = value.surface || "flat"
    var detail = value.detail || "native"
    var tooltip = value.tooltip || "native"
    var notifications = value.notifications || "native"
    var overrides = {}
    for (var key in (value.overrides || {}))
        overrides[key] = String(value.overrides[key])
    return {
        preset: preset,
        surface: surface,
        detail: detail,
        tooltip: tooltip,
        notifications: notifications,
        overrides: overrides
    }
}

function normalizeDesktopStyle(value) {
    value = value || ({})
    var border = value.borderStyle || value.border_style || "solid"
    if (border === "split") border = "split_top"
    var borderSize = Number(value.borderSize !== undefined ? value.borderSize : value.border_size)
    var borderSizeMode = value.borderSizeMode || value.border_size_mode || ""
    if (!isFinite(borderSize)) borderSize = -1
    if (borderSizeMode === "")
        borderSizeMode = borderSize === 0 ? "default" : borderSize < 0 ? "default" : "fixed"
    if (borderSizeMode === "default") borderSize = -1
    else if (borderSizeMode === "none") borderSize = 0
    else if (borderSizeMode === "fixed") {
        if (borderSize < 1 || borderSize > 24) { borderSize = -1; borderSizeMode = "default" }
    } else { borderSize = -1; borderSizeMode = "default" }
    var borderSpeed = Number(value.borderSpeed !== undefined ? value.borderSpeed : value.border_speed)
    if (!isFinite(borderSpeed) || borderSpeed < 10 || borderSpeed > 100) borderSpeed = 36
    var windowOpacity = Number(value.windowOpacity !== undefined ? value.windowOpacity : value.window_opacity)
    if (!isFinite(windowOpacity) || windowOpacity < 0 || windowOpacity > 100) windowOpacity = 100
    return { borderStyle: border, borderSize: borderSize, borderSizeMode: borderSizeMode, borderSpeed: borderSpeed, windowOpacity: Math.round(windowOpacity), shape: value.shape || "native", spacing: value.spacing || "native", depth: value.depth || "native", activeStyle: value.activeStyle || value.active_style || "native", inactiveStyle: value.inactiveStyle || value.inactive_style || "native" }
}

function normalizeAnimationsStyle(value) {
    value = value || ({})
    var borderSpeed = Number(value.borderSpeed !== undefined ? value.borderSpeed : value.border_speed)
    if (!isFinite(borderSpeed) || borderSpeed < 10 || borderSpeed > 100) borderSpeed = 36
    var windowAmount = Number(value.windowAmount !== undefined ? value.windowAmount : value.window_amount)
    if (!isFinite(windowAmount) || windowAmount < 60 || windowAmount > 100) windowAmount = 87
    var windowOpacity = Number(value.windowOpacity !== undefined ? value.windowOpacity : value.window_opacity)
    if (!isFinite(windowOpacity) || windowOpacity < 60 || windowOpacity > 100) windowOpacity = 100
    var windowSpeed = Number(value.windowSpeed !== undefined ? value.windowSpeed : value.window_speed)
    if (!isFinite(windowSpeed) || windowSpeed < 1 || windowSpeed > 10) windowSpeed = 4
    var workspaceTravel = Number(value.workspaceTravel !== undefined ? value.workspaceTravel : value.workspace_travel)
    if (!isFinite(workspaceTravel) || workspaceTravel < 5 || workspaceTravel > 100) workspaceTravel = 18
    var glitch = value.glitch || "none"
    if (glitch === "flicker") glitch = "medium"
    var rawEffect = value.screenEffect || value.screen_effect || null
    var screenEffect = rawEffect ? {
        id: rawEffect.id || "none",
        strength: rawEffect.strength || "medium",
        durationMs: Number(rawEffect.durationMs !== undefined ? rawEffect.durationMs : rawEffect.duration_ms || 0),
        triggers: rawEffect.triggers || [],
        coalesce: rawEffect.coalesce !== false
    } : null
    return {
        version: Number(value.version || 1),
        preset: value.preset || "native",
        window: value.window || "native",
        windowOpen: value.windowOpen || value.window_open || "popin",
        windowClose: value.windowClose || value.window_close || "popin",
        windowMove: value.windowMove || value.window_move || "native",
        windowAmount: windowAmount,
        windowOpacity: windowOpacity,
        windowSpeed: windowSpeed,
        workspace: value.workspace || "native",
        workspaceAxis: value.workspaceAxis || value.workspace_axis || "horizontal",
        workspaceTravel: workspaceTravel,
        specialWorkspace: value.specialWorkspace || value.special_workspace || "inherit",
        focus: value.focus || "native",
        layers: value.layers || "native",
        curve: value.curve || "bezier",
        border: value.border || "native",
        borderSpeed: borderSpeed,
        glitch: glitch,
        screenEffect: screenEffect,
        reducedMotion: value.reducedMotion === true || value.reduced_motion === true
    }
}

function normalizeBarStyle(value) {
    value = value || ({})
    return { surface: value.surface || "native", density: value.density || "native", attention: value.attention || "semantic", form: value.form || "continuous", visibility: value.visibility || "native", profile: value.profile || null, spec: value.spec || null }
}

// BarSpec has richer topologies than the legacy five-field bar document. Keep
// the compatibility field constrained to the native contract while the full
// topology remains available in spec/profile.
function legacyBarFormForTopology(topology) {
    return ["continuous", "floating", "minimal"].indexOf(topology) >= 0 ? "continuous" : "docked"
}

function normalizeTerminalTranslucency(value) {
    value = value || ({})
    var opacity = Number(value.opacity !== undefined ? value.opacity : 1)
    if (!isFinite(opacity) || opacity < 0.5 || opacity > 1)
        opacity = 1
    return {
        schemaVersion: Number(value.schemaVersion !== undefined ? value.schemaVersion : value.schema_version || 1),
        mode: value.mode || "preserve",
        opacity: opacity,
        cellMode: value.cellMode || value.cell_mode || "background"
    }
}

function copyLookFeelDocument(value) {
    value = value || ({})
    return {
        schemaVersion: Number(value.schemaVersion !== undefined ? value.schemaVersion : value.schema_version || 1),
        preset: value.preset || "omarchy-native",
        presetRevision: Number(value.presetRevision !== undefined ? value.presetRevision : value.preset_revision || 1),
        customized: value.customized || ({})
    }
}

function normalizedLookFeelRecipe(composition) {
    return {
        window: normalizeDesktopStyle(composition.window),
        shell: normalizeShellStyle(composition.shell),
        bar: normalizeBarStyle(composition.bar),
        animations: normalizeAnimationsStyle(composition.animations),
        terminal: normalizeTerminalTranslucency(composition.terminal)
    }
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function copyValue(value) {
    if (Array.isArray(value)) {
        var array = []
        for (var index = 0; index < value.length; ++index)
            array.push(copyValue(value[index]))
        return array
    }
    if (isObject(value)) {
        var object = {}
        for (var key in value)
            if (Object.prototype.hasOwnProperty.call(value, key))
                object[key] = copyValue(value[key])
        return object
    }
    return value
}

// Editor signals may carry a complete document or only the field that changed.
// Merge objects recursively at this boundary so a partial update cannot turn
// sibling settings back into normalizer defaults. Arrays and explicit nulls
// remain replacements: clearing a list or nested document must still work.
function mergeStyleDocument(current, incoming) {
    var result = isObject(current) ? copyValue(current) : ({})
    if (!isObject(incoming))
        return result
    for (var key in incoming) {
        if (!Object.prototype.hasOwnProperty.call(incoming, key))
            continue
        var value = incoming[key]
        result[key] = isObject(result[key]) && isObject(value)
            ? mergeStyleDocument(result[key], value)
            : copyValue(value)
    }
    return result
}

function styleJson(value) {
    return JSON.stringify(value || ({}))
}

function field(value, camel, snake, fallback) {
    value = value || ({})
    if (value[camel] !== undefined)
        return value[camel]
    if (value[snake] !== undefined)
        return value[snake]
    return fallback
}

// The editor keeps ergonomic camelCase documents, while the Go backend's
// durable JSON contract is snake_case. Keep this conversion at the boundary
// so a saved local recipe retains every staged advanced value.
function serializeLookFeelComposition(composition) {
    composition = composition || ({})
    var window = composition.window || ({})
    var shell = composition.shell || ({})
    var bar = composition.bar || ({})
    var animations = composition.animations || ({})
    var terminal = composition.terminal || ({})
    var rawEffect = field(animations, "screenEffect", "screen_effect", null)
    var screenEffect = rawEffect ? {
        id: field(rawEffect, "id", "id", "none"),
        strength: field(rawEffect, "strength", "strength", "medium"),
        duration_ms: Number(field(rawEffect, "durationMs", "duration_ms", 0)),
        triggers: copyValue(field(rawEffect, "triggers", "triggers", [])),
        coalesce: field(rawEffect, "coalesce", "coalesce", true)
    } : null
    return {
        schema_version: Number(field(composition, "schemaVersion", "schema_version", 1)),
        preset: field(composition, "preset", "preset", "omarchy-native"),
        preset_revision: Number(field(composition, "presetRevision", "preset_revision", 1)),
        customized: copyValue(composition.customized || ({})),
        window: {
            border_style: field(window, "borderStyle", "border_style", "solid"),
            border_size: Number(field(window, "borderSize", "border_size", -1)),
            border_size_mode: field(window, "borderSizeMode", "border_size_mode", "default"),
            border_speed: Number(field(window, "borderSpeed", "border_speed", 36)),
            window_opacity: Number(field(window, "windowOpacity", "window_opacity", 100)),
            shape: field(window, "shape", "shape", "native"),
            spacing: field(window, "spacing", "spacing", "native"),
            depth: field(window, "depth", "depth", "native"),
            active_style: field(window, "activeStyle", "active_style", "native"),
            inactive_style: field(window, "inactiveStyle", "inactive_style", "native")
        },
        shell: {
            preset: field(shell, "preset", "preset", "default"),
            surface: field(shell, "surface", "surface", "flat"),
            detail: field(shell, "detail", "detail", "native"),
            tooltip: field(shell, "tooltip", "tooltip", "native"),
            notifications: field(shell, "notifications", "notifications", "native"),
            overrides: copyValue(shell.overrides || ({}))
        },
        bar: {
            surface: field(bar, "surface", "surface", "native"),
            density: field(bar, "density", "density", "native"),
            attention: field(bar, "attention", "attention", "semantic"),
            form: field(bar, "form", "form", "continuous"),
            visibility: field(bar, "visibility", "visibility", "native"),
            profile: copyValue(bar.profile || null),
            spec: copyValue(bar.spec || null)
        },
        animations: {
            version: Number(field(animations, "version", "version", 1)),
            preset: field(animations, "preset", "preset", "native"),
            window: field(animations, "window", "window", "native"),
            window_open: field(animations, "windowOpen", "window_open", "popin"),
            window_close: field(animations, "windowClose", "window_close", "popin"),
            window_move: field(animations, "windowMove", "window_move", "native"),
            window_amount: Number(field(animations, "windowAmount", "window_amount", 87)),
            window_opacity: Number(field(animations, "windowOpacity", "window_opacity", 100)),
            window_speed: Number(field(animations, "windowSpeed", "window_speed", 4)),
            workspace: field(animations, "workspace", "workspace", "native"),
            workspace_axis: field(animations, "workspaceAxis", "workspace_axis", "horizontal"),
            workspace_travel: Number(field(animations, "workspaceTravel", "workspace_travel", 18)),
            special_workspace: field(animations, "specialWorkspace", "special_workspace", "inherit"),
            focus: field(animations, "focus", "focus", "native"),
            layers: field(animations, "layers", "layers", "native"),
            curve: field(animations, "curve", "curve", "bezier"),
            border: field(animations, "border", "border", "native"),
            border_speed: Number(field(animations, "borderSpeed", "border_speed", 36)),
            glitch: field(animations, "glitch", "glitch", "none"),
            screen_effect: screenEffect,
            reduced_motion: field(animations, "reducedMotion", "reduced_motion", false) === true
        },
        terminal: {
            schema_version: Number(field(terminal, "schemaVersion", "schema_version", 1)),
            mode: field(terminal, "mode", "mode", "preserve"),
            opacity: Number(field(terminal, "opacity", "opacity", 1)),
            cell_mode: field(terminal, "cellMode", "cell_mode", "background")
        }
    }
}
