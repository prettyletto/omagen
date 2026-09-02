# Product boundaries

Omagen has two packaged plugin products. They share source and the bundled Go
backend, but Omarchy registers and loads them as separate plugin kinds:

| Product | Manifest | Entry point | Ownership |
| --- | --- | --- | --- |
| Overlay + launcher/status widget | `manifest.json` (`pretty.omagen`) | `Omagen.qml`, `OmagenBarWidget.qml` | Opens the Studio overlay and exposes a small bar integration. |
| Full Bar plugin | `bar-manifest.json` (`pretty.omagen.bar`) | `OmagenBar.qml` | Renders the replacement/full bar and its presets. |

The launcher widget may summon the overlay through the already-running Omarchy
shell. It does not start a second Quickshell instance and does not own session,
generation, Preview, Demo, Apply, or recovery logic. The full Bar plugin
consumes BarSpec/profile data and native shell integrations but does not become
a second theme engine or lifecycle owner.

The backend remains the shared durable authority. QML views, Bar QML, native
Omarchy, and the runtime adapters meet through explicit data/protocol seams.

## Install payloads

`install.sh` installs the products independently:

- `~/.config/omarchy/plugins/pretty.omagen/` contains the overlay entry
  points, `qml/`, the shared backend executable, Studio/runtime helpers, Demo
  assets, and the `bar/BarSizing.js` helper used by the overlay.
- `~/.config/omarchy/plugins/pretty.omagen.bar/` contains the full-Bar entry
  point, Bar host files, `bar/` presets/widgets, the maintained Quattro clone,
  and compiled shader assets.

Neither manifest may absorb the other product's entry point or ownership.
