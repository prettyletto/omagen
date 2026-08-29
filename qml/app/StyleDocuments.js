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
    return { borderStyle: border, borderSize: borderSize, borderSizeMode: borderSizeMode, borderSpeed: borderSpeed, shape: value.shape || "native", spacing: value.spacing || "native", depth: value.depth || "native", activeStyle: value.activeStyle || value.active_style || "native", inactiveStyle: value.inactiveStyle || value.inactive_style || "native" }
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
