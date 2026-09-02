# Omarchy theme pipeline inventory

Inventory captured on 2026-08-22; validate the recorded package boundary with
the companion lock file and drift check before relying on it after an Omarchy
update.

This document records the installed Omarchy theme-set boundary used by Omagen.
It is an inventory of the local runtime, not a promise that package-owned
paths or hashes remain unchanged after an Omarchy update. The companion
[`omarchy-theme-pipeline.lock`](omarchy-theme-pipeline.lock) and
[`../scripts/omarchy-theme-pipeline-drift.sh`](../scripts/omarchy-theme-pipeline-drift.sh)
make that change detectable.

## Runtime snapshot

The inventory was captured from the active machine with the following values:

| Item | Observed value |
| --- | --- |
| Omarchy version | `4.0.0-1` |
| Omarchy source root | `/usr/share/omarchy` (the resolved target of `~/.local/share/omarchy`) |
| Theme-set driver | `/usr/bin/omarchy-theme-set` |
| Theme-set driver SHA-256 | `9dd2872607a7dc057a2b492c9b3ce62c9fcac002a487e3109b0353b4973204fc` |
| Template generator | `/usr/bin/omarchy-theme-set-templates` |
| Template generator SHA-256 | `add9154d012c12b5628128d71efcf216ed62024cef2370e3c5c470378c06d45f` |
| Hook runner | `/usr/bin/omarchy-hook` |
| Hook runner SHA-256 | `c64ea844feb1849375e7cd43dde98933293b0e0f0f522e1ba2c6572d86386c7b` |
| Quickshell | `0.3.0`, revision `28771c7c74b42e20afca0b1b63980cb46515537c` |
| Current theme | `Totoro` / normalized name `totoro` |
| Hyprland IPC version | Not verified: `hyprctl version` timed out on the shell socket during capture |

The source hashes identify the installed package-owned orchestration scripts.
They are compatibility evidence for the driver boundary, not permission to
edit `/usr/share/omarchy`.

## Theme source precedence

`omarchy-theme-set <name>` normalizes the name to lowercase kebab case and
accepts the theme when it exists in either source root:

```text
/usr/share/omarchy/themes/<name>/
~/.config/omarchy/themes/<name>/
```

For a selected theme, the installed driver creates a clean staging directory
at `~/.local/state/omarchy/current/next-theme/`, then applies this precedence:

```text
official stock theme
    ↓ copy first
user theme with the same name
    ↓ copy second; matching paths overlay stock files
next-theme staging directory
```

If the staged theme has no `colors.toml` but does have `alacritty.toml`,
Omarchy derives `colors.toml` from Alacritty before template generation.
Studio must preserve this fallback rather than assume every source theme ships
the canonical palette file.

Background selection is separate from config overlay. The driver searches
`~/.config/omarchy/backgrounds/<name>/` and the current theme's `backgrounds/`
directory, sorts the candidates, and updates the
`~/.local/state/omarchy/current/background` symlink. A theme can therefore
inherit user-supplied backgrounds without placing them in the theme source.

## Template inventory

The installed template generator reads built-in templates from:

```text
/usr/share/omarchy/default/themed/*.tpl
```

It also reads optional user templates from:

```text
~/.config/omarchy/themed/*.tpl
```

The current machine has one user sample (`alacritty.toml.tpl.sample`, which is
not active) and these built-in templates:

```text
alacritty.toml.tpl          btop.theme.tpl
chromium.theme.tpl          claude.json.tpl
foot.ini.tpl                ghostty.conf.tpl
gum_env.lua.tpl             helix.toml.tpl
hyprland-preview-share-picker.css.tpl
hyprland.lua.tpl            keyboard.rgb.tpl
kitty.conf.tpl              neovim.lua.tpl
obsidian.css.tpl            pi.json.tpl
shell.toml.tpl              vscode-theme.json.tpl
```

The generator reads all color aliases from the staged `colors.toml`, expands
plain tokens, RGB/stripped variants, `mix` tokens, and gradient functions, and
then processes user templates before built-in templates. Despite that order,
an existing file copied from the theme-specific directory is never overwritten
by a template. The effective rule is therefore:

```text
theme-specific file > generated template > no output
```

Finally, `shell.<section>.toml` files in the staged directory replace the
corresponding section in generated `shell.toml`. This is an explicit section
override and must be treated separately from ordinary `.tpl` generation.

## Generated outputs and real readers

The output directory is the promoted
`~/.local/state/omarchy/current/theme/`. The table distinguishes native readers
from Omagen-owned metadata.

| Output | Runtime reader or consumer | Ownership/evidence |
| --- | --- | --- |
| `colors.toml` | Quickshell `shell/Commons/Color.qml` | Native shell palette input |
| `shell.toml` | Quickshell `Color.qml` and `Style.qml`; shell surface bindings | Native shell surface/style input; user `~/.config/omarchy/shell.toml` keys win when duplicated |
| `shell.<section>.toml` | Consumed by the template generator while building `shell.toml` | Staging-time input, not a general native shell reader |
| `hyprland.conf` | `~/.config/hypr/hyprland.conf` source line 14 | Native Hyprland config, loaded before user override files |
| `hyprland.lua` | No active reader for the current user's `hyprland.conf` path was found during capture; the user has a separate `~/.config/hypr/hyprland.lua` | Potentially supported theme output, but not live proof on this installation |
| `alacritty.toml` | `/usr/share/omarchy/config/alacritty/alacritty.toml` import | Native Alacritty import |
| `kitty.conf` | `/usr/share/omarchy/config/kitty/kitty.conf` include | Native Kitty include |
| `foot.ini` | `omarchy-theme-set-foot` retint command | Native Foot retint path |
| `btop.theme` | Omarchy user theme symlink created by `install/user/theme.sh` | Native btop theme path |
| `neovim.lua` | Active `~/.config/nvim/lua/plugins/theme.lua` symlink | Native Neovim theme path |
| `background` symlink | Quickshell Background and Lock services; Hyprlock config | Native live wallpaper/lock input |
| app outputs (`ghostty.conf`, `helix.toml`, `neovim.lua`, `vscode-theme.json`, etc.) | Their respective post-theme commands and application config paths | Applied by explicit Omarchy retint commands, not by one universal shell reader |
| `shell.json` | Quickshell shell startup and `PluginRegistry.qml` | User/default shell layout; not generated by the theme templates |
| `omagen.bar.toml` | Omagen `DockedBarSurface.qml` | Compatibility metadata retained for older generated themes |
| `omagen.bar.json` | Omagen bar-profile adapter and `DockedBarSurface.qml` | Versioned theme-bounded bar behavior; user `shell.json` is changed only through a reversible profile transaction |
| `omagen.bar.spec.json` | Omagen `DockedBarSurface.qml` and BarSpec compiler | Versioned surface/geometry/topology/behavior document; continuous native values reach `shell.toml`, while Minimal and other advanced values select the Omagen replacement host |

The current generated directory also contains Omagen's
`shell.bar.toml`, `shell.controls.toml`, `shell.launcher.toml`,
`shell.menu.toml`, and `shell.popups.toml`. These are section overrides merged
into the generated `shell.toml` by Omagen. They are retained as inspectable
section artifacts and are not independently loaded by Quickshell.

## Shell payload and IPC

After promoting the staged theme, Omarchy base64-encodes the current
`colors.toml` and `shell.toml`. In a normal session it first asks
`omarchy-shell` to run:

```text
background themeTransition <old-snapshot> <new-snapshot> <new-path> <colors-payload> <shell-payload>
```

If the transition cannot run, or there is no usable background, it falls back
to:

```text
shell applyTheme <colors-payload> <shell-payload>
```

Headless/offline mode skips the session IPC and only maintains the current
background link when requested. The shell then reads the promoted files from
the current theme directory. The separate user shell file
`~/.config/omarchy/shell.toml` is loaded after the theme file, and duplicate
user keys override theme keys. This is why Studio must not write over that
user-owned file when it generates theme-specific shell sections.

The bar composition file `~/.config/omarchy/shell.json` is a separate user
reader. `omagen.bar.json` is therefore an Omagen profile input, not a native
Quattro layout file. When a profile owns bar layout or selects a replacement,
the backend captures the exact `shell.json` bytes (plus the native bar-off
toggle), applies the profile through a reversible adapter, and restores that
snapshot on Cancel, Restore, theme replacement, or crash recovery. Inherit and
visual-only profiles leave the user layout untouched.

## Hyprland load and override ordering

The active `~/.config/hypr/hyprland.conf` loads the current theme at this point:

```text
Omarchy default autostart/bindings/env/looknfeel/input/windows
    ↓
~/.local/state/omarchy/current/theme/hyprland.conf
    ↓
~/.config/hypr/monitors.conf
~/.config/hypr/input.conf
~/.config/hypr/bindings.conf
~/.config/hypr/envs.conf
~/.config/hypr/looknfeel.conf
~/.config/hypr/autostart.conf
~/.config/hypr/conf.d/*.conf
    ↓
~/.local/state/omarchy/toggles/hypr/*.conf
```

Later user and toggle sources can override theme values. A Studio preview must
report the theme output as staged/loaded only after the relevant Hyprland
reader has accepted it; a generated file or a successful QML parse is not
visual proof.

## Post-apply retint and hooks

After the critical theme promotion and shell transition, the installed driver
starts these application retint commands in parallel:

```text
omarchy-restart-terminal       omarchy-restart-hyprctl
omarchy-restart-btop           omarchy-restart-opencode
omarchy-restart-helix          omarchy-theme-set-foot
omarchy-theme-set-tmux         omarchy-theme-set-gnome
omarchy-theme-set-pi           omarchy-theme-set-claude
omarchy-theme-set-browser      omarchy-theme-set-vscode
omarchy-theme-set-obsidian     omarchy-theme-set-keyboard
```

The driver waits for these parallel processes, then invokes:

```text
omarchy-hook theme-set <normalized-theme-name>
```

The hook runner executes the optional single file
`~/.config/omarchy/hooks/theme-set` first, then every non-`.sample` regular
file in `~/.config/omarchy/hooks/theme-set.d/` in glob order. Each file is
run with Bash; a failure is printed and does not stop the following hook.

The active machine has executable theme-set hooks for Cava and keyboard RGB,
plus a timestamped backup and a disabled Waybar script. The keyboard hook can
reach OpenRGB/keyboard services, so Studio preview must not call arbitrary user
hooks. Native theme application and Studio preview require distinct
allowlists and side-effect policies.

After hooks, Omarchy warms the theme switcher and background caches. These are
performance operations and are outside the critical promotion boundary.

## Drift policy

`scripts/omarchy-theme-pipeline-drift.sh` is a read-only compatibility check.
It compares the installed Omarchy version and the SHA-256 hashes of the
theme-set driver, template generator, and hook runner with the recorded N1
lock values. It also reports the resolved Omarchy root, active theme, template
count, and current-background target.

`PASS` means the inspected package-owned boundary matches the captured
contract. `DRIFT` means Studio needs a compatibility review before it can
claim that a source-derived driver still matches the installed pipeline. The
check does not edit Omarchy files, change the active theme, reload Hyprland, or
execute theme-set hooks.
