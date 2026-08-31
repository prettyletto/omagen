<div align="center">

# Omagen

**An image-to-theme studio for Omarchy Quattro**

Generate a palette from an image, explore six directions, preview the result
on your desktop, and apply the one that feels right.

Omagen is the complete renewed product: the overlay and launcher widget,
reversible Live Canvas previews, optional desktop composition, Demo, Apply, and
recovery. Its full-bar implementation remains a separate, opt-in Omarchy
plugin.

</div>

![Omagen demo](assets/omagen-demo.gif)

## Video walkthrough

[![Watch the Omagen walkthrough](https://img.youtube.com/vi/Af06-XsdBHA/maxresdefault.jpg)](https://youtu.be/Af06-XsdBHA)

Watch the full walkthrough on [YouTube](https://youtu.be/Af06-XsdBHA).

## Install the renewed product

The current renewed product is on the `dev` branch. Install that branch with
the repository bootstrap:

~~~sh
OMAGEN_TEST_BRANCH=dev \
  bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/prettyletto/omagen/dev/scripts/install-branch.sh | bash'
~~~

The bootstrap clones `dev` into a temporary directory, installs the complete
overlay package (`pretty.omagen`) and the separate full-bar package
(`pretty.omagen.bar`), enables the overlay, rescans the shell, and removes the
temporary checkout. The backend binary is bundled, so Go is not required. The
full-bar package is installed separately because Quattro treats a full bar and
a bar-widget plugin as different product kinds; selecting a replacement bar is
still opt-in.

For a local checkout, contributors can use:

~~~sh
./dev-install.sh
~~~

See [Development](docs/development.md) for the local workflow.

### Test another branch or fork

The same bootstrap can install another branch or repository. Set the source
variables before piping the script from the renewed `dev` branch:

~~~sh
OMAGEN_TEST_BRANCH=my-branch \
  OMAGEN_TEST_REPOSITORY=https://github.com/your-name/omagen.git \
  bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/prettyletto/omagen/dev/scripts/install-branch.sh | bash'
~~~

This replaces the installed Omagen package files for both plugin IDs. Use it
when you intentionally want to switch the checkout being tested.

## How it works

| Step | In Omagen | Result |
| --- | --- | --- |
| 1 | Choose an image | Omagen extracts representative colors. |
| 2 | Explore the gallery | Six directions are generated: Source, Calm, Mute, Deep, Vibrant, and Balanced. |
| 3 | Preview and test | Activate a direction for a Live Canvas Preview; use Test Live for staged composition changes or open a temporary Demo workspace. |
| 4 | Apply the result | Save a named, permanent Omarchy theme. |

The preview uses the same production palette and semantic-contrast pipeline as
the applied theme, so the gallery represents the colors that will actually be
written to the theme.

## Examples

### Kanaawesome — Kanagawa Waves

An image-derived Omagen theme generated from a Kanagawa-style wave wallpaper:

<p align="center">
  <img src="assets/examples/midnight-waves-wallpaper.webp" alt="Kanaawesome source wallpaper" width="480">
  <img src="assets/examples/midnight-waves-theme.webp" alt="Kanaawesome generated Omagen theme" width="480">
</p>

### NieR:Automata — 2B Sunset

An image-derived Omagen theme generated from a NieR:Automata-inspired wallpaper:

<p align="center">
  <img src="assets/examples/2b-sunset-wallpaper.webp" alt="NieR:Automata source wallpaper" width="480">
  <img src="assets/examples/2b-sunset-theme.webp" alt="NieR:Automata generated Omagen theme" width="480">
</p>

### Ushinawareta — 失われた

An image-derived Omagen theme generated from a neon anime wallpaper:

<p align="center">
  <img src="assets/examples/ushinawareta-wallpaper.webp" alt="Ushinawareta source wallpaper" width="480">
  <img src="assets/examples/ushinawareta-theme.webp" alt="Ushinawareta generated Omagen theme" width="480">
</p>

### Neon Blue

An image-derived Omagen theme generated from a blue scanline anime wallpaper:

<p align="center">
  <img src="assets/examples/neon-blue-wallpaper.webp" alt="Neon Blue source wallpaper" width="480">
  <img src="assets/examples/neon-blue-theme.webp" alt="Neon Blue generated Omagen theme" width="480">
</p>

See the [Examples gallery](docs/examples.md) for the complete set of generated themes.

## Features

- Image-derived Omarchy palettes with six visual directions.
- Palette Preview and explicit Test Live inside a recoverable Omagen session.
- Optional Window, Shell, and Bar composition previews, including animated
  borders, border thickness, inactive-window treatment, shell feedback
  surfaces, and Docked-bar visibility.
- Temporary Demo workspace with editor, terminal, system-monitor, and
  file-manager views.
- Capability detection and useful fallbacks when preferred Demo applications
  are unavailable.
- Optional Plymouth unlock-screen artwork.
- Optional capture of the live Demo workspace as `preview.png`.
- Keyboard and mouse navigation, including arrows and `h/j/k/l`.
- Crash-safe Apply, Cancel, Quit, and recovery flows.

The optional composition controls shape generated theme files without taking
ownership of Quattro's native widget layout, ordering, transparency, or input.
See [Styling and palette settings](docs/styling.md) for the complete option
matrix.

## Screenshots

### Using Omagen

Start with an image, review the generated directions, and tune the palette
defaults from Settings:

<p align="center">
  <img src="assets/screenshots/onboarding.webp" alt="Omagen setup" width="320">
  <img src="assets/screenshots/settings.webp" alt="Omagen settings" width="320">
</p>

<p align="center">
  <img src="assets/screenshots/palette-gallery.webp" alt="Omagen palette gallery" width="960">
</p>

### Extra desktop composition

Enable the optional composition step to preview how the generated palette can
shape Window, Shell, and Bar surfaces while keeping Quattro's native layout:

![Omagen Window styling](assets/screenshots/extras-window.webp)

![Omagen Shell styling](assets/screenshots/extras-shell.webp)

![Omagen Bar styling](assets/screenshots/extras-bar.webp)

## First run

After installation, click the Omagen widget in the Quattro bar:

1. On the first open, review the optional user-level Advanced Runtime setup.
   It installs only Omagen's theme-set hook and runtime state; it does not use
   sudo, install packages, or change the current theme. **Use native mode** is
   always available.
2. Choose an image.
3. Optionally enable extra Window, Shell, and Bar configuration previews.
4. Select a palette direction.
5. Activate a palette card to **Preview** it on the Live Canvas. In-depth users
   can use **Test Live** for staged Window, Shell, Bar, Animation, or custom
   colour changes, open **Start Full Demo** for the four-window workspace, or
   use the read-only **Bar Demo**. Bar Demo previews the staged bar below the
   real native bar; it does not replace Quattro's widgets or input ownership.

Use **Cancel** to restore the original theme and background. If Omagen is
interrupted during a preview, its next launch offers **Restore & close** or
**Resume** when the generated workspace is still available.

Right-click the bar widget for **Open**, **Settings**, and **Quit**. Quit uses
the same restore path as Cancel when an active session exists.

## Requirements and integration

- Omarchy Quattro
- Hyprland
- Quickshell
- Linux x86_64 for the bundled backend binary

Demo applications are optional. Omagen resolves available terminals, editors,
monitors, and file managers and provides fallbacks when a preferred
application is not installed.

Omagen preserves Quattro's native left, center, and right widget layout. Its
optional Docked bar form is an additive surface beneath the native widgets when
the native bar is opaque. Native transparency intentionally keeps this
decoration transparent, while the explicit Show islands policy can keep it
visible over a transparent native bar. Native widgets, layout, and input remain
Omarchy-owned. It falls back to the normal continuous bar when the active shell
does not expose the geometry hooks required for the three section surfaces.

Bar profiles are theme-bounded. A profile that only styles or decorates the
native bar leaves the user's layout untouched. A profile that explicitly owns
the layout or selects a replacement is applied through a reversible adapter:
Omagen snapshots the exact user `shell.json` (and the native bar hidden toggle)
before applying it, then restores that snapshot on Cancel, Restore, theme
switch, or recovery. Replacement bars remain opt-in and must provide a native
Quattro fallback.

## Documentation

| Guide | Audience | Covers |
| --- | --- | --- |
| [Usage](docs/usage.md) | Users | The complete workflow from image selection to Apply. |
| [Styling and palette settings](docs/styling.md) | Users | Harmony, contrast, Window, Shell, Bar, and generated assets. |
| [Demo workspace](docs/demo.md) | Users | Temporary workspaces, capability resolution, fallbacks, and preview capture. |
| [Recovery and safety](docs/recovery.md) | Users and maintainers | Sessions, Cancel, Quit, Apply safety, and cleanup boundaries. |
| [Development](docs/development.md) | Contributors | Local installation, tests, linting, and the validation gate. |
| [Architecture](docs/architecture/README.md) | Contributors | The plugin contract, QML/backend boundary, generation pipeline, and lifecycle. |

The [documentation index](docs/README.md) mirrors this table. Contributors
should also start with the [agent navigation guide](AGENTS.md) and its
[bounded-context recipes](docs/agents/README.md). The
[mdBook summary](SUMMARY.md) provides the rendered documentation navigation.

## Remove

To remove Omagen completely, including the separate full-bar plugin, its
consented runtime hook, settings, and Omagen session state, run:

```sh
curl -fsSL https://raw.githubusercontent.com/prettyletto/omagen/dev/uninstall.sh | bash
```

From a local checkout, the equivalent command is:

```sh
./uninstall.sh
```

The uninstaller recovers an active Omagen session before removing its files.
It preserves permanent themes created by Omagen, unrelated Omarchy plugins,
and hooks that do not carry Omagen's ownership marker.

For plugin-manager removal only, without removing Omagen's user state:

```sh
omarchy plugin remove pretty.omagen --yes
omarchy plugin remove pretty.omagen.bar --yes
```

This removes the two plugin packages but leaves Omagen's user state and
permanent themes in place. The complete uninstaller is the recommended command
when Omagen should be removed from the machine.
