# Usage

Omagen is designed as a short loop:

~~~text
image → palette directions → live preview or Demo → permanent theme
~~~

For a visual tour of the complete workflow, watch the [Omagen video
walkthrough on YouTube](https://youtu.be/Af06-XsdBHA).

## Open Omagen

Click the Omagen widget in the Quattro bar to open the theme studio. The
widget is installed in the right bar section by default and can be moved with
Omarchy's normal bar controls.

Right-click the widget for:

- **Open** — open the theme studio.
- **Settings** — edit palette harmony and contrast preferences.
- **Quit** — close Omagen and restore an active temporary session when one
  exists.

The overlay also supports outside-click dismissal, a close button, arrow-key
navigation, and <code>h/j/k/l</code> navigation. Use <code>Enter</code> or <code>Space</code> to
activate the focused action and <code>Escape</code> to close the current surface.

<p align="center">
  <img src="../assets/screenshots/settings.webp" alt="Omagen settings" width="420">
</p>

Settings persist the harmony and contrast preferences used by later palette
generations. Reset defaults is available when you want to return to the
baseline values.

## Choose an image

The setup screen starts with **Choose image**. Omagen accepts common raster
formats supported by its image decoder, including PNG, JPEG, GIF, BMP, TIFF,
and WebP. The selected image is used for palette extraction and remains the
source shown in the preview cards.

After choosing an image, choose a workflow:

- **Fast** follows the normal path: choose a direction, enter Live Canvas, and
  apply the theme. Start Demo is optional when you want the four-window
  workspace.
- **In-depth** enables Studio extras for window, shell, bar, and animation composition in
  Live Canvas after palette generation; see [Styling and palette settings](styling.md).

<p align="center">
  <img src="../assets/screenshots/onboarding.webp" alt="Omagen setup" width="420">
</p>

## Configure extra desktop styling

When **In-depth** is selected, the Live Canvas sidebar exposes composition
controls after the six palette directions are generated. Open **Advanced
settings** and move between the four engines:

- **Window** controls the active border, a Default/None/1–24 px border slider, five fixed
  corner-shape presets, pane spacing, shadow depth, and independent active/inactive
  Frosted backdrop profiles (with Soft dim or Shadow · Preserve transparency
  for inactive windows).
- **Shell** controls surface composition, focus/detail language, and tooltip or
  notification feedback surfaces.
- **Bar** controls the form, surface, density, attention color, and Docked
  visibility policy while preserving native Quattro layout behavior.
- **Animations** controls window, workspace, and border motion plus reduced motion.

Every choice is staged in the current session. Use **Test Live composition**
to apply the selected values to the native runtime owners; these settings then
become part of the generated preview and applied theme.

![Window styling extras](../assets/screenshots/extras-window.webp)

![Shell styling extras](../assets/screenshots/extras-shell.webp)

![Bar styling extras](../assets/screenshots/extras-bar.webp)

## Explore palette directions

Omagen generates six directions from the same source image:

- **Source** — the closest representation of the extracted palette.
- **Calm** — a quieter, less aggressive interpretation.
- **Mute** — a more restrained version with reduced intensity.
- **Deep** — a darker, more atmospheric direction.
- **Vibrant** — a stronger, more expressive direction.
- **Balanced** — a middle-ground interpretation between source character and
  usability.

Select a card to make it the active direction. The gallery can be navigated
with the arrow keys or <code>h/j/k/l</code> and activated with <code>Enter</code> or <code>Space</code>.

Omagen applies semantic contrast processing to the generated palette before
it reaches the gallery, so the preview represents the palette that will be
used by the generated theme rather than an earlier intermediate result.

<p align="center">
  <img src="../assets/screenshots/palette-gallery.webp" alt="Omagen palette gallery" width="960">
</p>

## Enter Live Mode

Activate a palette card with a click or with **Enter** to enter Live Mode.
Omagen applies the selected direction temporarily through the Studio theme
driver and opens the Live Canvas control surface while keeping the real desktop
available. The temporary theme and the original theme/background are tracked by
the active Omagen session.

Arrow-key navigation only changes the focused direction. It does not mutate the
desktop until the direction is activated. Reopen Omagen from the bar to choose
another direction while the canvas is active; the new candidate is applied in
place without recreating the workspace.

The **Live Canvas** action applies a direction and opens the control surface;
it does not start the optional Demo workspace.

Use **Cancel** when you are finished testing. Omagen restores the original
theme and background before clearing the session.

## Use the Live Canvas

**Live Canvas** applies a direction to the real desktop and keeps the
monitor-bound control panel available. It is the normal place to compare
directions, use history, apply the theme, or restore the original desktop.

Use **Start demo** when you specifically want the temporary four-window
workspace containing the applications Omagen can resolve on the current
machine. Starting Demo does not replace the Live Canvas controls; the panel
stays available while the workspace is open.

When the canvas is open, Studio provides a monitor-bound side panel. Hide the
panel to keep interacting with the desktop; a small handle on the canvas
monitor reopens it without capturing application input while hidden. The panel
can reapply directions, move through reversible history, apply the theme, close
the canvas, or **Restore & close** the complete temporary session. See the
[Live Canvas workspace guide](demo.md) for ownership and cleanup details.

## Apply a theme

Choose **Apply theme** to open the save dialog. Enter a name for the permanent
Omarchy theme and choose any optional outputs:

- **Generate unlock screen** creates Plymouth unlock artwork and its preview.
- **Capture live Demo preview** uses the loaded Demo workspace as the theme's
  <code>preview.png</code>.

Choose **Save & Apply** to publish the generated theme and select it through
Omarchy. Apply is staged so an interrupted operation can be recovered; see
[Recovery and safety](recovery.md).

## Cancel, Quit, and recovery

Cancel from the gallery restores the original desktop. Closing the overlay is
not the same as abandoning the session: Omagen keeps the durable session state
until the session is applied, canceled, or recovered.

If a previous session is found on the next launch, Omagen shows **Recover
Omagen**. Choose **Restore & close** to restore the original theme and
background, or **Resume** when the generated workspace is still available.
