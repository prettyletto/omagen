import QtQuick

import "ConfigurationArgs.js" as ConfigurationArgs

Item {
    id: root

    property string executable: ""

    signal generationCompleted(string sessionId, string generationId)
    signal generationFailed(string sessionId, string message)
    signal generationDescribed(string sessionId, string generationId, var variants)
    signal generationDescribeFailed(string sessionId, string message)
    signal generationDiscarded(string sessionId, string generationId)
    signal generationDiscardFailed(string sessionId, string message)

    function generateTheme(sessionId, imagePath, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency) {
        generationCommand.sessionId = sessionId
        const args = [root.executable, "generate", sessionId, imagePath]
        ConfigurationArgs.appendConfigurationArgs(args, shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
        generationCommand.exec(args)
    }

    function describeGeneration(sessionId, generationId) {
        describeCommand.sessionId = sessionId
        describeCommand.exec([root.executable, "generation", "describe", sessionId, generationId])
    }

    function discardGeneration(sessionId, generationId) {
        discardCommand.sessionId = sessionId
        discardCommand.exec([root.executable, "generation", "discard", sessionId, generationId])
    }

    BackendCommand {
        id: generationCommand
        property string sessionId: ""
        failureFallback: "Theme generation failed"
        invalidJsonFallback: "Backend returned invalid generation JSON"
        onCompleted: function(result) {
            const requestSessionId = generationCommand.sessionId
            if (!result.generation_id) {
                root.generationFailed(requestSessionId, "Backend returned no generation id")
                return
            }
            root.generationCompleted(requestSessionId, result.generation_id)
        }
        onFailed: function(message) { root.generationFailed(generationCommand.sessionId, message) }
    }

    BackendCommand {
        id: describeCommand
        property string sessionId: ""
        failureFallback: "Failed to load generated palettes"
        invalidJsonFallback: "Backend returned invalid generation description"
        onCompleted: function(result) {
            const requestSessionId = describeCommand.sessionId
            if (!result.generation_id || (result.variants || []).length !== 6) {
                root.generationDescribeFailed(requestSessionId, "Backend returned incomplete generation data")
                return
            }
            root.generationDescribed(requestSessionId, result.generation_id, result.variants)
        }
        onFailed: function(message) { root.generationDescribeFailed(describeCommand.sessionId, message) }
    }

    BackendCommand {
        id: discardCommand
        property string sessionId: ""
        failureFallback: "Failed to discard generated workspace"
        invalidJsonFallback: "Backend returned invalid generation discard JSON"
        onCompleted: function(result) {
            const requestSessionId = discardCommand.sessionId
            if (result.ok !== true || !result.session_id || !result.generation_id) {
                root.generationDiscardFailed(requestSessionId, "Backend returned incomplete generation discard data")
                return
            }
            root.generationDiscarded(result.session_id, result.generation_id)
        }
        onFailed: function(message) { root.generationDiscardFailed(discardCommand.sessionId, message) }
    }
}
