# ADR-0003: Studio protocol boundary

- Status: Accepted
- Date: 2026-08-28

## Decision

`backend/internal/protocol` owns the durable operation journal, checkpoints,
cursor navigation, and socket observer protocol. Studio and QML request
operations through the CLI/service seam and do not implement a parallel
history store.

## Consequences

Protocol changes require journal/socket/CLI tests and must preserve checkpoint
reapplication semantics. UI navigation remains a consumer of protocol state.
