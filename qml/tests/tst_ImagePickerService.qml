import QtTest
import QtQml
import "../services"

TestCase {
    name: "ImagePickerService"

    ImagePickerService {
        id: picker
        // yes accepts the chooser arguments and stays alive until cancel().
        // This exercises the same Process stop/exit path used by the native
        // portal wrapper without opening a real desktop dialog.
        executable: "/usr/bin/yes"
    }

    property int selectedCount: 0
    property int cancelledCount: 0
    property int failedCount: 0

    Connections {
        target: picker
        function onSelected(path) { selectedCount += 1 }
        function onCancelled() { cancelledCount += 1 }
        function onFailed(message) { failedCount += 1 }
    }

    function init() {
        selectedCount = 0
        cancelledCount = 0
        failedCount = 0
        picker.cancel()
    }

    function cleanup() {
        picker.cancel()
    }

    function test_cancelStopsPickerWithoutReportingCancellation() {
        picker.choose()
        tryCompare(picker, "running", true)

        verify(picker.cancel())
        tryCompare(picker, "running", false)
        wait(50)

        compare(selectedCount, 0)
        compare(cancelledCount, 0)
        compare(failedCount, 0)
    }
}
