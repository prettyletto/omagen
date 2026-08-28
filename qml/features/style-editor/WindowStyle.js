.pragma library

function borderSliderPosition(borderSize) {
    if (borderSize < 0)
        return 0
    if (borderSize === 0)
        return 1
    return Math.max(2, Math.min(13, 1 + borderSize / 2))
}

function borderSizeFromSlider(position) {
    var snapped = Math.round(position)
    if (snapped <= 0)
        return -1
    if (snapped === 1)
        return 0
    return Math.min(24, (snapped - 1) * 2)
}

function copy(value) {
    value = value || ({})
    return {
        borderStyle: value.borderStyle || value.border_style || "solid",
        borderSize: value.borderSize !== undefined ? Number(value.borderSize) : -1,
        borderSizeMode: value.borderSizeMode || value.border_size_mode || (value.borderSize === 0 ? "none" : value.borderSize > 0 ? "fixed" : "default"),
        borderSpeed: Number(value.borderSpeed || value.border_speed || 36),
        shape: value.shape || "native",
        spacing: value.spacing || "native",
        depth: value.depth || "native",
        activeStyle: value.activeStyle || value.active_style || "native",
        inactiveStyle: value.inactiveStyle || value.inactive_style || "native"
    }
}

function choose(value, group, key) {
    var next = copy(value)
    next[group] = key
    if (group === "borderSize")
        next.borderSizeMode = key < 0 ? "default" : key === 0 ? "none" : "fixed"
    return next
}
