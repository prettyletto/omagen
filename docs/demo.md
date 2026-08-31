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

From the palette gallery:

- Activating a palette card with a click or **Enter** applies the direction and
  opens Live Canvas controls without starting Demo.
- **Start demo** opens the tracked four-window workspace for the selected
  direction.
- **Stop demo** closes the tracked windows and restores the original workspace;
  Live Canvas controls remain available.
- **Hide Studio panel** leaves the canvas and temporary theme active while
  returning all other pointer input to the desktop. The monitor-bound handle
  reopens the panel.
- **Apply theme** can close Demo before applying, or capture it as the theme
  preview when requested.

Demo is temporary. It does not change the user's normal workspace layout after
it closes.

## Capture a preview

In the **Save theme** dialog, enable **Capture live Demo preview** to use the
loaded Demo workspace as <code>preview.png</code>. Omagen captures the Demo monitor and
workspace recorded by the active session, normalizes the result to the
canonical theme preview format, and stages it with the theme before Apply.

If Demo is not open, Omagen opens it first, applies the selected direction,
captures the result, and then closes Demo before continuing the Apply flow.

When live Demo capture is not selected, Apply uses the theme's generated
background as <code>preview.png</code> instead.

## Troubleshooting

If a preferred application is missing, check that its fallback appears rather
than treating that as a failed theme generation. If a Demo window does not
close, Apply is aborted so Omagen does not leave an untracked window behind;
use **Stop demo** or the recovery flow before trying again.
