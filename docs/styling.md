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

Choose **In-depth** in setup to choose desktop composition before generating
the six directions. The configuration window contains
Window, Shell, Bar, and Animations sections. Each choice updates the Source card so the
composition can be judged alongside the extracted palette.

### Window

Window controls are:

- **Active border:** Solid, Split Top, Split Bottom, Accent Blend, Neon Blend,
  or Spinning Accent. Neon Blend adds a soft compositor glow/halo and a
  continuously moving gradient around the focused window. Spinning Accent
  keeps the gradient moving without the neon halo.
- **Border thickness:** A slider starting at **Default** (inherit the active
  theme), followed by **None** and fixed 1–24 px values.
- **Corner shape:** Five fixed presets — Native, Subtle, Soft, Rounded, and Pill.
- **Pane spacing:** Native, Compact, Airy.
- **Depth:** Native, Flat, Shadow.
- **Active and inactive windows:** Each has Native or Frosted backdrop (Light,
  Balanced, or Rich) treatment. Inactive also offers Soft dim.

Soft dim keeps inactive windows readable while moving attention to the focused
window. Frosted backdrop uses a translucent inactive surface and Hyprland
background blur. The generated profiles use `ignore_opacity = true` so the
inactive opacity does not collapse the backdrop sample into a dark shadow.
Light is the low-cost option, Balanced is the recommended
default, and Rich uses a larger multipass blur. The Live Canvas layer also uses
`ignore_alpha = 0.20` and profile-specific panel alpha so the glass surface is
visibly translucent. Opaque application pixels stay
sharp: native Hyprland blur affects only the backdrop visible through a
translucent surface.

Active and inactive profiles are separate compositor paths. A focused surface
can be translucent while inactive panes use a stronger dim, or either path can
remain native. This makes the blur choice explicit instead of pretending that
one inactive toggle can blur opaque application content.

The Live Canvas is a Quickshell layer surface rather than a managed window.
When a Frosted backdrop profile is selected, Omagen therefore emits a scoped Hyprland
`hl.layer_rule` for the `omagen-live-canvas` namespace, enables popup blur for
that surface, and lowers the panel background opacity so the compositor can
sample the wallpaper and windows behind it. The rule is intentionally scoped
to the Studio panel; it does not turn every Omarchy layer surface into a blur
target. Opaque application pixels remain sharp by design because Hyprland can
only blur the backdrop visible through a translucent surface.

These choices describe the generated theme's window presentation. They do not
change Hyprland's layout while you are making the selection.

### Animations

Animations are a separate Hyprland engine. Window motion controls open, close,
and resize transitions; workspace motion controls workspace switching; border
motion controls animated focus borders. Reduced motion disables those
transitions without changing Window, Shell, or Bar surfaces.

### Shell

Shell controls are:

- **Surface composition:** Flat, Layered, Contrast, Accent.
- **Detail language:** Native, Framed, Edge, Focus.
- **Tooltip surface:** Native or Accent.
- **Notification surface:** Native or Accent.

Shell surface choices affect Quickshell popups, menus, and interactive
controls. Detail choices affect how focus and selection edges are expressed.
Native tooltip and notification surfaces preserve Omarchy's semantic treatment;
Accent uses the generated accent for their borders and notification countdowns.

### Bar

Bar controls are:

- **Bar surface:** Native, Dark, Light, Accent.
- **Density:** Native, Compact, Comfortable.
- **Attention color:** Semantic, Accent.
- **Bar form:** Continuous, Docked.
- **Docked visibility:** Native transparency, Show islands.

Omagen preserves Quattro's native left, center, and right widget arrangement.
It does not take ownership of widget placement, ordering, transparency, or
bar input. Docked is an additive Omagen-owned surface beneath the native
widgets when the native bar is opaque. Native transparency keeps that additive
decoration transparent, preserving the existing behavior. Show islands is an
explicit opt-in that keeps the three Docked surfaces visible over a transparent
native bar; native widgets, layout, and input remain Omarchy-owned. If the active
shell does not expose the geometry hooks required for the three section
surfaces, Omagen falls back to the normal continuous form.

## Generated assets

An applied theme can contain these generated assets:

- <code>colors.toml</code> — the Omarchy palette values.
- <code>preview.png</code> — the normalized theme preview, or the captured Demo
  preview when that option is selected.
- <code>unlock.png</code> — Plymouth unlock artwork when **Generate unlock screen**
  is selected.
- <code>preview-unlock.png</code> — the unlock artwork preview used by the
  Plymouth switcher.
- `shell.*.toml` section overrides for non-native Shell choices, including
  tooltip and notification feedback surfaces.
- `omagen.bar.toml` sidecar metadata when Docked Bar choices are selected.
