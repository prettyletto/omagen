# Bar agent guide

Start with `docs/agents/recipes/bar-change.md`,
`docs/architecture/product-boundaries.md`, and
`docs/architecture/contracts/bar-spec.md`.

The full Bar is rooted at `OmagenBar.qml` and implemented under `bar/`;
`OmagenBarWidget.qml` is the separate launcher/status widget. Preserve native
Quattro fallback and workspace/input ownership. Use the router and the
relevant horizontal/vertical preset before reading the whole Bar tree.

`bar/BarPresetRouter.qml` maps stable preset IDs to wrapper QML files;
`BarModel.js`, `backend/internal/bar`, and `backend/internal/barprofile` own
the corresponding model/profile vocabulary. A normal preset change should not
touch session, palette, or native-clone code. Keep `pretty.omagen` and
`pretty.omagen.bar` as separate manifests and installed products.

`NativeBarClone.qml` is vendor/upstream compatibility code. Read
`docs/architecture/contracts/quattro-native-clone.md` when the task concerns
that clone; do not normally modify or split it for a preset or host change.

Run focused `backend/internal/bar` and `barprofile` tests plus the package/QML
gate. Manually check both monitor orientations for regions, tray growth,
workspace interactions, popup anchoring, click targets, and edge alignment.
Record unavailable live Omarchy checks in the handoff.
