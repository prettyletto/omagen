# Capabilities and trust boundary

Omagen is an unsandboxed user-level Omarchy plugin. Install it only if you are
comfortable granting a desktop customization tool access to the user-level
resources described below.

## What Omagen can do

| Capability | Why it exists | Boundary |
| --- | --- | --- |
| Read a selected image | Extract the palette and show its source in the session | Only the image you choose is used as generation input. |
| Read relevant Omarchy state | Preserve the current theme, background, and runtime choices | Reads are bounded and tied to the active workflow. |
| Write generated themes | Make an applied theme available to Omarchy | Permanent output is created only when you choose Apply. |
| Write Omagen session state | Support Preview, Apply, Cancel, and interrupted recovery | Session files are marked and cleaned only when ownership is verified. |
| Interact with the desktop session | Show previews, Demo windows, and optional shell/bar composition | Runs at user level through the active Omarchy/Hyprland session. |
| Run bundled user-level helpers | Provide the backend and runtime integration without Go installed | No `sudo`, system package installation, or privileged service setup is required. |

## What Omagen does not own

Omagen does not own unrelated themes, native Quattro layout, arbitrary
backgrounds, other plugins, existing user commands, or user files that were not
recorded as part of an Omagen session transaction. Cleanup and uninstall must
preserve those resources.

The optional `pretty.omagen.bar` package owns its own full-bar entry point, but
it remains separate from the core `pretty.omagen` overlay/widget package. The
separation makes the full bar explicit and keeps native Quattro as the safe
fallback.

## Bundled code and provenance

The backend executable is bundled so normal users do not need Go. Compiled
shader assets are bundled for the same reason. Their source, licenses, pinned
build settings, hashes, and provenance are checked before release.

The repository's marketplace preflight is a deterministic release check for a
specific commit. It is not a security audit, certification, endorsement, or
guarantee. Read the repository [security policy](../../SECURITY.md) for
maintainer reporting instructions.
