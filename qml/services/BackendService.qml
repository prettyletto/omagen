import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal sessionBegan(
        string sessionId,
        string originalTheme,
        string backgroundKind,
        string backgroundPath,
        var shellStyle,
        bool extraConfigs,
        var desktopStyle,
        var barStyle,
        var animationsStyle,
        var lookFeel,
        var terminalTranslucency
    )
    signal sessionBeginFailed(string message)
    signal sessionCancelled(string sessionId)
    signal sessionCancelFailed(string message)
    signal sessionResumeChecked(var result)
    signal sessionResumeCheckFailed(string message)
    signal backendReady()
    signal backendUnavailable(string message)
    signal lookFeelCatalogLoaded(var catalog)
    signal lookFeelCatalogFailed(string message)
    signal lookFeelResolved(var composition)
    signal lookFeelResolveFailed(string message)
    signal runtimeStatusLoaded(var status)
    signal runtimeStatusFailed(string message)
    signal runtimeInstalled(string hookPath)
    signal runtimeInstallFailed(string message)
    signal runtimePromptDismissed()
    signal runtimePromptDismissFailed(string message)
    signal sessionRecovered()
    signal sessionRecoverFailed(string message)
    signal generationCompleted(string sessionId, string generationId)
    signal generationFailed(string sessionId, string message)
    signal generationDescribed(string sessionId, string generationId, var variants)
    signal generationDescribeFailed(string sessionId, string message)
    signal generationDiscarded(string sessionId, string generationId)
    signal generationDiscardFailed(string sessionId, string message)
    signal previewApplied(string sessionId, string generationId, string variant, string themeName)
    signal previewApplyFailed(string message)
    signal themeApplied(string sessionId, string generationId, string variant, string themeName)
    signal themeApplyFailed(string message)
    signal demoOpened(string sessionId, string workspace, string monitor, bool reused)
    signal demoOpenFailed(string message)
    signal windowDemoOpened(string sessionId, string workspace, string monitor, bool reused)
    signal windowDemoOpenFailed(string message)
    signal demoReflowed(string sessionId)
    signal demoReflowFailed(string message)
    signal demoClosed(string sessionId, bool closed)
    signal demoCloseFailed(string message)
    signal demoCaptured(string sessionId, string previewPath)
    signal demoCaptureFailed(string message)
    signal protocolSnapshotLoaded(string sessionId, var snapshot)
    signal protocolSnapshotFailed(string sessionId, string message)
    signal protocolNavigationCompleted(string sessionId, var navigation)
    signal protocolNavigationFailed(string sessionId, string message)

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

    function beginSession(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        const args = [root.executable, "session", "begin"];
        appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency);
        sessionBeginProcess.exec(args);
    }

    function cancelSession(sessionId) {
        sessionCancelProcess.exec([
            root.executable,
            "session",
            "cancel",
            sessionId
        ]);
    }
    function checkResumeSession() { resumeProcess.exec([root.executable, "session", "resume"]); }
    function checkBackend() { pingProcess.exec([root.executable, "ping"]); }
    function listLookFeel() { lookFeelCatalogProcess.exec([root.executable, "look-feel", "list"]); }
    function resolveLookFeel(preset) { lookFeelResolveProcess.exec([root.executable, "look-feel", "resolve", preset]); }
    function checkRuntime() { runtimeStatusProcess.exec([root.executable, "runtime", "status"]); }
    function installRuntime() { runtimeInstallProcess.exec([root.executable, "runtime", "install"]); }
    function dismissRuntimePrompt() { runtimePromptDismissProcess.exec([root.executable, "runtime", "dismiss"]); }
    function recoverSession() { recoverProcess.exec([root.executable, "session", "recover"]); }

    function generateTheme(sessionId, imagePath, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        generationProcess.sessionId = sessionId;
        const args = [root.executable, "generate", sessionId, imagePath];
        appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency);
        generationProcess.exec(args);
    }
    function describeGeneration(sessionId, generationId) {
        generationDescribeProcess.sessionId = sessionId;
        generationDescribeProcess.exec([root.executable, "generation", "describe", sessionId, generationId]);
    }
    function discardGeneration(sessionId, generationId) {
        generationDiscardProcess.sessionId = sessionId;
        generationDiscardProcess.exec([root.executable, "generation", "discard", sessionId, generationId]);
    }
    function styleOverridesPayload(styles) {
        if (!styles)
            return null;
        const shell = styles.shell || ({});
        const desktop = styles.desktop || ({});
        const bar = styles.bar || ({});
        const animations = styles.animations || ({});
        const lookFeel = styles.look_feel || styles.lookFeel || null;
        const terminal = styles.terminal || styles.terminalTranslucency || null;
        return {
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
            // Test Live must receive the same complete animation document that
            // generation and Apply receive. Dropping a field here makes a
            // control look editable while previewing a different result.
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
        };
    }

    function applyPreview(sessionId, generationId, variant, colorOverrides, styles) {
        const args = [root.executable, "preview", "apply", sessionId, generationId, variant];
        if (colorOverrides && Object.keys(colorOverrides).length > 0)
            args.push("--colors-json", JSON.stringify(colorOverrides));
        const payload = root.styleOverridesPayload(styles);
        if (payload)
            args.push("--styles-json", JSON.stringify(payload));
        previewProcess.exec(args);
    }
    function applyTheme(sessionId, generationId, variant, name, generateUnlock, capturePreview) {
        const args = [root.executable, "apply", sessionId, generationId, variant, name];
        if (generateUnlock) args.push("--unlock");
        if (capturePreview) args.push("--live-preview");
        applyProcess.exec(args);
    }
    function openDemo(sessionId) { demoOpenProcess.exec([root.executable, "demo", "open", sessionId]); }
    function openWindowDemo(sessionId) { windowDemoOpenProcess.exec([root.executable, "demo", "open-window", sessionId]); }
    function reflowDemo(sessionId) { demoReflowProcess.exec([root.executable, "demo", "reflow", sessionId]); }
    function closeDemo(sessionId) { demoCloseProcess.exec([root.executable, "demo", "close", sessionId]); }
    function captureDemoPreview(sessionId) { demoCaptureProcess.exec([root.executable, "demo", "capture", sessionId]); }
    function inspectProtocol(sessionId) {
        protocolInspectProcess.sessionId = sessionId;
        protocolInspectProcess.exec([root.executable, "protocol", "inspect", sessionId]);
    }
    function navigateProtocolBack(sessionId) {
        protocolBackProcess.sessionId = sessionId;
        protocolBackProcess.exec([root.executable, "protocol", "back", sessionId]);
    }
    function navigateProtocolForward(sessionId) {
        protocolForwardProcess.sessionId = sessionId;
        protocolForwardProcess.exec([root.executable, "protocol", "forward", sessionId]);
    }

    function resetOutputs(stdout, stderr) {
        stdout.reset();
        stderr.reset();
    }

    Process {
        id: pingProcess
        stdout: BoundedOutputParser { id: pingStdout }
        stderr: BoundedOutputParser { id: pingStderr }
        onStarted: root.resetOutputs(pingStdout, pingStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = pingStderr.text.trim();
                root.backendUnavailable(
                    message !== "" ? message : "Omagen backend is unavailable"
                );
                return;
            }
            root.backendReady();
        }
    }

    Process {
        id: lookFeelCatalogProcess
        stdout: BoundedOutputParser { id: lookFeelCatalogStdout }
        stderr: BoundedOutputParser { id: lookFeelCatalogStderr }
        onStarted: root.resetOutputs(lookFeelCatalogStdout, lookFeelCatalogStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.lookFeelCatalogFailed(lookFeelCatalogStderr.text.trim() || "Failed to load Look & Feel presets")
                return
            }
            try {
                const result = JSON.parse(lookFeelCatalogStdout.text)
                if (!Array.isArray(result)) {
                    root.lookFeelCatalogFailed("Backend returned an invalid Look & Feel catalog")
                    return
                }
                root.lookFeelCatalogLoaded(result)
            } catch (error) {
                root.lookFeelCatalogFailed("Backend returned invalid Look & Feel catalog JSON")
            }
        }
    }

    Process {
        id: lookFeelResolveProcess
        stdout: BoundedOutputParser { id: lookFeelResolveStdout }
        stderr: BoundedOutputParser { id: lookFeelResolveStderr }
        onStarted: root.resetOutputs(lookFeelResolveStdout, lookFeelResolveStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.lookFeelResolveFailed(lookFeelResolveStderr.text.trim() || "Failed to resolve Look & Feel preset")
                return
            }
            try {
                const result = JSON.parse(lookFeelResolveStdout.text)
                if (!result || !result.preset || !result.window || !result.shell || !result.bar || !result.animations || !result.terminal) {
                    root.lookFeelResolveFailed("Backend returned an incomplete Look & Feel preset")
                    return
                }
                root.lookFeelResolved(result)
            } catch (error) {
                root.lookFeelResolveFailed("Backend returned invalid Look & Feel preset JSON")
            }
        }
    }

    Process {
        id: runtimeStatusProcess
        stdout: BoundedOutputParser { id: runtimeStatusStdout }
        stderr: BoundedOutputParser { id: runtimeStatusStderr }
        onStarted: root.resetOutputs(runtimeStatusStdout, runtimeStatusStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.runtimeStatusFailed(runtimeStatusStderr.text.trim() || "Failed to inspect Omagen Advanced Runtime")
                return
            }
            try {
                root.runtimeStatusLoaded(JSON.parse(runtimeStatusStdout.text))
            } catch (error) {
                root.runtimeStatusFailed("Backend returned invalid runtime status JSON")
            }
        }
    }

    Process {
        id: runtimeInstallProcess
        stdout: BoundedOutputParser { id: runtimeInstallStdout }
        stderr: BoundedOutputParser { id: runtimeInstallStderr }
        onStarted: root.resetOutputs(runtimeInstallStdout, runtimeInstallStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.runtimeInstallFailed(runtimeInstallStderr.text.trim() || "Failed to install Omagen Advanced Runtime")
                return
            }
            try {
                const result = JSON.parse(runtimeInstallStdout.text)
                if (result.installed !== true || !result.hook_path) {
                    root.runtimeInstallFailed("Backend returned incomplete runtime installation data")
                    return
                }
                root.runtimeInstalled(result.hook_path)
            } catch (error) {
                root.runtimeInstallFailed("Backend returned invalid runtime installation JSON")
            }
        }
    }

    Process {
        id: runtimePromptDismissProcess
        stdout: BoundedOutputParser { id: runtimePromptDismissStdout }
        stderr: BoundedOutputParser { id: runtimePromptDismissStderr }
        onStarted: root.resetOutputs(runtimePromptDismissStdout, runtimePromptDismissStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.runtimePromptDismissFailed(runtimePromptDismissStderr.text.trim() || "Failed to save Omagen runtime setup choice")
                return
            }
            root.runtimePromptDismissed()
        }
    }

    Process {
        id: resumeProcess
        stdout: BoundedOutputParser { id: resumeStdout }
        stderr: BoundedOutputParser { id: resumeStderr }
        onStarted: root.resetOutputs(resumeStdout, resumeStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.sessionResumeCheckFailed(resumeStderr.text.trim() || "Failed to inspect previous session"); return }
            try { root.sessionResumeChecked(JSON.parse(resumeStdout.text)) } catch (error) { root.sessionResumeCheckFailed("Backend returned invalid resume data") }
        }
    }

    Process {
        id: recoverProcess
        stdout: BoundedOutputParser { id: recoverStdout }
        stderr: BoundedOutputParser { id: recoverStderr }
        onStarted: root.resetOutputs(recoverStdout, recoverStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.sessionRecoverFailed(recoverStderr.text.trim() || "Failed to restore previous session"); return }
            root.sessionRecovered()
        }
    }

    Process {
        id: sessionBeginProcess

        stdout: BoundedOutputParser {
            id: sessionBeginStdout
        }

        stderr: BoundedOutputParser {
            id: sessionBeginStderr
        }

        onStarted: root.resetOutputs(sessionBeginStdout, sessionBeginStderr)

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionBeginStderr.text.trim();
                root.sessionBeginFailed(
                    message !== "" ? message : "Failed to begin session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionBeginStdout.text);
                const background = result.original_background || {};
                const sessionId = result.session_id || "";
                const originalTheme = result.original_theme || "";
                const backgroundKind = background.kind || "";
                const backgroundPath = background.path || "";

                if (
                    sessionId === "" ||
                    originalTheme === "" ||
                    backgroundKind === "" ||
                    backgroundPath === ""
                ) {
                    root.sessionBeginFailed(
                        "Backend returned incomplete session data"
                    );
                    return;
                }

                root.sessionBegan(
                    sessionId,
                    originalTheme,
                    backgroundKind,
                    backgroundPath,
                    result.shell_style || ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" }),
                    result.extra_configs === true,
                    result.desktop_style || ({ border_style: "solid", border_size: -1, border_size_mode: "default", border_speed: 36, shape: "native", spacing: "native", depth: "native", active_style: "native", inactive_style: "native" }),
                    result.bar_style || ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null }),
                    result.animations_style || ({ window: "native", workspace: "native", border: "native", border_speed: 36, reduced_motion: false }),
                    result.look_feel || ({ schema_version: 1, preset: "omarchy-native", preset_revision: 1, customized: ({}) }),
                    result.terminal_translucency || ({ schema_version: 1, mode: "preserve", opacity: 1, cell_mode: "background" })
                );
            } catch (error) {
                root.sessionBeginFailed("Backend returned invalid JSON");
            }
        }
    }

    Process {
        id: sessionCancelProcess

        stdout: BoundedOutputParser {
            id: sessionCancelStdout
        }

        stderr: BoundedOutputParser {
            id: sessionCancelStderr
        }

        onStarted: root.resetOutputs(sessionCancelStdout, sessionCancelStderr)

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionCancelStderr.text.trim();
                root.sessionCancelFailed(
                    message !== "" ? message : "Failed to cancel session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionCancelStdout.text);
                if (result.ok !== true || !result.session_id) {
                    root.sessionCancelFailed(
                        "Backend returned invalid cancellation result"
                    );
                    return;
                }
                root.sessionCancelled(result.session_id);
            } catch (error) {
                root.sessionCancelFailed(
                    "Backend returned invalid cancellation JSON"
                );
            }
        }
    }

    Process {
        id: generationProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: generationStdout }
        stderr: BoundedOutputParser { id: generationStderr }
        onStarted: root.resetOutputs(generationStdout, generationStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) { root.generationFailed(requestSessionId, generationStderr.text.trim() || "Theme generation failed"); return }
            try { const result=JSON.parse(generationStdout.text); if (!result.generation_id) { root.generationFailed(requestSessionId, "Backend returned no generation id"); return } root.generationCompleted(requestSessionId, result.generation_id) } catch (error) { root.generationFailed(requestSessionId, "Backend returned invalid generation JSON") }
        }
    }

    Process {
        id: generationDescribeProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: generationDescribeStdout }
        stderr: BoundedOutputParser { id: generationDescribeStderr }
        onStarted: root.resetOutputs(generationDescribeStdout, generationDescribeStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) { root.generationDescribeFailed(requestSessionId, generationDescribeStderr.text.trim() || "Failed to load generated palettes"); return }
            try { const result=JSON.parse(generationDescribeStdout.text); if (!result.generation_id || (result.variants||[]).length !== 6) { root.generationDescribeFailed(requestSessionId, "Backend returned incomplete generation data"); return } root.generationDescribed(requestSessionId, result.generation_id, result.variants) } catch (error) { root.generationDescribeFailed(requestSessionId, "Backend returned invalid generation description") }
        }
    }

    Process {
        id: generationDiscardProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: generationDiscardStdout }
        stderr: BoundedOutputParser { id: generationDiscardStderr }
        onStarted: root.resetOutputs(generationDiscardStdout, generationDiscardStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) {
                root.generationDiscardFailed(requestSessionId, generationDiscardStderr.text.trim() || "Failed to discard generated workspace");
                return;
            }
            try {
                const result = JSON.parse(generationDiscardStdout.text);
                if (result.ok !== true || !result.session_id || !result.generation_id) {
                    root.generationDiscardFailed(requestSessionId, "Backend returned incomplete generation discard data");
                    return;
                }
                root.generationDiscarded(result.session_id, result.generation_id);
            } catch (error) {
                root.generationDiscardFailed(requestSessionId, "Backend returned invalid generation discard JSON");
            }
        }
    }

    Process {
        id: previewProcess
        stdout: BoundedOutputParser { id: previewStdout }
        stderr: BoundedOutputParser { id: previewStderr }
        onStarted: root.resetOutputs(previewStdout, previewStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.previewApplyFailed(previewStderr.text.trim() || "Failed to apply preview"); return }
            try { const result=JSON.parse(previewStdout.text); if (!result.session_id || !result.generation_id || !result.variant) { root.previewApplyFailed("Backend returned incomplete preview data"); return } root.previewApplied(result.session_id,result.generation_id,result.variant,result.theme_name||"") } catch (error) { root.previewApplyFailed("Backend returned invalid preview JSON") }
        }
    }

    Process {
        id: applyProcess
        stdout: BoundedOutputParser { id: applyStdout }
        stderr: BoundedOutputParser { id: applyStderr }
        onStarted: root.resetOutputs(applyStdout, applyStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.themeApplyFailed(applyStderr.text.trim() || "Failed to apply theme"); return }
            try { const result = JSON.parse(applyStdout.text); if (!result.session_id || !result.generation_id || !result.variant || !result.theme_name) { root.themeApplyFailed("Backend returned incomplete apply data"); return } root.themeApplied(result.session_id, result.generation_id, result.variant, result.theme_name) } catch (error) { root.themeApplyFailed("Backend returned invalid apply JSON") }
        }
    }

    Process {
        id: demoOpenProcess
        stdout: BoundedOutputParser { id: demoOpenStdout }
        stderr: BoundedOutputParser { id: demoOpenStderr }
        onStarted: root.resetOutputs(demoOpenStdout, demoOpenStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoOpenFailed(demoOpenStderr.text.trim() || "Failed to open demo workspace"); return }
            try {
                const result = JSON.parse(demoOpenStdout.text)
                if (result.ok !== true || !result.session_id || !result.workspace || !result.monitor) { root.demoOpenFailed("Backend returned incomplete live canvas data"); return }
                root.demoOpened(result.session_id, result.workspace, result.monitor, result.reused === true)
            } catch (error) { root.demoOpenFailed("Backend returned invalid demo JSON") }
        }
    }

    Process {
        id: windowDemoOpenProcess
        stdout: BoundedOutputParser { id: windowDemoOpenStdout }
        stderr: BoundedOutputParser { id: windowDemoOpenStderr }
        onStarted: root.resetOutputs(windowDemoOpenStdout, windowDemoOpenStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.windowDemoOpenFailed(windowDemoOpenStderr.text.trim() || "Failed to open Window demo"); return }
            try {
                const result = JSON.parse(windowDemoOpenStdout.text)
                if (result.ok !== true || !result.session_id || !result.workspace || !result.monitor) { root.windowDemoOpenFailed("Backend returned incomplete Window demo data"); return }
                root.windowDemoOpened(result.session_id, result.workspace, result.monitor, result.reused === true)
            } catch (error) { root.windowDemoOpenFailed("Backend returned invalid Window demo JSON") }
        }
    }

    Process {
        id: demoCloseProcess
        stdout: BoundedOutputParser { id: demoCloseStdout }
        stderr: BoundedOutputParser { id: demoCloseStderr }
        onStarted: root.resetOutputs(demoCloseStdout, demoCloseStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoCloseFailed(demoCloseStderr.text.trim() || "Failed to close demo workspace"); return }
            try {
                const result = JSON.parse(demoCloseStdout.text)
                if (result.ok !== true || !result.session_id) { root.demoCloseFailed("Backend returned incomplete demo cleanup data"); return }
                root.demoClosed(result.session_id, result.closed === true)
            } catch (error) { root.demoCloseFailed("Backend returned invalid demo cleanup JSON") }
        }
    }

    Process {
        id: demoReflowProcess
        stdout: BoundedOutputParser { id: demoReflowStdout }
        stderr: BoundedOutputParser { id: demoReflowStderr }
        onStarted: root.resetOutputs(demoReflowStdout, demoReflowStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoReflowFailed(demoReflowStderr.text.trim() || "Failed to reflow live canvas"); return }
            try {
                const result = JSON.parse(demoReflowStdout.text)
                if (result.ok !== true || !result.session_id) { root.demoReflowFailed("Backend returned incomplete live canvas reflow data"); return }
                root.demoReflowed(result.session_id)
            } catch (error) { root.demoReflowFailed("Backend returned invalid live canvas reflow JSON") }
        }
    }

    Process {
        id: demoCaptureProcess
        stdout: BoundedOutputParser { id: demoCaptureStdout }
        stderr: BoundedOutputParser { id: demoCaptureStderr }
        onStarted: root.resetOutputs(demoCaptureStdout, demoCaptureStderr)
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoCaptureFailed(demoCaptureStderr.text.trim() || "Failed to capture Demo preview"); return }
            try {
                const result = JSON.parse(demoCaptureStdout.text)
                if (result.ok !== true || !result.session_id || !result.preview_path) { root.demoCaptureFailed("Backend returned incomplete Demo capture data"); return }
                root.demoCaptured(result.session_id, result.preview_path)
            } catch (error) { root.demoCaptureFailed("Backend returned invalid Demo capture JSON") }
        }
    }

    Process {
        id: protocolInspectProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: protocolInspectStdout }
        stderr: BoundedOutputParser { id: protocolInspectStderr }
        onStarted: root.resetOutputs(protocolInspectStdout, protocolInspectStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) {
                root.protocolSnapshotFailed(requestSessionId, protocolInspectStderr.text.trim() || "Failed to inspect change history");
                return;
            }
            try {
                const result = JSON.parse(protocolInspectStdout.text);
                if (!result.session_id || !result.snapshot) {
                    root.protocolSnapshotFailed(requestSessionId, "Backend returned incomplete change history");
                    return;
                }
                root.protocolSnapshotLoaded(result.session_id, result.snapshot);
            } catch (error) {
                root.protocolSnapshotFailed(requestSessionId, "Backend returned invalid change history JSON");
            }
        }
    }

    Process {
        id: protocolBackProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: protocolBackStdout }
        stderr: BoundedOutputParser { id: protocolBackStderr }
        onStarted: root.resetOutputs(protocolBackStdout, protocolBackStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) {
                root.protocolNavigationFailed(requestSessionId, protocolBackStderr.text.trim() || "Cannot move back in change history");
                return;
            }
            try {
                const result = JSON.parse(protocolBackStdout.text);
                if (!result.to_checkpoint_id || !result.state) {
                    root.protocolNavigationFailed(requestSessionId, "Backend returned incomplete back navigation data");
                    return;
                }
                root.protocolNavigationCompleted(requestSessionId, result);
            } catch (error) {
                root.protocolNavigationFailed(requestSessionId, "Backend returned invalid back navigation JSON");
            }
        }
    }

    Process {
        id: protocolForwardProcess
        property string sessionId: ""
        stdout: BoundedOutputParser { id: protocolForwardStdout }
        stderr: BoundedOutputParser { id: protocolForwardStderr }
        onStarted: root.resetOutputs(protocolForwardStdout, protocolForwardStderr)
        onExited: function(exitCode, exitStatus) {
            const requestSessionId = sessionId;
            if (exitCode !== 0) {
                root.protocolNavigationFailed(requestSessionId, protocolForwardStderr.text.trim() || "Cannot move forward in change history");
                return;
            }
            try {
                const result = JSON.parse(protocolForwardStdout.text);
                if (!result.to_checkpoint_id || !result.state) {
                    root.protocolNavigationFailed(requestSessionId, "Backend returned incomplete forward navigation data");
                    return;
                }
                root.protocolNavigationCompleted(requestSessionId, result);
            } catch (error) {
                root.protocolNavigationFailed(requestSessionId, "Backend returned invalid forward navigation JSON");
            }
        }
    }
}
