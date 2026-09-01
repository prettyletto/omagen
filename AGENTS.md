# Omagen agent guide

Omagen is an Omarchy Quattro plugin. QML presents the overlay and bar widget;
the bundled Go backend owns theme generation, durable sessions, filesystem
mutation, Demo, Apply, and recovery.

## Start here

Read `docs/development.md`, classify the task with
`scripts/agent-context <domain>`, then read one recipe under
`docs/agents/recipes/` and the architecture contract it names. Inspect the
target and direct callers before expanding context. Run focused checks first,
then the repository gate, and record unavailable live checks in the handoff.
The branch lifecycle is `nightly` (experimental), `dev` (integration and
release candidates), and `main` (stable product). Do not introduce historical
branch, old-preview, or deleted-path assumptions into new docs or code.

## Global invariants

- The backend session record is the authority for baseline, rollback, and
  interrupted Apply state. QML state is a view and request coordinator.
- Apply, Cancel, Quit, recovery, preview cleanup, and Demo cleanup must remain
  ownership-aware and must not remove unrelated user resources.
- Palette, colorspace, contrast, and six-variant generation semantics are
  protected contracts. Structural work must not rewrite their algorithms.
- QML must use the existing Go JSON wire contract; do not casually rename
  commands, fields, stdout/stderr messages, or exit codes.
- Omarchy/Quattro owns native shell and widget layout. Omagen's bar, runtime
  bridge, and shell effects are additive or explicitly opted into.
- `pretty.omagen` is the overlay/bar-widget plugin; `pretty.omagen.bar` is the
  full bar plugin. Do not merge their manifests or ownership.
- User theme files, native `shell.json`, Hyprland state, and backgrounds are
  not Omagen-owned unless a session transaction recorded exact ownership.

## Bounded contexts

| Context | Start here | Main source |
| --- | --- | --- |
| Palette | `docs/agents/recipes/palette-engine-change.md` | `backend/internal/imageanalysis`, `palette`, `colorspace`, `contrast` |
| Generation | `docs/architecture/backend.md` | `backend/internal/generation`, `theme` |
| Lifecycle/recovery | `docs/agents/recipes/lifecycle-change.md` | `backend/internal/session`, `apply`, `preview`, `cleanup`, `qml/controllers` |
| QML UI | `docs/agents/recipes/qml-ui-change.md` | `qml/views`, `qml/components`, `qml/app`, `qml/controllers`, `Omagen.qml` |
| Live Canvas/Studio | `docs/agents/recipes/live-canvas-change.md` | `qml/views/LiveCanvasPanel.qml`, `qml/components/AdvancedStyleEditor.qml`, `qml/controllers`, `backend/internal/studio` |
| Style editor | `docs/agents/recipes/style-editor-change.md` | `qml/components/AdvancedStyleEditor.qml`, `qml/features/style-editor`, focused style controls |
| Bar | `docs/agents/recipes/bar-change.md` | `bar`, `OmagenBar.qml`, `NativeBarClone.qml`, `backend/internal/bar`, `barprofile` |
| Look & Feel | `docs/agents/recipes/look-feel-change.md` | `backend/internal/lookfeel`, `qml/views/live-canvas/LookFeelStep.qml` |
| Theme editing | `docs/agents/recipes/theme-edit-change.md` | `backend/internal/themeedit`, `qml/gateways/ThemeGateway.qml`, `qml/controllers/ThemeEditController.qml` |
| Runtime | `docs/agents/recipes/runtime-adapter-change.md` | `backend/internal/runtime`, `bin/studio-theme-set` |
| Packaging | `docs/agents/recipes/packaging-release.md` | `manifest.json`, `bar-manifest.json`, `install.sh`, `scripts`, `.github` |

Use `scripts/agent-context <domain>` to print the compact route for a task.
Read callers and callees only when the change crosses a documented seam.

## Documentation routing

- Current architecture lives under `docs/architecture/`.
- Operational recipes and context routing live under `docs/agents/`.
- User and contributor guides remain under `docs/` and are indexed by
  `docs/README.md`.
- Architectural decisions live under `docs/adr/`.
- Optional roadmaps and implementation plans live under `docs/plans/`; they
  are never a substitute for current source or architecture contracts.
- Do not read `docs/plans/**` unless the task is specifically about planning,
  roadmap work, or historical implementation context.
- Do not automatically read every Markdown file, the whole QML tree, or all
  backend packages. Start with one recipe and expand from dependency evidence.

## Source routing

- Backend commands are adapters over domain packages; command parsing belongs
  under `backend/internal/cli`, while transaction behavior belongs in its
  domain package.
- `qml/gateways` owns bounded backend command seams and `qml/services` owns the
  compatibility façade plus settings/image helpers; views should not spawn the
  backend directly.
- `qml/controllers` owns feature busy/pending state and asynchronous
  Preview/Demo/Apply sequencing; `Omagen.qml` remains the composition root.
- `qml/features/style-editor` owns pure staged-document transformations; it
  must not write files, start backend operations, or own session state.
- `Omagen.qml` is the application composition root. Keep domain state and
  rendering in the nearest bounded QML file when extracting code.
- `OmagenBarWidget.qml` is launcher/status integration. Full bar composition
  belongs under `bar/` and the `pretty.omagen.bar` entry point.

## Testing expectations

For Go changes, run from `backend/`:

```sh
GOCACHE=/tmp/omagen-gocache go test ./...
GOCACHE=/tmp/omagen-gocache go test -race ./...
GOCACHE=/tmp/omagen-gocache go vet ./...
```

For packaging or QML changes, run `GOCACHE=/tmp/omagen-gocache
./scripts/v1-check.sh`; run `qmllint` when available. For lifecycle, Demo,
runtime, or bar changes, state any live Omarchy/Hyprland checks that were not
possible in the current environment. Preserve the bundled backend binary
provenance check when backend sources change.

## Agent skills

### Issue tracker

This repository tracks work in GitHub Issues for `prettyletto/omagen`. See
`docs/agents/issue-tracker.md`.

### Triage labels

Use the repository's default five-role triage vocabulary. See
`docs/agents/triage-labels.md`.

### Domain docs

This repository uses domain-routed architecture documents rather than one
global context file. See `docs/agents/domain.md` and `context-map.yaml`.

### Repo-local live UI skill

For real interactive Omagen testing on the live Omarchy/Hyprland desktop, read
`skills/testing-omagen/SKILL.md` and use `scripts/ui-test`. This skill is scoped
to this repository and does not replace the normal Go, QML, or packaging tests.

## Handoff

Use `docs/agents/handoff-template.md` for a focused handoff. Include the
bounded context, files changed, contracts preserved, tests run, and manual
validation still required.
