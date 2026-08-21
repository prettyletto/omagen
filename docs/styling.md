# Styling and palette settings

Omagen has two kinds of choices:

1. Palette-generation settings that influence the colors produced from the
   image.
2. Optional desktop-composition settings that are previewed alongside those
   colors.

## Palette generation

The production pipeline is:

~~~text
source image
→ representative colors
→ source palette
→ harmony transformation
→ palette direction
→ semantic contrast enforcement
→ Omarchy theme files
~~~

The palette shown in the gallery is the contrast-processed palette that will
be used by the generated theme.

## Harmony

Settings exposes these color-theory choices:

- **Closest to source** — preserve the wallpaper's natural color
  relationships.
- **Monochromatic** — use one primary hue across the palette.
- **Analogous** — use neighboring hues around the source accent.
- **Complementary** — combine the source accent with its opposite hue.
- **Split complementary** — combine the source accent with two neighboring
  opposite hues.
- **Triadic** — use three evenly spaced hue families.

The default is **Closest to source**.

## Contrast targets

Settings lets you adjust the contrast targets used for these semantic roles:

- Primary text
- Bright text
- Secondary text
- UI elements
- Selection text
- ANSI colors
- Bright ANSI colors

These are palette-generation settings, not a replacement for checking the
final theme on the desktop. Use Test live or Demo when the relationship
between surfaces matters.

## Extra configuration previews

Enable **extra configs on preview** in setup to choose desktop composition
before generating the six directions. The configuration window contains
Window, Shell, and Bar sections. Each choice updates the Source card so the
composition can be judged alongside the extracted palette.

### Window

Window controls are:

- **Active border:** Solid, Split Top, Split Bottom, Accent Blend, Neon
  Blend.
- **Corner shape:** Native, Soft, Rounded.
- **Pane spacing:** Native, Compact, Airy.
- **Depth:** Native, Flat, Shadow.

These choices describe the generated theme's window presentation. They do not
change Hyprland's layout while you are making the selection.

### Shell

Shell controls are:

- **Surface composition:** Flat, Layered, Contrast, Accent.
- **Detail language:** Native, Framed, Edge, Focus.

Shell surface choices affect Quickshell popups, menus, and interactive
controls. Detail choices affect how focus and selection edges are expressed.

### Bar

Bar controls are:

- **Bar surface:** Native, Dark, Light, Accent.
- **Density:** Native, Compact, Comfortable.
- **Attention color:** Semantic, Accent.
- **Bar form:** Continuous, Docked.

Omagen preserves Quattro's native left, center, and right widget arrangement.
It does not take ownership of widget placement, ordering, transparency, or
bar input. Docked is an additive Omagen-owned surface beneath the native
widgets. If the active shell does not expose the geometry hooks required for
the three section surfaces, Omagen falls back to the normal continuous form.

## Generated assets

An applied theme can contain these generated assets:

- <code>colors.toml</code> — the Omarchy palette values.
- <code>preview.png</code> — the normalized theme preview, or the captured Demo
  preview when that option is selected.
- <code>unlock.png</code> — Plymouth unlock artwork when **Generate unlock screen**
  is selected.
- <code>preview-unlock.png</code> — the unlock artwork preview used by the
  Plymouth switcher.
- Bar configuration sidecar data when non-native Bar choices are selected.
