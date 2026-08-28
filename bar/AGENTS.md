# Bar agent guide

Start with `docs/agents/recipes/bar-change.md`,
`docs/architecture/product-boundaries.md`, and
`docs/architecture/contracts/bar-spec.md`.

The full Bar is rooted at `OmagenBar.qml` and implemented under `bar/`;
`OmagenBarWidget.qml` is the separate launcher/status widget. Preserve native
Quattro fallback and workspace/input ownership. Use the router and the
relevant horizontal/vertical preset before reading the whole Bar tree.

Run focused `backend/internal/bar` and `barprofile` tests plus the package/QML
gate. Manually check both monitor orientations for layout or interaction
changes.
