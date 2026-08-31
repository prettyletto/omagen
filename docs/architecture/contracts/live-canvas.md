# Live Canvas contract

Live Canvas is the monitor-bound editing surface for an active session. It is
QML workflow state, not a persistence or history engine. `LiveCanvasPanel.qml`
renders pages and emits intent; `LiveCanvasWizardController.qml` owns wizard
navigation; `Omagen.qml` composes state and routes requests.

## Workflow

The wizard supports two entry modes:

- **Fast** uses the normal image generation path.
- **In-depth** exposes staged Window, Shell, Bar, Animations, Look & Feel, and
  terminal controls.

Installed-theme editing enters through the Theme Picker, snapshots the native
and user source into a session workspace, and uses the authored source palette
without requiring a new image. It still produces the six generation
directions.

The active pages are Palette, Look & Feel, Advanced style, Demo, and Finish.
Page visibility is presentation state; lifecycle state remains in the root,
controllers, and backend session record.

## Operation ownership

| Intent | QML coordinator | Backend owner |
| --- | --- | --- |
| Generate/regenerate | `GenerationController` | `generation.Service` |
| Test Live / replace candidate | `PreviewController` | `preview.Service` |
| Open, close, reflow, capture Demo | `DemoController` | `demo.Service` |
| Save & Apply | `ApplyController` | `apply.Service` |
| Restore & close | root/controller request | `session.Service` plus lifecycle collaborators |

Controllers own busy flags, request correlation, and stale-response rejection.
The backend owns session identity, temporary aliases, Demo windows, rollback,
and recovery. Hiding a panel or starting a process is not cancellation or
completion.

## Replaceable preview

Live Canvas has no checkpoints, cursor, back/forward history, or preview
journal. Each Test Live request replaces the current candidate. Latest-intent
and single-flight rules decide which result may become visible. Preview uses
the same palette and theme writers as generation so the live result represents
what Apply will publish.

The Live Canvas fast path uses an instant wallpaper/Quickshell handoff.
Permanent Apply may retain its animated transition. Deferred retint and
cleanup must not extend the critical preview operation.

## Style documents and evidence

Focused editor signals are partial nested patches; the root merges them into
the current complete document before normalization and serialization. Preset
selection and scope reset are intentional complete replacements. Style helpers
are pure and do not spawn processes, write files, or mutate the session.

The QML tests cover wizard navigation, Preview correlation, gateway behavior,
and recursive style merging. Backend generation, Preview, Demo, Apply, and
session tests cover durable effects. Live monitor, Quickshell, Hyprland, and
visual behavior still require the repo-local interactive testing workflow.
