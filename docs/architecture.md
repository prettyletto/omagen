# Architecture

Omagen is a Quickshell plugin with a QML presentation layer and a bundled Go
backend. Quickshell owns the visible plugin lifecycle; the backend owns the
filesystem, theme, Demo, and recovery operations that must survive UI reloads.

The stable backend ownership and Studio attachment rules are recorded in the
[engine contract](engine-contract.md). This contract is the boundary for new
Studio capabilities; it does not replace the existing session or recovery
engine.

## Omarchy plugin contract

The root [manifest.json](../manifest.json) is the package contract:

| Field | Value |
| --- | --- |
| ID | <code>pretty.omagen</code> |
| Kinds | <code>overlay</code>, <code>bar-widget</code> |
| Overlay entry point | <code>Omagen.qml</code> |
| Bar-widget entry point | <code>OmagenBarWidget.qml</code> |
| Default bar section | <code>right</code> |
| Keep loaded | <code>true</code> |

Omarchy installs the repository at:

~~~text
~/.config/omarchy/plugins/pretty.omagen/
~~~

The bar widget summons the overlay through the running <code>omarchy-shell</code>;
it does not create a second Quickshell instance.

## Runtime layers

~~~mermaid
flowchart TD
    Shell["Omarchy / Quickshell"]
    Bar["OmagenBarWidget.qml"]
    Overlay["Omagen.qml"]
    Views["Setup, styling, gallery, recovery views"]
    Backend["bin/omagen"]
    Generation["Generation and contrast"]
    Preview["Temporary preview themes"]
    Demo["Demo workspace"]
    Apply["Permanent Apply and asset writing"]

    Shell --> Bar
    Shell --> Overlay
    Bar --> Overlay
    Overlay --> Views
    Views --> Backend
    Backend --> Generation
    Backend --> Preview
    Backend --> Demo
    Backend --> Apply
~~~

## Generation pipeline

The production generation path is:

~~~text
image file
→ image decoding and pixel sampling
→ representative colors
→ source palette
→ optional harmony transformation
→ Source / Calm / Mute / Deep / Vibrant / Balanced
→ semantic contrast enforcement
→ Omarchy theme candidate
~~~

The preview path uses the same palette and contrast transformations as the
generation path. This keeps the gallery aligned with the colors that will be
written into <code>colors.toml</code>.

## QML/backend boundary

QML owns:

- Overlay routing and visible state.
- Image selection and settings controls.
- Window, Shell, and Bar composition choices and their visual previews.
- Palette-card selection and keyboard navigation.
- Demo, preview, Apply, Cancel, and recovery requests.
- User-facing busy and error states.

The Go backend owns:

- Image analysis and palette generation.
- Contrast enforcement and theme-file writing.
- Hyprland window overrides and Quattro shell section overrides.
- Durable session records and mutation locking.
- Temporary preview theme aliases.
- Demo capability resolution, window ownership, placement, and cleanup.
- Apply staging, commit, and recovery.
- Restoration and verification of the original theme/background.

The backend remains authoritative when the shell reloads or the overlay is
hidden. A QML close action therefore requests cancel or recovery when needed;
it does not merely discard the visible surface.

## Session lifecycle

~~~mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Active: begin session
    Active --> Previewing: Test live
    Previewing --> Active: choose another direction
    Active --> DemoOpen: open Demo
    DemoOpen --> Active: Dispatch
    Active --> Idle: Cancel and restore
    Active --> Applying: Save & Apply
    Applying --> Idle: commit and clear session
    Active --> Recovery: shell or process interruption
    Applying --> Recovery: interrupted Apply
    Recovery --> Active: Resume
    Recovery --> Idle: Restore and close
~~~

Every active session records the original theme and background before any
temporary theme is applied. Demo and preview artifacts are associated with the
session so cleanup can distinguish them from unrelated user files.

## Apply transaction

Apply follows a staged transaction:

~~~text
persist PREPARED
→ publish an Omagen-owned destination
→ apply the Omarchy theme
→ persist COMMITTED
→ remove the ownership marker
→ clear the active session
~~~

Recovery inspects the current theme and the Omagen ownership marker before
deciding whether a prepared destination can be committed or must be removed.
Restoration is verified against both the original theme and original
background before the session is cleared.

## Omarchy ownership boundaries

Omagen integrates with Omarchy without replacing the native shell systems:

- The plugin is loaded by the long-running <code>omarchy-shell</code> process.
- Theme changes go through Omarchy's theme commands.
- Quattro remains responsible for native bar layout, widget ordering,
  transparency, and input.
- Omagen's Docked form is an additive surface beneath those native widgets;
  native transparency hides that decoration unless the user selects Show
  islands.
- Demo uses temporary Hyprland workspace/window state and restores the user's
  original workspace.
- Cleanup removes only resources that Omagen can prove belong to an inactive
  session.
