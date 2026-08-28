# Runtime contract

The Go `backend/internal/runtime` package is the model, registry, and adapter
authority for runtime feature status and activation. It covers shell, bar,
Hyprland, and other explicitly registered features without replacing native
Omarchy ownership.

`bin/studio-theme-set` is the installed compatibility/transaction driver. It
contains shell-level integration needed to resolve Omarchy paths, locks, and
post-theme adapter execution. The current nightly source has meaningful
orchestration in both layers; this pass deliberately does not rewrite it. A
future consolidation must preserve scopes, wait modes, no-hook defaults,
allowlists, locking, and non-fatal post-commit retint behavior.

When changing runtime behavior, read the runtime package tests and this
contract before touching the shell driver. Do not create a second runtime
authority in QML or in a new Bar component.
