# QML agent guide

Start with `docs/agents/recipes/qml-ui-change.md` or
`docs/agents/recipes/live-canvas-change.md`, then read
`docs/architecture/frontend.md` and
`docs/architecture/contracts/qml-backend.md`.

`Omagen.qml` composes routing, durable-session views, controllers, gateways,
and visual surfaces. Views/components render and emit intent; gateways own
bounded process access; controllers own feature busy/pending state and
asynchronous sequencing. Keep the Go JSON argv and signal payload contract
unchanged. QML does not own durable session, rollback, palette, or native
desktop state.

Start lifecycle work in `qml/controllers/` after reading the lifecycle recipe.
`ApplyController.qml`, `DemoController.qml`, and `PreviewController.qml` are
the current frontend state-machine boundary. Do not bypass them by adding
another Apply/Demo/Preview handler to `Omagen.qml`.

For Window or Animations styling, use the focused style-editor recipe and
`qml/features/style-editor/`. Do not load lifecycle controllers or Bar runtime
files for a pure style-document transformation.

Run `qmllint` when available and `GOCACHE=/tmp/omagen-gocache
./scripts/v1-check.sh` from the repository root. Manually exercise the
affected route in the running Quickshell when possible.
