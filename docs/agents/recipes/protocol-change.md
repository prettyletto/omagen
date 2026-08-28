# Protocol change

Read `docs/architecture/contracts/studio-protocol.md`, ADR-0003, the relevant
`backend/internal/protocol` files, CLI protocol adapter, and QML protocol
consumer.

Keep journal persistence, checkpoint navigation, cursor movement, and socket
streaming in the protocol package. Normally do not touch palette, Bar, or
session baseline semantics unless the change explicitly crosses those seams.

Run `go test ./internal/protocol ./internal/cli` and the full Go checks. Manual
validation should cover inspect, events, back, forward, and failed reapply.
Common trap: moving the cursor before native checkpoint reapplication succeeds.
