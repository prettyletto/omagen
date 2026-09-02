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

Choose **In-depth** in setup to open the optional composition workflow around
the six directions. Look & Feel recipes provide complete starting
compositions; the Advanced page then exposes Window, Shell, Bar, and
Animations sections for focused edits. Each choice is staged in the session and
can be Previewed or tested live before Apply.

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
  Balanced, or Rich) treatment. Inactive also offers Soft dim or Shadow ·
  Preserve transparency.

Soft dim keeps inactive windows readable while moving attention to the focused
window. Shadow · Preserve transparency adds only a lower-alpha compositor
shadow and leaves Omarchy/application opacity untouched. Frosted backdrop uses
the existing translucent surface and inherits the current application/Omarchy
opacity policy when selected as a standalone Window style; the Glass Blur
preset explicitly adds `0.82` active and inactive window opacity so the full
desktop treatment remains visibly translucent.
background blur. The generated profiles use `ignore_opacity = true` so the
inactive opacity does not collapse the backdrop sample into a dark shadow.
Light is the low-cost option, Balanced is the recommended
default, and Rich uses a larger multipass blur. Hyprland exposes one blur
kernel for normal windows, so when both active and inactive windows are
frosted, the active choice owns that shared strength; a stronger inactive
choice still keeps its independent dim/opacity intent without making the
focused window blur more strongly. The Live Canvas layer also uses
`ignore_alpha = 0.20` and profile-specific panel alpha so the glass surface is
visibly translucent. Opaque application pixels stay
sharp: native Hyprland blur affects only the backdrop visible through a
translucent surface.

The all-windows opacity control and the active/inactive profiles work together:
the slider sets the shared steady-state opacity, while the profiles set each
window's backdrop and dim treatment. A focused surface can be frosted while
inactive panes use a stronger dim, or either path can remain native. The shared
normal-window blur kernel is resolved in favor of the focused frosted profile
because Hyprland does not expose separate active/inactive blur sizes. This
makes the limitation explicit instead of pretending that one inactive toggle
can blur opaque application content.

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
motion controls animated focus borders. Retro VHS is a finite event signal with
soft tape wobble, chroma bleed, scanlines, and restrained tracking noise. Reduced
motion disables those transitions and screen effects without changing Window,
Shell, or Bar surfaces.

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
The Glass Blur preset makes the core bar, popup, menu, and launcher surfaces
`0.72` alpha and emits a scoped Hyprland layer-blur rule for the native
`omarchy-menu` and related shell namespaces, so the shell can show the desktop
behind it without changing application-window opacity policy.

### Bar

Bar controls are:

- **Preset:** Default, Float Compact, Float Expanded, Islands, Dock, Minimal,
  Orbit, Segmented Ribbon, Cathedral, Pulse, and Zen.
- **Size:** Default, Compact, Comfortable. This is applied after a bar preset
  so each preset can be tuned without changing its structure. Cathedral,
  Pulse, and Zen use dedicated horizontal and vertical compositions.
- **Pane:** Preset default, Opaque, Metal, Glass (real compositor blur), and
  Clear. Preset default keeps the selected recipe's own pane; Opaque maximizes
  contrast; Metal uses a near-opaque dark neutral pane for a restrained solid
  finish; Glass uses a translucent layer with scoped Hyprland backdrop blur;
  Clear keeps the pane mostly transparent without blur for wallpaper visibility
  and lower GPU cost.
- **Advanced size:** Expand the size control to inspect the resolved pixel
  footprint and set a custom value. The minimum is the smallest usable
  footprint for the selected preset; Dock and vertical Islands include their
  structural cross-axis padding in that displayed value. Reset returns to the
  selected named size mode.
- **Workspaces:** Default (Omarchy-compatible), Numbers, Japanese Kanji (一–五),
  Roman numerals, Letters, Dots, or Custom glyphs. Custom mode accepts up to
  five labels (one for each primary workspace), with up to four Unicode
  characters per label.
  Switching remains native Hyprland behavior; only the presentation changes.

The Bar Lab stages a versioned declarative `BarSpec` behind these focused controls.
Additional topology, attention, region, and behavior controls remain reserved
for later iterations. Layout, widget ordering, and bar input remain native
Quattro responsibilities for the overlay's additive bar path; the separate
`pretty.omagen.bar` plugin is the opt-in full-bar host for BarSpec replacement
layouts.

## Generated assets

An applied theme can contain these generated assets:

- <code>colors.toml</code> — the Omarchy palette values.
- <code>preview.png</code> — the normalized theme background preview by default,
  or the captured Demo preview when that option is selected.
- <code>unlock.png</code> — Plymouth unlock artwork when **Generate unlock screen**
  is selected.
- <code>preview-unlock.png</code> — the unlock artwork preview used by the
  Plymouth switcher.
- `shell.*.toml` section overrides for non-native Shell choices, including
  tooltip and notification feedback surfaces.
- `omagen.bar.toml` sidecar metadata when Docked Bar choices are selected.
