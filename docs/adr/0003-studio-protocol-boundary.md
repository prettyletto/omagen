# ADR-0003: Studio protocol boundary

- Status: Superseded
- Date: 2026-08-28

## Decision

The former `backend/internal/protocol` package owned a durable operation
journal, checkpoints, cursor navigation, and socket observer protocol. That
history system was removed. The session record and the current Go service
seams are now the authority for lifecycle state; Studio and QML do not
maintain a parallel history store.

## Consequences

The session store still removes `protocol/<session>` directories left by older
engines during session cleanup, but no current runtime code writes or reads the
removed protocol format. New lifecycle changes should follow the session and
cleanup contracts instead of reviving the old protocol boundary.
