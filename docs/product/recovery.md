# Recovery and rollback

Omagen treats Preview and Apply as temporary desktop transactions. The active
session records the original theme, background, generated workspace, and
Omagen-owned temporary paths before changes are made.

## If you change your mind

Choose **Cancel** in the Studio. Omagen restores the original theme and
background, closes session-owned Demo windows, removes temporary preview state,
and clears the active session record after restoration succeeds.

**Quit** uses the same restore behavior when a session is active.

## If Omagen or the shell is interrupted

Reopen Omagen. If a durable session is still active, it presents a recovery
choice:

- **Restore & close** returns to the original theme and background.
- **Resume** returns to the staged workspace only when its data is still
  available and ownership can be verified.

Omagen does not silently delete a session whose ownership or restoration state
cannot be proved.

## What cleanup preserves

Cleanup removes only inactive resources that Omagen can identify as its own,
including temporary theme aliases, session directories, Demo state, and Apply
staging directories. It preserves permanent user themes, unrelated plugins,
native shell configuration, external backgrounds, and resources without an
Omagen ownership marker.

Do not manually remove `~/.local/state/omagen` during an active session. Use the
recovery UI first.

For the maintainer-level transaction contract, see the full
[recovery and safety guide](../recovery.md).
