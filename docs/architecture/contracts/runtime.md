# Runtime contract

The Go `backend/internal/runtime` package is the model, registry, and adapter
authority for runtime feature status and activation. It covers Shell, Bar,
Window, Animations, Hyprland, and other explicitly registered features without
replacing native Omarchy ownership.

`bin/studio-theme-set` is the installed compatibility/transaction driver. It
contains shell-level integration needed to resolve Omarchy paths, locks, and
post-theme adapter execution. `bin/omagen-theme-set` is the user-facing router:
it validates the generated runtime marker, sends advanced themes to the Studio
driver, and delegates ordinary or malformed themes to native `omarchy theme
set`. The two layers intentionally coexist. A future consolidation must
preserve scopes, wait modes, no-hook defaults, allowlists, locking, and
non-fatal post-commit retint behavior.

The theme-set hook is opt-in and user-owned. Native Omarchy applies native
theme files first; the hook then invokes `bin/omagen runtime theme-set`. If
the plugin or hook is unavailable, native theme application remains valid and
the runtime reports a degraded/native-only result.

The replacement Bar adapter owns one stable native/user baseline for the
entire continuous advanced-runtime interval. An advanced-to-advanced theme
switch must preflight the target, derive its `shell.json` overlay from that
baseline, and preserve the mounted `pretty.omagen.bar` selector while the old
activation is deactivated. This lets the existing Quickshell bar instance
observe the promoted theme spec without briefly mounting Quattro's native bar.
Switching to a native, Fast, inherited, or incompatible Bar restores the exact
baseline and removes the runtime snapshot. Existing per-theme runtime Bar
snapshots are migration inputs only and must not replace the stable baseline.
Bar QML reads the promoted profile and owns only local presentation or explicit
user layout gestures; it does not select or restore the theme-owned bar in
`shell.json`. If the native hook is unavailable, the user-facing router asks
the Go runtime authority to perform the same owner-aware deactivation after
native promotion.

The overlay entry point keeps the Quattro plugin resident without constructing
the heavyweight Live Canvas graph at idle. `Omagen.qml` loads that graph only
for an active workspace, Demo, Apply, or workflow and drops queued actions on
route changes; session state and runtime controllers remain durable and
resident.

When changing runtime behavior, read the runtime package tests and this
contract before touching the shell driver. Do not create a second runtime
authority in QML or in a new Bar component.
