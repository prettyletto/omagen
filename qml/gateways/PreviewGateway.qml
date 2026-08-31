import QtQuick

Item {
    id: root

    property string executable: ""

    signal applied(string sessionId, string generationId, string variant, string themeName)
    signal applyFailed(string message)

    function styleOverridesPayload(styles) {
        if (!styles)
            return null
        const shell = styles.shell || ({})
        const desktop = styles.desktop || ({})
        const bar = styles.bar || ({})
        const animations = styles.animations || ({})
        const lookFeel = styles.look_feel || styles.lookFeel || null
        const terminal = styles.terminal || styles.terminalTranslucency || null
        return {
            managed_scopes: styles.managedScopes || styles.managed_scopes || [],
            shell: {
                preset: shell.preset || "default",
                surface: shell.surface || "flat",
                detail: shell.detail || "native",
                tooltip: shell.tooltip || "native",
                notifications: shell.notifications || "native",
                overrides: shell.overrides || ({})
            },
            desktop: {
                border_style: desktop.borderStyle || desktop.border_style || "solid",
                border_size: Number(desktop.borderSize !== undefined ? desktop.borderSize : desktop.border_size !== undefined ? desktop.border_size : -1),
                border_size_mode: desktop.borderSizeMode || desktop.border_size_mode || "default",
                border_speed: Number(desktop.borderSpeed !== undefined ? desktop.borderSpeed : desktop.border_speed || 36),
                window_opacity: Number(desktop.windowOpacity !== undefined ? desktop.windowOpacity : desktop.window_opacity !== undefined ? desktop.window_opacity : 100),
                shape: desktop.shape || "native",
                spacing: desktop.spacing || "native",
                depth: desktop.depth || "native",
                active_style: desktop.activeStyle || desktop.active_style || "native",
                inactive_style: desktop.inactiveStyle || desktop.inactive_style || "native"
            },
            bar: {
                surface: bar.surface || "native",
                density: bar.density || "native",
                attention: bar.attention || "semantic",
                form: bar.form || "continuous",
                visibility: bar.visibility || "native",
                profile: bar.profile || null,
                spec: bar.spec || null
            },
            animations: {
                version: Number(animations.version || 1),
                preset: animations.preset || "native",
                window: animations.window || "native",
                window_open: animations.windowOpen || animations.window_open || "popin",
                window_close: animations.windowClose || animations.window_close || "popin",
                window_move: animations.windowMove || animations.window_move || "native",
                window_amount: Number(animations.windowAmount !== undefined ? animations.windowAmount : animations.window_amount !== undefined ? animations.window_amount : 87),
                window_opacity: Number(animations.windowOpacity !== undefined ? animations.windowOpacity : animations.window_opacity !== undefined ? animations.window_opacity : 100),
                window_speed: Number(animations.windowSpeed !== undefined ? animations.windowSpeed : animations.window_speed !== undefined ? animations.window_speed : 4),
                workspace: animations.workspace || "native",
                workspace_axis: animations.workspaceAxis || animations.workspace_axis || "horizontal",
                workspace_travel: Number(animations.workspaceTravel !== undefined ? animations.workspaceTravel : animations.workspace_travel !== undefined ? animations.workspace_travel : 18),
                special_workspace: animations.specialWorkspace || animations.special_workspace || "inherit",
                focus: animations.focus || "native",
                layers: animations.layers || "native",
                curve: animations.curve || "bezier",
                border: animations.border || "native",
                border_speed: Number(animations.borderSpeed !== undefined ? animations.borderSpeed : animations.border_speed || 36),
                glitch: animations.glitch || "none",
                screen_effect: animations.screenEffect || animations.screen_effect || null,
                reduced_motion: animations.reducedMotion === true || animations.reduced_motion === true
            },
            look_feel: lookFeel ? {
                schema_version: Number(lookFeel.schemaVersion !== undefined ? lookFeel.schemaVersion : lookFeel.schema_version || 1),
                preset: lookFeel.preset || "omarchy-native",
                preset_revision: Number(lookFeel.presetRevision !== undefined ? lookFeel.presetRevision : lookFeel.preset_revision || 1),
                customized: lookFeel.customized || ({})
            } : null,
            terminal: terminal ? {
                schema_version: Number(terminal.schemaVersion !== undefined ? terminal.schemaVersion : terminal.schema_version || 1),
                mode: terminal.mode || "preserve",
                opacity: Number(terminal.opacity !== undefined ? terminal.opacity : 1),
                cell_mode: terminal.cellMode || terminal.cell_mode || "background"
            } : null
        }
    }

    function apply(sessionId, generationId, variant, colorOverrides, styles) {
        const args = [root.executable, "preview", "apply", sessionId, generationId, variant]
        if (colorOverrides && Object.keys(colorOverrides).length > 0)
            args.push("--colors-json", JSON.stringify(colorOverrides))
        const payload = root.styleOverridesPayload(styles)
        if (payload)
            args.push("--styles-json", JSON.stringify(payload))
        command.exec(args)
    }

    BackendCommand {
        id: command
        failureFallback: "Failed to apply preview"
        invalidJsonFallback: "Backend returned invalid preview JSON"
        onCompleted: function(result) {
            if (!result.session_id || !result.generation_id || !result.variant) {
                root.applyFailed("Backend returned incomplete preview data")
                return
            }
            root.applied(result.session_id, result.generation_id, result.variant, result.theme_name || "")
        }
        onFailed: root.applyFailed(message)
    }
}
