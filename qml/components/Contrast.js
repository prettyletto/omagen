.pragma library

// Small, dependency-free contrast helpers for controls whose surface is not
// the current shell background (accent buttons, palette swatches, and staged
// colour previews). The native Color singleton intentionally exposes palette
// roles, but it cannot know the arbitrary colour a local control is painting.

function channel(value) {
    var n = Number(value)
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : 0
}

function linear(value) {
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

function luminance(color) {
    if (!color)
        return 0
    return 0.2126 * linear(channel(color.r))
        + 0.7152 * linear(channel(color.g))
        + 0.0722 * linear(channel(color.b))
}

function contrastRatio(first, second) {
    var a = luminance(first)
    var b = luminance(second)
    var light = Math.max(a, b)
    var dark = Math.min(a, b)
    return (light + 0.05) / (dark + 0.05)
}

// Return whichever candidate has the stronger WCAG-style contrast against
// the painted surface. Candidates are normally Color.background and
// Color.foreground so the helper keeps the active theme's text pair intact.
function textFor(surface, darkCandidate, lightCandidate) {
    var dark = darkCandidate || "#000000"
    var light = lightCandidate || "#ffffff"
    return contrastRatio(surface, dark) >= contrastRatio(surface, light) ? dark : light
}

