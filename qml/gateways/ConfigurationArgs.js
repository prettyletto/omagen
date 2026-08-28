.pragma library

function appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
    if (!shellStyle)
        return;
    args.push("--shell-style", shellStyle.surface, shellStyle.detail, shellStyle.tooltip, shellStyle.notifications,
              "--desktop-style", desktopStyle.borderStyle, desktopStyle.borderSize,
              desktopStyle.borderSizeMode || desktopStyle.border_size_mode || "default",
              desktopStyle.shape, desktopStyle.spacing, desktopStyle.depth, desktopStyle.inactiveStyle,
              "--bar-style", barStyle.surface, barStyle.density, barStyle.attention, barStyle.form, barStyle.visibility,
              "--window-active-style", desktopStyle.activeStyle || desktopStyle.active_style || "native",
              "--shell-preset", shellStyle.preset || "default");
    if (shellStyle.overrides && Object.keys(shellStyle.overrides).length > 0)
        args.push("--shell-overrides-json", JSON.stringify(shellStyle.overrides));
    if (barStyle.profile)
        args.push("--bar-profile-json", JSON.stringify(barStyle.profile));
    if (barStyle.spec)
        args.push("--bar-spec-json", JSON.stringify(barStyle.spec));
    if (animationsStyle)
        args.push("--animations-json", JSON.stringify(animationsStyle));
    if (lookFeel)
        args.push("--look-feel-json", JSON.stringify({
            schema_version: Number(lookFeel.schemaVersion !== undefined ? lookFeel.schemaVersion : lookFeel.schema_version || 1),
            preset: lookFeel.preset || "omarchy-native",
            preset_revision: Number(lookFeel.presetRevision !== undefined ? lookFeel.presetRevision : lookFeel.preset_revision || 1),
            customized: lookFeel.customized || ({})
        }));
    if (terminalTranslucency)
        args.push("--terminal-json", JSON.stringify({
            schema_version: Number(terminalTranslucency.schemaVersion !== undefined ? terminalTranslucency.schemaVersion : terminalTranslucency.schema_version || 1),
            mode: terminalTranslucency.mode || "preserve",
            opacity: Number(terminalTranslucency.opacity !== undefined ? terminalTranslucency.opacity : 1),
            cell_mode: terminalTranslucency.cellMode || terminalTranslucency.cell_mode || "background"
        }));
}
