import QtTest
import QtQuick
import "../controllers"

TestCase {
    name: "ApplyController"

    QtObject {
        id: backend

        signal themeApplied(string sessionId, string generationId, string variant, string themeName)
        signal themeApplyFailed(string message)

        property int openCalls: 0
        property int closeCalls: 0
        property int captureCalls: 0
        property int applyCalls: 0
        property bool lastApplyCaptured: false

        function openDemo(sessionId) { openCalls += 1 }
        function closeDemo(sessionId) { closeCalls += 1 }
        function captureDemoPreview(sessionId) { captureCalls += 1 }
        function applyTheme(sessionId, generationId, variant, name, unlock, capture, replaceSource, presetName) {
            applyCalls += 1
            lastApplyCaptured = capture
        }
    }

    QtObject {
        id: demo

        signal opened(string sessionId, string workspace, string monitor, bool reused)
        signal openFailed(string message)
        signal captured(string sessionId, string previewPath)
        signal captureFailed(string message)
        signal closed(string sessionId, bool wasClosed)
        signal closeFailed(string message)

        property bool active: false
        property string mode: "none"
    }

    QtObject {
        id: session

        property bool workspaceReady: true
        property string sessionId: "session-1"
        property string generationId: "generation-1"
        property string selectedVariant: "source"
    }

    QtObject {
        id: preview

        signal applied()
        signal failed(string message)
        property int calls: 0

        function previewCurrentState(variant) {
            calls += 1
            return "started"
        }
    }

    ApplyController {
        id: controller
        backend: backend
        session: session
        previewController: preview
        demoController: demo
        workspaceReady: session.workspaceReady
        previewBusy: false
        demoBusy: false
        cancelBusy: false
        demoActive: demo.active
        demoMode: demo.mode
    }

    function init() {
        backend.openCalls = 0
        backend.closeCalls = 0
        backend.captureCalls = 0
        backend.applyCalls = 0
        backend.lastApplyCaptured = false
        preview.calls = 0
        demo.active = false
        demo.mode = "none"
        controller.reset()
    }

    function test_captureRestartsActiveDemoAsFreshFullDemo() {
        demo.active = true
        demo.mode = "bar"

        controller.apply("source", "demo-theme", false, true, false, false, "")

        verify(controller.active)
        compare(backend.closeCalls, 1)
        compare(backend.openCalls, 0)
        compare(preview.calls, 0)

        demo.active = false
        demo.mode = "none"
        demo.closed("session-1", true)

        compare(backend.openCalls, 1)
        verify(controller.pendingCapture)

        demo.active = true
        demo.mode = "full"
        demo.opened("session-1", "__omagen_demo_session-1", "DP-1", false)
        compare(preview.calls, 1)

        preview.applied()
        compare(backend.captureCalls, 1)

        demo.captured("session-1", "/tmp/apply-preview.png")
        compare(backend.closeCalls, 2)

        demo.active = false
        demo.mode = "none"
        demo.closed("session-1", true)

        compare(backend.applyCalls, 1)
        verify(backend.lastApplyCaptured)
    }
}
