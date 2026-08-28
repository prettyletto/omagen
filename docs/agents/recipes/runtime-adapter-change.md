# Runtime adapter change

Read `docs/architecture/contracts/runtime.md`, ADR-0005, runtime package
tests, and only the relevant portions of `bin/studio-theme-set`.

Keep Go runtime models/registry/adapters separate from shell compatibility
orchestration. Normally do not touch palette, Live Canvas, session transaction
internals, or native package files. Preserve scope selection, wait modes,
no-hook defaults, locking, adapter allowlists, and non-fatal post-commit
retint behavior.

Run `go test ./internal/runtime ./internal/omarchy` and shell syntax/smoke
checks; run the full gate for packaging changes. Manual Omarchy checks are
required for compositor/runtime effects. Common trap: shell and Go can both
look like owners while differing in failure semantics.
