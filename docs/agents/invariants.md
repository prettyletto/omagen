# Cross-context invariants

- Durable session state, not QML, owns rollback and recovery truth.
- Every destructive cleanup operation must prove Omagen ownership.
- Preview aliases and Demo workspaces are temporary and session-scoped.
- Apply commits only after the staged destination and native state are
  consistent; interrupted state remains recoverable.
- The six generation variants and palette/color math are stable engine
  contracts.
- QML/backend JSON, stdout/stderr, and exit semantics are compatibility
  surfaces.
- Native Omarchy/Quattro remains the fallback and owner where the contract
  says `native` or `inherit`.
- Full Bar and launcher/status widget are different plugin products.
- Runtime post-commit retint failures do not make the core theme transaction
  appear uncommitted.
- A structural extraction should preserve source ownership, ordering,
  asynchronous signal behavior, and cleanup guarantees.
