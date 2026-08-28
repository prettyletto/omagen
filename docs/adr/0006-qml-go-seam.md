# ADR-0006: QML ↔ Go process seam

- Status: Accepted
- Date: 2026-08-28

## Decision

QML owns visible coordination and calls the bundled backend through a bounded
process/gateway seam. Go owns command validation, JSON responses, durable state,
and native mutations. Generic process execution may be extracted from domain
gateways as long as the established wire contract remains unchanged.

## Consequences

Views should not spawn the backend directly. Gateway tests and CLI contract
tests protect the seam; domain packages remain the place for behavior changes.
