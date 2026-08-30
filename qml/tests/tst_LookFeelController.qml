import QtTest
import QtQuick
import "../controllers"

TestCase {
    name: "LookFeelController"

    QtObject {
        id: backend
        signal lookFeelResolved(var composition)
        signal lookFeelResolveFailed(string message)
        property int resolveCalls: 0
        property var requested: []

        function resolveLookFeel(preset) {
            resolveCalls += 1
            requested.push(String(preset))
        }
    }

    LookFeelController {
        id: controller
        backend: backend
        previewBusy: true
    }

    property int resolvedCount: 0
    property string lastResolvedPreset: ""

    Connections {
        target: controller
        function onResolved(composition, applies) {
            if (applies) {
                resolvedCount += 1
                lastResolvedPreset = String(composition.preset)
            }
        }
    }

    function composition(preset) {
        return {
            preset: preset,
            window: { shape: "rounded" },
            shell: { preset: "glass" },
            bar: { surface: "solid" },
            animations: { preset: "smooth" },
            terminal: { mode: "preset", opacity: 0.82 }
        }
    }

    function init() {
        backend.resolveCalls = 0
        backend.requested = []
        resolvedCount = 0
        lastResolvedPreset = ""
        controller.reset()
    }

    function test_busyPreviewAcceptsLatestPresetAndRejectsStaleResolution() {
        verify(controller.requestPreset("first"))
        verify(controller.requestPreset("second"))
        compare(backend.resolveCalls, 1)
        compare(backend.requested[0], "first")

        backend.lookFeelResolved(composition("first"))
        compare(resolvedCount, 0)
        compare(backend.resolveCalls, 2)
        compare(backend.requested[1], "second")

        backend.lookFeelResolved(composition("second"))
        compare(resolvedCount, 1)
        compare(lastResolvedPreset, "second")
        verify(!controller.busy)
    }
}
