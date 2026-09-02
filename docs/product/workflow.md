# Product workflow

Omagen keeps theme creation reversible until you choose to apply it:

```text
choose image → explore directions → preview → Demo → apply or cancel
```

## Choose and generate

Choose a local PNG, JPEG, GIF, BMP, TIFF, or WebP image. Omagen extracts a
palette and generates six directions:

- **Source** — stays closest to the extracted colors.
- **Calm** — reduces intensity for a quieter desktop.
- **Mute** — lowers saturation for restrained surfaces.
- **Deep** — emphasizes darker contrast and depth.
- **Vibrant** — increases color energy while preserving readable contrast.
- **Balanced** — aims for a general-purpose middle ground.

## Preview

Live Canvas shows the staged direction before it becomes permanent. **Test
live** applies a reversible preview to the desktop session. Preview state is
owned by the active Omagen session and can be restored through Cancel or
Recovery.

## Demo

Demo opens a temporary, session-owned workspace with an editor, terminal,
system monitor, and file manager when those capabilities are available. It is
designed to show how the generated theme reads across real desktop surfaces.

Window Demo, Shell Demo, and Bar Demo are focused alternatives when you want to
inspect one composition area. Demo does not change the user's permanent
workspace layout after it closes.

## Optional composition

The In-depth path can stage:

- Window borders, corners, opacity, and inactive-window treatment.
- Shell surfaces, details, tooltips, notifications, and scoped effects.
- Bar presets, size, pane treatment, and workspace presentation.
- Animation and reduced-motion behavior.
- Optional terminal and unlock-screen assets.

Omagen's full bar is an optional suite component. Native Quattro remains the
fallback and native widget placement remains Omarchy-owned.

## Apply, Cancel, and Quit

- **Apply theme** saves a named permanent theme after the staged work is ready.
- **Cancel** restores the original theme and background and cleans only
  Omagen-owned temporary resources.
- **Quit** closes the visible surface and follows the same restore path when a
  session is active.

For the ownership and interrupted-session details, read
[Recovery and rollback](recovery.md). For the complete implementation-level
option matrix, see [Styling and palette settings](../styling.md).
