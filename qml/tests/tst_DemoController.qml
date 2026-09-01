import QtTest
import QtQuick
import "../controllers"

TestCase {
    name: "DemoController"

    QtObject {
        id: backend
        signal demoOpened(string sessionId, string workspace, string monitor, bool reused)
        signal windowDemoOpened(string sessionId, string workspace, string monitor, bool reused)
        signal demoReaderOpened(string sessionId, string workspace, string monitor, string mode, bool reused)
        signal demoClosed(string sessionId, bool wasClosed)
        signal demoOpenFailed(string message)
        signal windowDemoOpenFailed(string message)
        signal demoCloseFailed(string message)
        signal demoReflowed(string sessionId)
        signal demoReflowFailed(string message)
        property int openCalls: 0
        property int windowOpenCalls: 0
        property int readerOpenCalls: 0
        property int closeCalls: 0
        property int reflowCalls: 0

        function openDemo(sessionId) { openCalls += 1 }
        function openWindowDemo(sessionId) { windowOpenCalls += 1 }
        function openDemoReader(sessionId, mode) { readerOpenCalls += 1 }
        function closeDemo(sessionId) { closeCalls += 1 }
        function reflowDemo(sessionId) { reflowCalls += 1 }
    }

    QtObject {
        id: session
        property bool workspaceReady: true
        property string sessionId: "session-1"
        property string generationId: "generation-1"
        property string selectedVariant: "source"
        function selectVariant(variant) { selectedVariant = variant }
    }

    QtObject {
        id: previewController
        property int calls: 0
        function previewCurrentState(variant) { calls += 1; return "started" }
    }

    DemoController {
        id: controller
        backend: backend
        session: session
        previewController: previewController
        focusedMonitorName: function() { return "DP-1" }
        workspaceReady: session.workspaceReady
    }

    function init() {
        backend.openCalls = 0
        backend.windowOpenCalls = 0
        backend.readerOpenCalls = 0
        backend.closeCalls = 0
        backend.reflowCalls = 0
        previewController.calls = 0
        session.selectedVariant = "source"
        controller.reset()
        controller.workspaceReady = true
    }

    function test_readerModesSwitchAndStopWithoutBackendCalls() {
        compare(controller.requestMode("shell"), "started")
        compare(backend.readerOpenCalls, 1)
        verify(!controller.active)

        backend.demoReaderOpened("session-1", "__omagen_demo_session-1_shell", "DP-1", "shell", false)
        compare(controller.mode, "shell")
        compare(controller.monitor, "DP-1")

        compare(controller.requestMode("bar"), "switching")
        compare(backend.closeCalls, 1)
        backend.demoClosed("session-1", true)
        compare(backend.readerOpenCalls, 2)
        backend.demoReaderOpened("session-1", "__omagen_demo_session-1_bar", "DP-1", "bar", false)
        compare(controller.mode, "bar")
        compare(controller.requestMode("bar"), "stopped")
        verify(!controller.active)
        compare(backend.openCalls, 0)
        compare(backend.closeCalls, 2)
    }

    function test_windowModePreviewsBeforeOpeningOwnedWindows() {
        compare(controller.requestMode("window"), "started")
        compare(previewController.calls, 1)
        verify(controller.pendingWindowDemo)
        compare(backend.windowOpenCalls, 0)

        verify(controller.handlePreviewApplied())
        compare(backend.windowOpenCalls, 1)

        backend.windowDemoOpened("session-1", "__omagen_demo_session-1_window", "DP-1", false)
        compare(controller.mode, "window")
        verify(controller.active)
        verify(!controller.pendingWindowDemo)
    }

    function test_fullModeOpensBeforePreviewAndRepeatedChoiceCloses() {
        compare(controller.requestMode("full", "bright"), "started")
        compare(session.selectedVariant, "bright")
        compare(backend.openCalls, 1)
        verify(controller.pendingDemo)

        backend.demoOpened("session-1", "__omagen_demo_session-1", "DP-1", false)
        compare(controller.mode, "full")
        verify(controller.active)
        controller.finishPendingDemo()

        compare(controller.requestMode("full"), "stopped")
        compare(backend.closeCalls, 1)
        verify(controller.busy)
    }

    function test_switchingOwnedModesClosesBeforeStartingTarget() {
        controller.requestMode("full")
        backend.demoOpened("session-1", "__omagen_demo_session-1", "DP-1", false)
        controller.finishPendingDemo()

        compare(controller.requestMode("window"), "switching")
        compare(backend.closeCalls, 1)
        compare(controller.pendingMode, "window")
        compare(previewController.calls, 0)

        backend.demoClosed("session-1", true)
        compare(previewController.calls, 1)
        verify(controller.pendingWindowDemo)
        compare(backend.windowOpenCalls, 0)
    }

    function test_unknownModeIsRejected() {
        compare(controller.requestMode("not-a-demo"), "invalid")
        verify(!controller.active)
        verify(!controller.busy)
    }
}
