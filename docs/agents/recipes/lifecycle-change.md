# Lifecycle or recovery change

Read `docs/architecture/lifecycle.md`,
`docs/architecture/contracts/engine.md`, `docs/agents/invariants.md`, and ADRs
0001–0002. Start in `backend/internal/session`, `apply`, `preview`, and
`cleanup`; inspect `omarchy` only for the native adapter seam.

Normally do not touch QML cleanup logic, Bar code, palette internals, or runtime
driver code. Preserve durable baseline capture, ownership markers, idempotent
cleanup, recoverability after interruption, and verification before clearing a
session.

Run focused package tests plus `go test ./...` and `go test -race ./...`.
Manual Omarchy/Hyprland checks are required when native restoration is changed.
Common trap: a successful command invocation is not a committed transaction.
