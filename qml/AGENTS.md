# QML agent guide

Start with `docs/agents/recipes/qml-ui-change.md` or
`docs/agents/recipes/live-canvas-change.md`, then read
`docs/architecture/frontend.md` and
`docs/architecture/contracts/qml-backend.md`.

`Omagen.qml` composes routing, state, gateways, and views. Views/components
render and emit intent; services/gateways own bounded process access. Keep the
Go JSON argv and signal payload contract unchanged. QML does not own durable
session, Apply, recovery, palette, or native desktop state.

Run `qmllint` when available and `GOCACHE=/tmp/omagen-gocache
./scripts/v1-check.sh` from the repository root. Manually exercise the
affected route in the running Quickshell when possible.
