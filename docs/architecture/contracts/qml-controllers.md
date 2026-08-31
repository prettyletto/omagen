# QML controller contract

QML controllers are feature-owned state machines between the composition root,
the existing backend gateways, and visual views. They coordinate asynchronous
requests and expose high-level outcomes; they are not a second durable session
authority.

## Current controllers

| Module | Owns | Interface to the root |
| --- | --- | --- |
| `qml/controllers/PreviewController.qml` | Preview busy state, staged-colour preview state, preview command, session/generation correlation, and preview success/failure | `previewCurrentState()`, `start()`, `reset()`, `applied`, `rejected`, `failed` |
| `qml/controllers/DemoController.qml` | Full/Window backend Demo resources, QML-only Shell/Bar Demo modes, monitor selection, open/close/reflow state, and Demo command correlation | start/stop/dispatch methods, state properties, and completion signals |
| `qml/controllers/ApplyController.qml` | Apply pending variant/name/options, final-preview sequencing, optional capture, Demo close, cancellation invalidation, and recovery-required state | `apply()`, `cancel()`, `reset()`, shared completion handlers, and `completed`/error/UI signals |
| `qml/controllers/GenerationController.qml` | Generate/describe/discard sequencing, regeneration state, and generation correlation | `generate()`, `discard()`, `reset()`, and generation outcome signals |
| `qml/controllers/LiveCanvasWizardController.qml` | Ephemeral page navigation, Fast/In-depth workflow selection, and wizard history flags | step properties, navigation methods, and workflow signals |
| `qml/controllers/ThemeEditController.qml` | Installed-theme catalog/open state and source-workspace correlation | list/open/reset methods and theme-edit outcome signals |
| `qml/controllers/RuntimeSetupController.qml` | Advanced runtime prompt, status, install, and first-run dismissal state | setup/status actions and prompt/error signals |
| `qml/controllers/LookFeelController.qml` | Look & Feel catalog/resolution busy state and whether a resolution applies or only loads a recipe | `list()`, `requestPreset()`, `loadRecipe()`, `reset()`, and resolve/error signals |

The controllers use the existing gateway seam and the
`qml/services/BackendService.qml` compatibility façade where the root still
needs it. They preserve established command names, argv ordering, JSON fields,
and signal payloads. They do not alter palette, generation, session, cleanup,
or runtime algorithms.

## Ownership rules

- `Omagen.qml` remains the composition root for route visibility, style
  documents, durable `SessionState`, and high-level view wiring.
- A controller owns its busy and pending-operation state. The root exposes
  compatibility aliases only where views still consume the old property names.
- `ApplyController` must preserve the ordering `final preview → optional Demo
  capture → Demo close → backend Apply`.
- `DemoController` must keep backend-backed Full/Window Demo separate from the
  QML-only Shell/Bar demonstration surfaces.
- Cancel invalidates frontend controller state, while the backend remains the
  authority for closing Demo resources, restoring the baseline, and clearing
  the durable session.
- A stale session or generation response is rejected before it can advance a
  controller transition.

When extracting another state machine, add a focused controller interface and
route it through this document. Do not move arbitrary root functions into a
controller merely to lower a line-count warning.
