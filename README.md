# Omagen

Omagen is an Omarchy Quattro plugin for generating, previewing, and applying
themes from images. It provides a bar widget and an overlay, with optional
Demo integrations for editors, monitors, terminals, and file managers.

## Install

Install the plugin directly through Omarchy:

```sh
omarchy plugin add https://github.com/prettyletto/omarchy-themegen.git --enable --yes
```

That is the complete user installation. Omarchy clones the repository,
validates the manifest, enables the plugin, and places the bar widget in its
declared default section.

## Remove

```sh
omarchy plugin remove pretty.omagen --yes
```

Removing the plugin does not delete user-created permanent themes. Omagen
session state is kept under `~/.local/state/omagen`; it can be removed after
confirming that no session is active.

## Requirements

Required:

- Omarchy Quattro
- Hyprland
- Quickshell
- Linux x86_64 for the bundled V1 backend binary

Omagen's optional Docked bar form is an Omagen-owned additive decoration. It
keeps Quattro's native left/center/right widget layout and falls back to the
normal continuous bar when the active bar does not expose the geometry hooks
needed to draw the three islands.

The backend is bundled at `bin/omagen`; Go is not required for installation.

Demo applications are optional. Omagen resolves available terminals,
editors, monitors, and file managers and provides terminal/source-viewer,
system-info, and file-listing fallbacks when preferred applications are not
available.

## Development

Contributor-only helpers such as `dev-install.sh` and `scripts/v1-check.sh`
are not part of the user installation flow. The repository itself is the
plugin package and must remain runnable directly from its checkout.

Validate a checkout with:

```sh
omarchy plugin validate .
./scripts/v1-check.sh
```

## License

MIT. See [LICENSE](LICENSE).
