# Demo workspace

Demo is the optional, temporary, session-owned four-window workspace used to
judge a generated theme in context. Live Canvas is the persistent control
surface for the real desktop test; it can remain open without Demo running.

## What Demo opens

Omagen resolves capabilities for four slots:

- Editor or source viewer
- Terminal
- System monitor
- File manager

The exact applications depend on what is available on the machine. When a
preferred application is unavailable, Omagen uses a terminal/source-viewer,
system-information, or file-listing fallback so the workspace remains useful.

The content comes from the repository's deterministic <code>demo/</code> assets rather
than the user's private files.

## Workspace behavior

When Demo opens, Omagen:

1. Records the current monitor and workspace.
2. Creates a temporary Omagen-owned workspace.
3. Launches and classifies the Demo windows it owns.
4. Places the windows with consistent spacing.
5. Restores the original workspace when Demo closes.

Demo prefers the focused monitor and remembers its state while the Omagen
session remains active. If a shell reload or application restart removes some
of the windows, reopening Demo recreates only the missing slots it can
classify.

## Demo and Live Canvas controls

From the Live Canvas wizard:

- Activating a palette card with a click or **Enter** applies the direction and
  opens Live Canvas without starting Demo.
- Open **Demos** in the wizard header, or use the **Demo Studio** page, to
  choose Window Demo, Shell Demo, Bar Demo, or the full four-window workspace.
- Only one Demo surface is active at a time. Selecting the active surface
  stops it; selecting another surface switches after any owned resources are
  safely closed.
- Window Demo previews the current staged Window, Shell, Bar, and Motion
  composition before opening its tracked windows.
- **Hide Studio panel** leaves the canvas and temporary theme active while
  returning all other pointer input to the desktop. The monitor-bound handle
  shows the active Demo mode and keeps the Demos switcher available.
- **Save & Apply** can close Full Demo before applying, or capture it as the
  theme preview when requested.

Shell Demo and Bar Demo are separate, read-only overlays backed by their own
session-owned temporary workspaces. Shell Demo has its own close control; Bar
Demo is rendered below the real native bar and does not replace Quattro's
widgets or capture their input. Only Full Demo and Window Demo create tracked
application windows.

Demo is temporary. It does not change the user's normal workspace layout after
it closes.

## Capture a preview

In the **Save theme** dialog, enable **Capture live Demo preview** to use a
fresh Full Demo screenshot as <code>preview.png</code>. Omagen closes any
currently open Demo surface, opens the Full Demo scene from scratch, applies
the selected direction, captures the Demo monitor, and normalizes the result
to the canonical theme preview format before closing Demo and continuing the
Apply flow.

When live Demo capture is not selected, Apply uses the theme's generated
background as <code>preview.png</code> instead.

## Troubleshooting

If a preferred application is missing, check that its fallback appears rather
than treating that as a failed theme generation. If a Demo window does not
close, Apply is aborted so Omagen does not leave an untracked window behind;
use the **Demos** switcher or the recovery flow before trying again.
