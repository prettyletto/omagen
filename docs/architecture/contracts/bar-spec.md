# BarSpec and Bar profile contract

BarSpec describes theme-owned Bar geometry, topology, behavior, attention,
motion, and the optional presentation style of the clock. Bar profile data
records the selected profile and the ownership mode used when applying it.
Native `shell.json` widget placement remains a Quattro/user concern unless a
recorded opt-in transaction owns the complete profile.

The clock style is presentation-only. `native` keeps the first-party Omarchy
clock unchanged; `neon`, `matrix`, and `lcd` paint an Omagen face above the
still-mounted native clock. The native clock remains the owner of its calendar
popup, format cycling, timezone action, IPC target, and panel identity.

The full Bar plugin is rooted at `OmagenBar.qml` and loads implementation from
`bar/`. `OmagenBarWidget.qml` is a launcher/status widget in the overlay plugin.
The two entry points must remain separate in their manifests and install
paths. `backend/internal/bar` and `barprofile` define the durable data
contracts; Bar QML renders them and owns local interaction/layout only.

For the horizontal/vertical preset relationship, start with
`bar/BarPresetRouter.qml`, the relevant file under `bar/presets/`, and
`bar/AGENTS.md`.

For a new built-in full-Bar layout, follow the
[Add Bar Preset recipe](../../agents/recipes/bar-change.md). It covers the
separate horizontal and vertical compositions, the QML and Go registries,
profile/Look & Feel checks, and required monitor validation.

## Frozen horizontal compact-float contract

The horizontal compact floating bar is a frozen visual and interaction
contract. Do not change this path as part of a later bar or vertical-layout
change; modify it only when the user explicitly requests a horizontal
compact-float change.

Its geometry is defined by the current `BarSurface.qml` and
`bar/CompactTrayWidget.qml` implementation:

- The main surface is a content-sized rounded pill containing the left,
  center, and right semantic groups. The right group uses
  `bar.entriesWithoutTray(...)`, so the tray never contributes to the pill's
  measured width.
- The tray is a separate bordered surface to the right of the main pill, with
  a fixed gap. It is resolved through `bar.trayEntry(...)` and remains its own
  `WidgetSlot` so its drawer cannot move or resize the main pill.
- The collapsed tray reserves one icon slot even when no StatusNotifier item
  is currently registered. The chevron is first; drawer items follow it;
  pinned items follow the drawer.
- Expanding the tray grows outward to the right from its left edge beside the
  main pill. It must not expand left over the main pill or shift the main
  pill's centered position, except for unavoidable monitor-edge clamping.
- The vertical compact-float composition is independent and lives in
  `bar/presets/FloatingVerticalBar.qml`; do not transpose horizontal geometry
  into that file.

`NativeBarClone.qml` is a maintained Quattro compatibility fork, documented in
[`quattro-native-clone.md`](quattro-native-clone.md). Do not decompose it as
part of ordinary Bar preset or host work.
