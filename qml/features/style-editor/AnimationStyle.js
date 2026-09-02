.pragma library

function motionBase(value) {
    var a = value || ({})
    var glitch = a.glitch || "none"
    if (glitch === "flicker")
        glitch = "medium"
    var rawEffect = a.screenEffect || a.screen_effect || null
    var screenEffect = rawEffect ? {
        id: rawEffect.id || "none",
        strength: rawEffect.strength || "medium",
        durationMs: Number(rawEffect.durationMs !== undefined ? rawEffect.durationMs : rawEffect.duration_ms || 0),
        triggers: (rawEffect.triggers || []).slice(),
        coalesce: rawEffect.coalesce !== false
    } : null
    return {
        version: Number(a.version || 1), preset: a.preset || "native",
        window: a.window || "native",
        windowOpen: a.windowOpen || a.window_open || "popin",
        windowClose: a.windowClose || a.window_close || "popin",
        windowMove: a.windowMove || a.window_move || "native",
        windowAmount: Number(a.windowAmount !== undefined ? a.windowAmount : a.window_amount || 87),
        windowOpacity: Number(a.windowOpacity !== undefined ? a.windowOpacity : a.window_opacity !== undefined ? a.window_opacity : 100),
        windowSpeed: Number(a.windowSpeed !== undefined ? a.windowSpeed : a.window_speed || 4),
        workspace: a.workspace || "native",
        workspaceAxis: a.workspaceAxis || a.workspace_axis || "horizontal",
        workspaceTravel: Number(a.workspaceTravel !== undefined ? a.workspaceTravel : a.workspace_travel || 18),
        specialWorkspace: a.specialWorkspace || a.special_workspace || "inherit",
        focus: a.focus || "native", layers: a.layers || "native", curve: a.curve || "bezier",
        border: a.border || "native",
        borderSpeed: Number(a.borderSpeed || a.border_speed || 36),
        glitch: glitch,
        screenEffect: screenEffect,
        reducedMotion: a.reducedMotion === true || a.reduced_motion === true
    }
}

function effectiveScreenEffect(value) {
    var current = motionBase(value)
    if (current.screenEffect)
        return current.screenEffect
    if (current.glitch !== "none")
        return {
            id: "rgb-tear", strength: current.glitch, durationMs: 1250,
            triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"],
            coalesce: true
        }
    return { id: "none", strength: "medium", durationMs: 0, triggers: [], coalesce: true }
}

function defaultEffect(id, strength) {
    if (id === "spectral-shift")
        return { id: id, strength: strength || "medium", durationMs: 500, triggers: ["window-open", "window-close", "workspace", "panel"], coalesce: true }
    if (id === "phosphor-scan")
        return { id: id, strength: strength || "medium", durationMs: 850, triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"], coalesce: true }
    if (id === "retro-vhs")
        return { id: id, strength: strength || "medium", durationMs: 1100, triggers: ["window-open", "window-close", "workspace", "panel"], coalesce: true }
    return { id: "rgb-tear", strength: strength || "medium", durationMs: 1250, triggers: ["window-open", "window-close", "workspace", "panel", "notification", "urgent"], coalesce: true }
}

function chooseScreenEffect(value, id) {
    var next = motionBase(value)
    var current = effectiveScreenEffect(value)
    next.preset = "custom"
    if (id === "none") {
        next.glitch = "none"
        next.screenEffect = null
    } else if (id === "rgb-tear") {
        next.glitch = current.strength || "medium"
        next.screenEffect = null
    } else {
        next.glitch = "none"
        next.screenEffect = defaultEffect(id, current.strength)
    }
    return next
}

function chooseEffectStrength(value, strength) {
    var next = motionBase(value)
    var effect = effectiveScreenEffect(value)
    next.preset = "custom"
    if (effect.id === "rgb-tear") {
        next.glitch = strength
        next.screenEffect = null
    } else if (effect.id !== "none") {
        effect.strength = strength
        next.glitch = "none"
        next.screenEffect = effect
    }
    return next
}

function editEffectDuration(value, duration) {
    var next = motionBase(value)
    var effect = effectiveScreenEffect(value)
    if (effect.id === "none")
        return null
    effect.durationMs = Math.max(100, Math.min(5000, Math.round(Number(duration))))
    next.preset = "custom"
    next.glitch = "none"
    next.screenEffect = effect
    return next
}

function toggleEffectTrigger(value, trigger) {
    var next = motionBase(value)
    var effect = effectiveScreenEffect(value)
    if (effect.id === "none")
        return null
    var index = effect.triggers.indexOf(trigger)
    if (index >= 0)
        effect.triggers.splice(index, 1)
    else
        effect.triggers.push(trigger)
    next.preset = "custom"
    next.glitch = "none"
    next.screenEffect = effect
    return next
}

function chooseMotionPreset(value, name) {
    var next = motionBase(value)
    next.preset = name
    next.window = "native"; next.windowOpen = "popin"; next.windowClose = "popin"; next.windowMove = "native"; next.windowAmount = 87; next.windowOpacity = 100; next.windowSpeed = 4
    next.workspace = "native"; next.workspaceAxis = "horizontal"; next.workspaceTravel = 18; next.specialWorkspace = "inherit"; next.focus = "native"; next.layers = "native"; next.curve = "bezier"; next.border = "native"; next.borderSpeed = 36; next.glitch = "none"; next.screenEffect = null
    if (name === "snappy") {
        next.window = "snappy"; next.workspace = "fade"; next.windowMove = "quick"; next.windowAmount = 97; next.windowSpeed = 1; next.workspaceTravel = 5; next.focus = "quick"; next.layers = "fade"; next.curve = "precision"
    } else if (name === "smooth") {
        next.window = "smooth"; next.workspace = "slidefade"; next.windowMove = "smooth"; next.windowAmount = 82; next.windowSpeed = 4; next.workspaceTravel = 22; next.specialWorkspace = "fade"; next.focus = "smooth"; next.layers = "fade"; next.curve = "glass"
    } else if (name === "spring") {
        next.window = "spring"; next.workspace = "slidefade"; next.windowMove = "spring"; next.curve = "spring"; next.workspaceTravel = 18; next.focus = "smooth"; next.layers = "fade"
    } else if (name === "cinematic") {
        next.window = "cinematic"; next.windowClose = "gnomed"; next.workspace = "slidefade"; next.windowAmount = 76; next.windowSpeed = 5; next.workspaceTravel = 28; next.specialWorkspace = "slide"; next.focus = "smooth"; next.layers = "slide"
    } else if (name === "minimal") {
        next.window = "minimal"; next.windowOpen = "fade"; next.windowClose = "fade"; next.windowMove = "none"; next.workspace = "fade"; next.windowAmount = 100; next.windowSpeed = 1; next.workspaceTravel = 5; next.focus = "quick"; next.layers = "fade"; next.curve = "precision"
    } else if (name === "cyberpunk") {
        next.window = "digital"; next.windowOpen = "gnomed"; next.windowClose = "slide"; next.windowMove = "digital"; next.workspace = "slide"; next.windowAmount = 94; next.windowOpacity = 82; next.windowSpeed = 2; next.workspaceTravel = 12; next.specialWorkspace = "slidevert"; next.focus = "digital"; next.layers = "slide"; next.curve = "digital"; next.border = "static"; next.glitch = "medium"
    }
    return next
}

function chooseAnimations(value, group, key) {
    var next = motionBase(value)
    next[group] = key
    next.preset = "custom"
    return next
}

function editMotionNumber(value, group, number) {
    var next = motionBase(value)
    next.preset = "custom"
    next[group] = Number(number)
    return next
}
