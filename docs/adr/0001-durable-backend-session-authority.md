# ADR-0001: Durable backend session authority

- Status: Accepted
- Date: 2026-08-28

## Decision

The Go session store and `session.Service` are the authority for active-session
identity, original theme/background, generation linkage, preview direction, and
resumability. QML may mirror this state for presentation but cannot be the
source of truth.

## Rationale

The overlay and shell can reload independently of filesystem and compositor
state. A durable backend record keeps Resume, Cancel, Quit, and recovery
correct when the UI disappears.

## Consequences

Changes to lifecycle state start in `backend/internal/session` and its tests;
frontend extraction must preserve the existing commands and signals.
