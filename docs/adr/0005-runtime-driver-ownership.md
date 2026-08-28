# ADR-0005: Runtime driver ownership remains explicit

- Status: Accepted for nightly; consolidation deferred
- Date: 2026-08-28

## Decision

Go `backend/internal/runtime` is the model/adapter authority. The shell
`bin/studio-theme-set` remains a compatibility transaction driver for current
Omarchy path resolution, locking, scopes, hook policy, and post-commit adapter
execution. This rehabilitation documents the seam but does not risk a runtime
rewrite.

## Follow-up trigger

Revisit when a dedicated runtime change can prove parity for scope handling,
wait modes, no-hook defaults, locking, adapter allowlists, and failure
semantics with focused integration coverage.
