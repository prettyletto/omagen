# Lifecycle or recovery change

Read `docs/architecture/lifecycle.md`,
`docs/architecture/contracts/engine.md`, `docs/agents/invariants.md`, and ADRs
0001–0002. Start in `backend/internal/session`, `apply`, `preview`, and
`cleanup`; read `docs/architecture/contracts/qml-controllers.md` and inspect
`qml/controllers/ApplyController.qml` and `DemoController.qml` when the
frontend sequencing is involved. Inspect `omarchy` only for the native adapter
seam.

Normally do not touch QML view rendering, Bar code, palette internals, or
runtime driver code. Preserve durable baseline capture, ownership markers,
idempotent cleanup, recoverability after interruption, and verification before
clearing a session. Controllers coordinate these operations but never replace
the backend cleanup authority.

Run focused package tests plus `go test ./...` and `go test -race ./...`.
Manual Omarchy/Hyprland checks are required when native restoration is changed.
Common trap: a successful command invocation is not a committed transaction.
