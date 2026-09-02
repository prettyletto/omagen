# Installed-theme editing contract

Omagen can adopt an installed Omarchy theme into a durable session workspace.
The native catalog is discovered through `omarchy theme list` and resolved
through `omarchy theme dir <slug>`. Display labels and trusted slugs are kept
separate.

When a user theme overlays a stock theme, the edit snapshot is composed in
native precedence order: stock files first, user files second. The selected
source is never mutated during Open, Preview, or Cancel. Only the staged
session candidate is mutable.

Open accepts regular files and directories only. Symlinks and special files
are rejected with an error instead of being followed, so a theme cannot make
the preview workspace read outside the selected source roots. Copy such assets
into the theme as regular files before editing. Regular-file permission bits
are retained in the snapshot.

Choosing a Studio engine is an explicit ownership migration. Omagen regenerates
its managed output, while hand-authored Hyprland Lua is retained ahead of the
generated block when it is not already marked as Omagen-generated. Native shell
section inputs remain the source of truth for fields outside the selected
Omagen controls; keep machine-wide shell policy in the user override layer.

An edit workspace uses the existing `source` variant and carries
`workflow: "theme-edit"` in the durable session record. Image generation keeps
its six-variant contract. Stock files remain native until a user explicitly
migrates a compiler scope (`shell-bar`, `window-motion`, or `terminal`) into
Omagen control.

Apply destination policy is explicit. A new name publishes a new user theme.
Keeping the selected name creates or replaces only the corresponding user
theme directory; stock directories are never written. Replacement moves the
old user directory to a session-owned backup before promotion and removes it
only after native Apply and verification commit. Recovery restores that backup
when the transaction does not commit.

Successful Omagen themes include `omagen.theme-recipe.json`, a validated
sidecar containing palette, managed style documents, source provenance, and
scope ownership. `omagen theme export-recipe <theme>` exports that sidecar for
versioning or reuse. Recipe export is intentionally sidecar-only in this
workflow; importing a complete theme bundle remains a separate capability.
The recipe is optional provenance for compatibility fixtures; its absence must
not invalidate a native theme transaction.
