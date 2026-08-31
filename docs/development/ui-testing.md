# Real desktop UI testing

Omagen's QML runs inside the user's long-lived Omarchy Quickshell process. A
useful UI test therefore needs the real Hyprland, Wayland, and shell session;
QML linting and backend tests cannot verify layer-shell geometry, keyboard
focus, rendering, or the interaction between the overlay and the native bar.

The repository provides `scripts/ui-test`, a small host-side adapter around the
existing desktop tools. It does not start a second Quickshell, edit Hyprland
configuration, kill applications, or manage Omagen's session/recovery state.
Run it from the repository root:

```sh
scripts/ui-test check
scripts/ui-test clients
scripts/ui-test layers
scripts/ui-test summon
scripts/ui-test wait-window 'layer:omagen-' 10
scripts/ui-test screenshot
scripts/ui-test key down
scripts/ui-test key enter
scripts/ui-test type 'example text'
scripts/ui-test move 896 450
scripts/ui-test hide
```

The default screenshot is written to `.tmp/ui-tests/latest.png`, which is
ignored by Git. Pass an absolute path or a repository-relative path to
`screenshot` when a named capture is useful. After every visual change,
inspect the captured PNG itself; source inspection and `qmllint` are not visual
verification.

## Session and host access

The helper discovers these values rather than baking in boot-specific values:

- `XDG_RUNTIME_DIR`, defaulting to `/run/user/<uid>` only when unset.
- `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`, discovered from
  `hyprctl instances -j` when unset.
- `DBUS_SESSION_BUS_ADDRESS`, defaulting to the session bus under the runtime
  directory when unset.

When Codex's restricted process cannot reach the Hyprland socket, Wayland
display, DBus, or launched desktop processes, run the helper with host/full
desktop access. This is an execution permission for the developer command, not
a repository or system-wide security change. The helper fails with a clear
message instead of pretending a filesystem-only run tested the GUI.

The current development machine has Hyprland 0.56.2, Quickshell 0.3.1,
Omarchy 4.0.1-1, `grim`, `jq`, `wtype`, and the `omarchy-shell` IPC wrapper.
`wtype` supplies user-level key and text input through the Wayland
virtual-keyboard protocol. Pointer injection is optional: `click` only runs
when an already configured `ydotool` and `ydotoold` are present and
`/dev/uinput` exists. The helper never starts a daemon as root or changes
input-device permissions. Prefer keyboard navigation and semantic
shell/Hyprland operations whenever possible.

Hyprland 0.55 and newer use the Lua dispatcher API. The helper uses
`hl.dsp.cursor.move`, `hl.dsp.focus`, and the JSON APIs instead of relying on
the older hyprlang dispatcher spelling.

## Surface lookup

Omagen's overlay is a layer-shell surface, not a normal Hyprland client. Use
both JSON endpoints:

```sh
scripts/ui-test clients
scripts/ui-test layers
scripts/ui-test wait-window 'namespace=omagen-setup'
```

Selectors accept a bare substring or `field=value` for `address`, `class`,
`initialClass`, `title`, `initialTitle`, `pid`, `workspace`, `namespace`, and
`monitor`. Prefixes `client:` and `layer:` constrain the match. `focus` is
intentionally limited to ordinary clients because layer surfaces own their
keyboard focus through Quickshell; use `summon` for Omagen.

## Safe test lifecycle

Use the shell IPC path that production uses:

```sh
scripts/ui-test summon
scripts/ui-test screenshot
# interact with the UI using key/type and inspect another screenshot
scripts/ui-test hide
```

For tests that begin a temporary preview session, finish through Omagen's
Cancel/restore path. Do not delete `~/.local/state/omagen`, generated themes,
workspaces, or backgrounds as test cleanup. Do not use broad `pkill`; the
running shell owns the plugin and its lifecycle.

## Development loop

For a QML/UI change, follow the repository checks first, then use the live
desktop loop:

1. Run `qmllint` when available and `GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh`.
2. Install or synchronize the checkout with the normal development workflow
   when needed (`./dev-install.sh`), allowing the shell to rescan the plugin.
3. Run `scripts/ui-test summon` and wait for the expected `omagen-*` layer.
4. Capture with `scripts/ui-test screenshot` and inspect the PNG visually.
5. Exercise keyboard-first paths with `key`/`type`; use `move` and `click` only
   for controls that cannot be reached semantically.
6. Hide or Cancel the overlay, make the next change, and repeat.

The current repository may contain a dirty worktree from other work. The UI
helper only creates the ignored `.tmp/ui-tests/` directory and does not modify
those unrelated files.
