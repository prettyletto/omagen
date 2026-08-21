# Recovery and safety

Omagen treats a live preview as a temporary desktop transaction. The original
theme, background, generated workspace, and temporary theme aliases belong to
the active session until the user applies, cancels, or recovers it.

## Temporary sessions

At the start of a session, Omagen records:

- The current Omarchy theme.
- The current background, including whether it belongs to the active theme or
  is an external path.
- The selected source image and generation state.
- Optional Window, Shell, and Bar choices.

This record lets Omagen restore the desktop even when the overlay is no longer
visible.

## Cancel and Quit

**Cancel** from the palette gallery restores the original theme and background,
closes the session's Demo windows, removes temporary preview state, and clears
the active session record.

**Quit** from the bar widget uses the backend recovery path. If there is no
active session, it does nothing beyond closing any visible Omagen surface. If
there is an active session, it performs the same restoration work as Cancel.

Closing a window or hiding the overlay is not by itself a successful cancel;
the backend session record remains authoritative until restoration completes.

## Interrupted sessions

If the shell or Omagen is interrupted during a preview, the next launch checks
for an active durable session and opens **Recover Omagen**.

- **Restore & close** restores the original theme and background, then clears
  the session.
- **Resume** returns to the generated workspace when its staged data is still
  available.
- If the generated workspace is unavailable, Resume is disabled and restore is
  the safe available action.

Recovery is deliberately explicit. Omagen does not silently delete a session
whose ownership or restoration state cannot be verified.

## Apply safety

Apply is staged as a transaction:

~~~text
prepare session
→ publish the owned theme candidate
→ apply the Omarchy theme
→ commit the session
→ remove temporary state
~~~

The generated theme is marked as Omagen-owned before the external theme switch
is attempted. If the process stops during Apply, the next recovery attempt can
distinguish an Omagen-owned destination from an unrelated user theme.

If an external theme change happens during Apply, Omagen preserves enough
staged state for a later recovery or retry instead of deleting a destination
it cannot prove it owns.

## Cleanup boundaries

Omagen cleanup removes only resources it can identify as belonging to inactive
Omagen sessions, such as:

- Temporary preview theme aliases.
- Inactive session directories.
- Demo state owned by an inactive session.
- Abandoned Omagen Apply temporary directories.

Cleanup does not remove user-created permanent themes. Removing the plugin also
does not remove those themes.

## State location

Durable Omagen session state is stored under:

~~~text
~/.local/state/omagen/
~~~

Do not remove this directory while an Omagen session is active. If recovery is
needed, use the UI first so the original theme and background can be restored
and verified.
