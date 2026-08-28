# Bar change

Read `docs/architecture/product-boundaries.md`,
`docs/architecture/contracts/bar-spec.md`, `bar/AGENTS.md`, then the relevant
preset/router/widget files. For data changes also read `backend/internal/bar`
and `barprofile` tests.

Keep `OmagenBarWidget.qml` as launcher/status integration and the full Bar
under `OmagenBar.qml` plus `bar/`. Normally do not touch palette, Apply,
session recovery, or Live Canvas. Preserve native Quattro fallback, workspace
state ownership, profile ownership modes, topology/geometry semantics, and
horizontal/vertical direction handling.

Run focused Bar/barprofile Go tests and the full QML/package gate. Manually
check the affected preset on horizontal and vertical monitors, including tray
expansion and interaction direction. Common trap: a visual fix in one preset
can alter a shared router or native clone path.
