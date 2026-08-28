# Packaging or release change

Read `docs/development.md`, `docs/architecture/product-boundaries.md`, the
manifests, `install.sh`, `scripts/v1-check.sh`, and the relevant workflow.

Preserve the two plugin manifests, plugin-relative QML paths, bundled binary
provenance, atomic replacement of running helpers, and the no-symlink package
rule. Normally do not touch domain behavior for a packaging-only change.

Run `GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh`, plus a native
`omarchy plugin validate` when available. Manually verify install/rescan only
on a disposable or known-safe Omarchy setup. Common trap: changing a source
file without rebuilding the checked-in backend binary.
