# Contributing to Omagen

Thanks for helping improve Omagen. The project is an Omarchy Quattro plugin
with QML presentation code and a bundled Go backend.

## Branches

- `nightly` is experimental development.
- `dev` is the protected integration and release-candidate branch.
- `main` is the stable user-facing product.

Changes move through `nightly → dev → main`. Do not open a direct promotion
from nightly to main.

## Before opening a pull request

Read [`AGENTS.md`](AGENTS.md), run `scripts/agent-context <domain>`, and read
the recipe for the bounded context you are changing. Run focused checks first,
then the complete gate:

```zsh
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
python3 scripts/marketplace-preflight.py
```

For backend changes, also run Go tests, race tests, and vet from `backend/`.
For QML or lifecycle changes, report separately whether real Omarchy/Hyprland
validation was possible.

## Review expectations

Preserve the durable backend session as the authority for rollback and
recovery, prove ownership before cleanup, keep the two plugin manifests
separate, and preserve the existing QML↔Go wire contract. Changes to bundled
binaries must come from the canonical deterministic build.

Do not include secrets, private user state, screenshots containing sensitive
data, or generated host artifacts in a pull request.
