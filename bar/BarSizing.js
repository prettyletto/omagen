.pragma library

// Keep the QML bar readers aligned with backend/internal/theme's native bar
// tokens. The native values passed by callers are already resolved Style.bar
// values; named densities use the same base values the backend writes and
// follow Quattro's font scaling when it is enabled.
function baseSize(density, vertical, nativeHorizontal, nativeVertical, scaleWithFont, fontScale) {
    var value
    switch (String(density || "native")) {
    case "compact":
        value = vertical ? 24 : 22
        break
    case "comfortable":
        value = vertical ? 32 : 30
        break
    default:
        return vertical ? Number(nativeVertical) : Number(nativeHorizontal)
    }

    var scale = scaleWithFont === true ? Number(fontScale) : 1
    if (!isFinite(scale) || scale <= 0)
        scale = 1
    return Math.max(1, Math.round(value * scale))
}

function isVertical(spec) {
    var position = String(spec && spec.position || "top")
    return position === "left" || position === "right"
}

function presetDensity(preset) {
    return ["float", "minimal"].indexOf(String(preset || "")) >= 0 ? "compact" : "native"
}

function resolvedBaseSize(spec, nativeHorizontal, nativeVertical, scaleWithFont, fontScale) {
    var value = spec || ({})
    var geometry = value.geometry || ({})
    var thickness = Number(geometry.thickness || 0)
    if (thickness > 0)
        return Math.round(thickness)
    return baseSize(geometry.density, isVertical(value), nativeHorizontal, nativeVertical, scaleWithFont, fontScale)
}

function structuralPadding(spec, padding) {
    var value = spec || ({})
    var topology = String(value.topology || "continuous")
    return topology === "dock" || (topology === "islands" && isVertical(value))
        ? Number(padding || 0) : 0
}

