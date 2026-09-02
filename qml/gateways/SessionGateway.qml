import QtQuick

import "ConfigurationArgs.js" as ConfigurationArgs

Item {
    id: root

    property string executable: ""

    signal sessionBegan(string sessionId, string originalTheme, string backgroundKind, string backgroundPath, var shellStyle, bool extraConfigs, var desktopStyle, var barStyle, var animationsStyle, var lookFeel, var terminalTranslucency)
    signal sessionBeginFailed(string message)
    signal sessionCancelled(string sessionId)
    signal sessionCancelFailed(string message)
    signal sessionResumeChecked(var result)
    signal sessionResumeCheckFailed(string message)
    signal sessionRecovered()
    signal sessionRecoverFailed(string message)

    function appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        ConfigurationArgs.appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
    }

    function beginSession(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        const args = [root.executable, "session", "begin"]
        appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
        sessionBeginCommand.exec(args)
    }

    function cancelSession(sessionId) {
        sessionCancelCommand.exec([root.executable, "session", "cancel", sessionId])
    }

    function checkResumeSession() { resumeCommand.exec([root.executable, "session", "resume"]) }
    function recoverSession() { recoverCommand.exec([root.executable, "session", "recover"]) }

    BackendCommand {
        id: sessionBeginCommand
        failureFallback: "Failed to begin session"
        onCompleted: function(result) {
            const background = result.original_background || ({})
            const sessionId = result.session_id || ""
            const originalTheme = result.original_theme || ""
            const backgroundKind = background.kind || ""
            const backgroundPath = background.path || ""
            if (sessionId === "" || originalTheme === "" || backgroundKind === "" || backgroundPath === "") {
                root.sessionBeginFailed("Backend returned incomplete session data")
                return
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
            )
        }
        onFailed: root.sessionBeginFailed(message)
    }

    BackendCommand {
        id: sessionCancelCommand
        failureFallback: "Failed to cancel session"
        invalidJsonFallback: "Backend returned invalid cancellation JSON"
        onCompleted: function(result) {
            if (result.ok !== true || !result.session_id) {
                root.sessionCancelFailed("Backend returned invalid cancellation result")
                return
            }
            root.sessionCancelled(result.session_id)
        }
        onFailed: root.sessionCancelFailed(message)
    }

    BackendCommand {
        id: resumeCommand
        failureFallback: "Failed to inspect previous session"
        onCompleted: root.sessionResumeChecked(result)
        onFailed: root.sessionResumeCheckFailed(message)
    }

    BackendCommand {
        id: recoverCommand
        failureFallback: "Failed to restore previous session"
        onCompleted: root.sessionRecovered()
        onFailed: root.sessionRecoverFailed(message)
    }
}
