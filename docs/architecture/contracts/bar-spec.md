# BarSpec and Bar profile contract

BarSpec describes theme-owned Bar geometry, topology, behavior, attention, and
motion. Bar profile data records the selected profile and the ownership mode
used when applying it. Native `shell.json` widget placement remains a
Quattro/user concern unless a recorded opt-in transaction owns the complete
profile.

The full Bar plugin is rooted at `OmagenBar.qml` and loads implementation from
`bar/`. `OmagenBarWidget.qml` is a launcher/status widget in the overlay plugin.
The two entry points must remain separate in their manifests and install
paths. `backend/internal/bar` and `barprofile` define the durable data
contracts; Bar QML renders them and owns local interaction/layout only.

For the horizontal/vertical preset relationship, start with
`bar/BarPresetRouter.qml`, the relevant file under `bar/presets/`, and
`bar/AGENTS.md`.

`NativeBarClone.qml` is a maintained Quattro compatibility fork, documented in
[`quattro-native-clone.md`](quattro-native-clone.md). Do not decompose it as
part of ordinary Bar preset or host work.
