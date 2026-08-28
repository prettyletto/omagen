# ADR-0002: Apply and recovery ownership

- Status: Accepted
- Date: 2026-08-28

## Decision

`apply.Service` owns staged Apply, commit markers, pending recovery, and the
handoff to restoration. `session.Service`, `preview.Service`, and
`cleanup.Service` retain their documented parts of Cancel/Restore cleanup.

## Rationale

Apply can be interrupted after native mutation. One backend ownership model is
needed to distinguish Omagen-owned prepared state from unrelated user files.

## Consequences

Do not move transaction logic into QML, shell views, or the runtime driver
during structural refactors. Add tests at the domain interface before changing
ownership.
