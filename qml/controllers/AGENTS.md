# QML controller guide

Controllers are feature-owned asynchronous state machines. Start with
`docs/architecture/contracts/qml-controllers.md`, then read only the
controller and gateway/view interfaces for the affected flow.

| Controller | Owns |
| --- | --- |
| `PreviewController.qml` | Preview request state and newest-pending coalescing |
| `DemoController.qml` | Full/Window and QML-only Demo sequencing |
| `ApplyController.qml` | staged Apply sequencing and completion/error state |
| `GenerationController.qml` | generate/describe/discard requests |
| `RuntimeSetupController.qml` | runtime setup request state |
| `LookFeelController.qml` | Look & Feel request state |
| `ThemeEditController.qml` | installed-theme edit route state |

`PreviewController.qml` owns preview command state, `DemoController.qml` owns
Full/Window and QML-only Demo state, and `ApplyController.qml` owns the staged
Apply sequence. `GenerationController.qml` owns generate/describe/discard;
`RuntimeSetupController.qml` and `LookFeelController.qml` own their request
state. Keep backend session
rollback, cleanup, and recovery authority in Go. Preserve existing command
argv, JSON fields, signal payloads, and session/generation correlation.

Run `qmllint` when available and
`GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh` from the repository root.
Manual Quickshell validation is required for changes to operation ordering,
Demo transitions, Cancel, Apply, recovery, or layer-close behavior. Preserve
session/generation correlation and stale-response rejection; do not add direct
backend launches or a second operation handler in `Omagen.qml`.
