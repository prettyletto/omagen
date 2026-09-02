import QtTest
import QtQuick
import "../controllers"

TestCase {
    name: "PreviewController"

    QtObject {
        id: backend
        signal previewApplied(string sessionId, string generationId, string variant, string themeName)
        signal previewApplyFailed(string message)
        property int calls: 0
        function applyPreview(sessionId, generationId, variant, overrides, styles) {
            calls += 1
        }
    }

    QtObject {
        id: session
        property bool workspaceReady: true
        property string sessionId: "session-1"
        property string generationId: "generation-1"
        property string selectedVariant: "source"
        property string previewVariant: ""
        function markPreviewed(variant) { previewVariant = variant }
    }

    QtObject {
        id: canvas
        function overridesForVariant(variant) { return ({}) }
    }

    PreviewController {
        id: controller
        backend: backend
        session: session
        liveCanvasPanel: canvas
    }

    property int appliedCount: 0

    Connections {
        target: controller
        function onApplied() { appliedCount += 1 }
    }

    function init() {
        backend.calls = 0
        appliedCount = 0
        session.previewVariant = ""
        controller.reset()
    }

    function test_alreadyLiveEmitsCompletionAndDoesNotSpawnProcess() {
        compare(controller.start("source", {}, null, false), "started")
        compare(backend.calls, 1)
        backend.previewApplied("session-1", "generation-1", "source", "preview-source")
        compare(appliedCount, 1)

        compare(controller.start("source", {}, null, false), "alreadyLive")
        compare(backend.calls, 1)
        compare(appliedCount, 2)
    }

    function test_busyPreviewKeepsOnlyLatestIntent() {
        compare(controller.start("source", { red: "#111111" }, null, true), "started")
        compare(controller.start("source", { red: "#222222" }, null, true), "queued")
        compare(controller.start("source", { red: "#333333" }, null, true), "queued")
        compare(backend.calls, 1)

        backend.previewApplied("session-1", "generation-1", "source", "preview-red-111111")
        compare(backend.calls, 2)
        compare(appliedCount, 0)

        backend.previewApplied("session-1", "generation-1", "source", "preview-red-333333")
        compare(backend.calls, 2)
        compare(appliedCount, 1)
    }
}
