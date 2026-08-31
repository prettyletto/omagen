import QtQuick

// Ephemeral navigation state for the Live Canvas wizard. The composition root
// remains the owner of the durable session, style documents, and transaction
// controllers; this object only coordinates page intent for the view.
Item {
    id: root

    // Inputs supplied by Omagen.qml. They deliberately describe availability
    // rather than duplicating SessionState or any backend operation state.
    property bool sessionReady: false
    property bool operationBusy: false
    property bool paletteSelected: false
    // The palette card and the Next action must share the same selected value.
    // The boolean above describes availability; this value is the selection
    // that the composition root carries into the remaining wizard steps.
    property string selectedVariant: ""
    property bool lookFeelDecided: false
    // Theme-edit sessions do not have the image-workflow history that an
    // image-generated session uses. Their first page therefore restores and
    // closes when Back is pressed.
    property bool restoreFromFirstStep: false
    // Pre-session workflow selection is separate from live-page navigation.
    // It is intentionally ephemeral and does not mirror the durable backend
    // session until Omagen.qml confirms Continue.
    property bool workflowStepActive: false
    property bool sourceImageSelected: false
    property string workflowMode: ""
    property bool workflowModeConfirmed: false
    property bool workflowContinuePending: false
    // This is deliberately separate from workflowStepActive. The latter is
    // the currently visible pre-session page; this flag is the history seam
    // that keeps Back available after generation moves to Palette.
    property bool workflowHistoryAvailable: false

    readonly property int stepCount: 5
    property int step: 0
    property string advancedChoice: "undecided"

    readonly property bool canContinueWorkflow: root.workflowStepActive
        && root.sourceImageSelected
        && root.workflowModeConfirmed
        && !root.workflowContinuePending
        && !root.operationBusy
    readonly property bool canOpenWorkflow: root.workflowStepActive
        && root.sourceImageSelected
        && !root.workflowContinuePending
        && !root.operationBusy
    readonly property bool canGoBack: !root.operationBusy
        && (root.workflowStepActive
            ? root.sourceImageSelected
            : root.step > 0 || root.restoreFromFirstStep || (root.workflowHistoryAvailable
                && root.sourceImageSelected && root.workflowModeConfirmed))
    readonly property bool canGoNext: {
        if (root.workflowStepActive)
            return root.canContinueWorkflow
        if (!root.sessionReady || root.operationBusy)
            return false
        if (root.step === 0)
            return root.paletteSelected
        if (root.step === 1)
            return root.lookFeelDecided
        if (root.step === 2)
            return root.advancedChoice === "skip" || root.advancedChoice === "customize"
        return root.step === 3
    }
    readonly property string nextLabel: {
        if (root.workflowStepActive)
            return root.workflowModeConfirmed ? "Continue: Generate" : "Choose Fast or In-depth"
        if (root.step === 0)
            return "Next: Look & Feel"
        if (root.step === 1)
            return "Next: Advanced"
        if (root.step === 2)
            return "Next: Demo"
        if (root.step === 3)
            return "Review"
        return "Save & Apply"
    }

    signal goBackRequested()
    signal goNextRequested()
    signal advancedChoiceRequested(string choice)
    signal restoreAndCloseRequested()
    signal workflowModeSelected(string mode)
    signal workflowContinueRequested()
    signal workflowCancelRequested()
    signal workflowBackRequested()

    function reset() {
        root.resetNavigation()
        root.workflowStepActive = false
        root.sourceImageSelected = false
        root.workflowMode = ""
        root.workflowModeConfirmed = false
        root.workflowContinuePending = false
        root.workflowHistoryAvailable = false
    }

    function resetNavigation() {
        root.step = 0
        root.advancedChoice = "undecided"
        root.lookFeelDecided = false
    }

    function beginWorkflow(imageSelected) {
        root.resetNavigation()
        root.workflowStepActive = true
        root.sourceImageSelected = imageSelected === true
        root.workflowMode = ""
        root.workflowModeConfirmed = false
        root.workflowContinuePending = false
        root.workflowHistoryAvailable = false
    }

    function selectWorkflowMode(mode) {
        const nextMode = String(mode || "")
        if (nextMode !== "fast" && nextMode !== "in-depth")
            return false
        if (!root.workflowStepActive || root.operationBusy)
            return false
        root.workflowMode = nextMode
        root.workflowModeConfirmed = true
        root.workflowModeSelected(nextMode)
        return true
    }

    function confirmWorkflow() {
        if (!root.canContinueWorkflow)
            return false
        // Set the guard before emitting so a second pointer/keyboard event
        // cannot enqueue another Begin request in the same event turn.
        root.workflowContinuePending = true
        root.workflowContinueRequested()
        return true
    }

    function finishWorkflow() {
        root.workflowStepActive = false
        root.workflowContinuePending = false
        // Theme-edit and resumed sessions have no pre-session image workflow.
        // A normal image workflow retains this history through generation and
        // description so Back from Palette can cross the session boundary.
        root.workflowHistoryAvailable = root.sourceImageSelected
            && root.workflowModeConfirmed
    }

    function workflowBeginFailed() {
        if (root.workflowStepActive) {
            root.workflowContinuePending = false
            root.workflowHistoryAvailable = false
        }
    }

    function cancelWorkflow() {
        if (!root.workflowStepActive)
            return false
        root.workflowCancelRequested()
        root.workflowStepActive = false
        root.sourceImageSelected = false
        root.workflowMode = ""
        root.workflowModeConfirmed = false
        root.workflowContinuePending = false
        root.workflowHistoryAvailable = false
        return true
    }

    function chooseAdvanced(choice) {
        const nextChoice = String(choice || "")
        if (nextChoice !== "skip" && nextChoice !== "customize")
            return false
        root.advancedChoice = nextChoice
        root.advancedChoiceRequested(nextChoice)
        return true
    }

    function chooseLookFeel() {
        root.lookFeelDecided = true
        return true
    }

    function skipLookFeel() {
        root.lookFeelDecided = true
        return true
    }

    function goBack() {
        if (!root.canGoBack)
            return false
        if (root.workflowStepActive) {
            // The first workflow page is still part of setup. Back returns to
            // the image/theme chooser rather than leaving the user in a page
            // with no previous step.
            root.workflowCancelRequested()
            return true
        }
        if (root.step === 0) {
            if (root.restoreFromFirstStep) {
                root.restoreAndCloseRequested()
                return true
            }
            // Back from the first generated page exits the pre-session
            // workflow. The root routes this through the normal backend
            // cancel/restore transaction and returns to the initial chooser.
            root.workflowBackRequested()
            return true
        }
        root.goBackRequested()
        root.step -= 1
        return true
    }

    function goNext() {
        if (!root.canGoNext)
            return false
        root.goNextRequested()
        root.step += 1
        return true
    }

    // Verbose aliases keep the view seam self-documenting while retaining the
    // compact methods used by keyboard handlers and tests.
    function requestBack() { return root.goBack() }
    function requestNext() { return root.goNext() }

    function requestRestoreAndClose() {
        if (root.step !== root.stepCount - 1 || root.operationBusy)
            return false
        root.restoreAndCloseRequested()
        return true
    }
}
