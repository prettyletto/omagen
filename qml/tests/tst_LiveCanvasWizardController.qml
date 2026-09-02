import QtTest
import QtQuick
import "../controllers"

TestCase {
    name: "LiveCanvasWizardController"

    LiveCanvasWizardController {
        id: controller
        sessionReady: true
        paletteSelected: true
        lookFeelDecided: true
    }

    property bool workflowCancelRequested: false
    property bool workflowBackRequested: false
    property bool restoreAndCloseRequested: false

    Connections {
        target: controller
        function onWorkflowCancelRequested() { workflowCancelRequested = true }
        function onWorkflowBackRequested() { workflowBackRequested = true }
        function onRestoreAndCloseRequested() { restoreAndCloseRequested = true }
    }

    function init() {
        controller.reset()
        controller.sessionReady = true
        controller.paletteSelected = true
        controller.lookFeelDecided = true
        controller.operationBusy = false
        workflowCancelRequested = false
        workflowBackRequested = false
        restoreAndCloseRequested = false
        controller.selectedVariant = "source"
        controller.selectedLookFeelPreset = "omarchy-native"
        controller.restoreFromFirstStep = false
    }

    function test_progressionAndBackPreserveAdvancedChoice() {
        compare(controller.stepCount, 5)
        compare(controller.step, 0)
        verify(controller.canGoNext)
        compare(controller.goNext(), true)
        compare(controller.step, 1)
        compare(controller.goNext(), true)
        compare(controller.step, 2)

        verify(controller.chooseAdvanced("customize"))
        compare(controller.advancedChoice, "customize")
        compare(controller.goNext(), true)
        compare(controller.step, 3)
        compare(controller.goBack(), true)
        compare(controller.step, 2)
        compare(controller.advancedChoice, "customize")
    }

    function test_navigationIsBlockedDuringOperation() {
        controller.operationBusy = true
        verify(!controller.canGoBack)
        verify(!controller.canGoNext)
        compare(controller.goNext(), false)
        compare(controller.step, 0)
        compare(controller.requestRestoreAndClose(), false)
    }

    function test_nextCanUseTheDefaultPaletteSelection() {
        controller.selectedVariant = ""
        verify(controller.canGoNext)

        controller.selectedVariant = "source"
        verify(controller.canGoNext)
    }

    function test_existingLookFeelPresetCountsAsASelection() {
        controller.step = 1
        controller.lookFeelDecided = false
        controller.selectedLookFeelPreset = "omarchy-native"

        verify(controller.canGoNext)
        compare(controller.goNext(), true)
        compare(controller.step, 2)
        compare(controller.advancedChoice, "skip")
        verify(controller.canGoNext)
    }

    function test_missingLookFeelPresetStillRequiresAChoice() {
        controller.step = 1
        controller.lookFeelDecided = false
        controller.selectedLookFeelPreset = ""

        verify(!controller.canGoNext)
    }

    function test_preSessionWorkflowRequiresExplicitModeBeforeContinue() {
        controller.beginWorkflow(true)
        controller.sessionReady = false
        controller.paletteSelected = false
        verify(!controller.canContinueWorkflow)
        verify(!controller.confirmWorkflow())

        controller.sessionReady = true
        controller.paletteSelected = true
        verify(!controller.selectWorkflowMode(""))
        verify(controller.selectWorkflowMode("in-depth"))
        compare(controller.workflowMode, "in-depth")
        verify(controller.workflowModeConfirmed)
        verify(controller.canContinueWorkflow)
        verify(controller.confirmWorkflow())
        verify(controller.workflowStepActive)
        controller.finishWorkflow()
        verify(!controller.workflowStepActive)
        verify(controller.workflowHistoryAvailable)
    }

    function test_navigationResetPreservesPreSessionSelection() {
        controller.beginWorkflow(true)
        verify(controller.selectWorkflowMode("fast"))
        controller.step = 3
        controller.chooseAdvanced("customize")
        controller.resetNavigation()

        compare(controller.step, 0)
        compare(controller.workflowMode, "fast")
        verify(controller.workflowModeConfirmed)
        verify(controller.workflowStepActive)
        verify(controller.sourceImageSelected)
    }

    function test_setupHandoffIsSeparateFromWorkflowContinue() {
        controller.beginWorkflow(true)
        verify(controller.canOpenWorkflow)
        verify(!controller.canContinueWorkflow)
        verify(controller.selectWorkflowMode("fast"))
        verify(controller.canOpenWorkflow)
        verify(controller.canContinueWorkflow)
    }

    function test_backFromWorkflowReturnsToSetupChooser() {
        controller.beginWorkflow(true)
        verify(controller.canGoBack)
        verify(controller.goBack())
        verify(workflowCancelRequested)
    }

    function test_workflowContinueIsSingleFlightAndCanRetryAfterFailure() {
        controller.beginWorkflow(true)
        verify(controller.selectWorkflowMode("fast"))
        verify(controller.canContinueWorkflow)

        verify(controller.confirmWorkflow())
        verify(controller.workflowContinuePending)
        verify(!controller.canContinueWorkflow)
        verify(!controller.confirmWorkflow())

        controller.workflowBeginFailed()
        verify(!controller.workflowContinuePending)
        verify(!controller.workflowHistoryAvailable)
        verify(controller.canContinueWorkflow)
    }

    function test_backFromFirstGeneratedPageRequestsRestoreAndChooser() {
        controller.beginWorkflow(true)
        verify(controller.selectWorkflowMode("in-depth"))
        controller.finishWorkflow()
        controller.sessionReady = true
        controller.paletteSelected = true
        compare(controller.step, 0)
        verify(controller.workflowHistoryAvailable)
        verify(controller.canGoBack)
        verify(controller.goBack())
        verify(workflowBackRequested)
        verify(!controller.workflowStepActive)
        verify(!controller.workflowContinuePending)
    }

    function test_editFirstGeneratedPageBackRestoresAndCloses() {
        controller.restoreFromFirstStep = true
        controller.selectedVariant = "source"
        verify(controller.canGoBack)
        compare(controller.goBack(), true)
        verify(restoreAndCloseRequested)
        compare(controller.step, 0)
    }

    function test_restoreIntentIsOnlyAvailableOnFinish() {
        verify(controller.goNext())
        verify(controller.goNext())
        verify(controller.chooseAdvanced("skip"))
        verify(controller.goNext())
        verify(controller.goNext())
        compare(controller.step, 4)
        compare(controller.requestRestoreAndClose(), true)
    }
}
