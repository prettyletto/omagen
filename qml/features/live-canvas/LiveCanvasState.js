.pragma library

function editableColorRoles() {
    return [
        { key: "accent", label: "Accent" },
        { key: "background", label: "Background" },
        { key: "foreground", label: "Foreground" },
        { key: "selection", label: "Selection" }
    ]
}

function advancedColorGroups() {
    return [
        {
            key: "surfaces",
            label: "Surfaces",
            roles: [
                { key: "muted", label: "Muted" },
                { key: "dark_background", label: "Dark background" },
                { key: "darker_background", label: "Deep background" },
                { key: "lighter_background", label: "Light background" }
            ]
        },
        {
            key: "text",
            label: "Text",
            roles: [
                { key: "dark_foreground", label: "Dark text" },
                { key: "light_foreground", label: "Light text" },
                { key: "bright_foreground", label: "Bright text" }
            ]
        },
        {
            key: "terminal",
            label: "Terminal colours",
            roles: [
                { key: "red", label: "Red" },
                { key: "orange", label: "Orange" },
                { key: "yellow", label: "Yellow" },
                { key: "green", label: "Green" },
                { key: "cyan", label: "Cyan" },
                { key: "blue", label: "Blue" },
                { key: "magenta", label: "Magenta" },
                { key: "brown", label: "Brown" }
            ]
        },
        {
            key: "bright-terminal",
            label: "Bright terminal colours",
            roles: [
                { key: "bright_red", label: "Bright red" },
                { key: "bright_yellow", label: "Bright yellow" },
                { key: "bright_green", label: "Bright green" },
                { key: "bright_cyan", label: "Bright cyan" },
                { key: "bright_blue", label: "Bright blue" },
                { key: "bright_magenta", label: "Bright magenta" }
            ]
        }
    ]
}

function copyColors(colors) {
    var next = {}
    for (var key in (colors || {}))
        next[key] = colors[key]
    return next
}

function copyOverrideColors(overrides) {
    var next = {}
    for (var key in (overrides || {}))
        next[key] = String(overrides[key]).toUpperCase()
    return next
}
