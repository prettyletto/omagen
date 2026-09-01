# Omagen development branch

This checkout is the `nightly` branch, intended for contributors and testers.
It may contain incomplete or experimental work and must not be used as the
normal user installation source. The controlled promotion path is:

```text
nightly → dev → main → marketplace verification
```

The `dev` branch is the protected integration and release-candidate branch.
The `main` branch owns the stable product README, demos, screenshots, user
installation, upgrade, recovery, and release notes. See the [stable product
README](https://github.com/prettyletto/omagen/blob/main/README.md) for the
user-facing experience.

## Contributor setup

Omagen is an Omarchy Quattro plugin composed of two separately owned packages:

- `pretty.omagen` — the overlay and launcher/status widget.
- `pretty.omagen.bar` — the optional full-bar plugin.

Runtime requirements are Omarchy Quattro, Hyprland, Quickshell, and Linux
x86_64 for the bundled backend executable. Demo applications are optional and
are resolved with fallbacks. The plugin is unsandboxed and can modify the
user-level themes, settings, shell state, backgrounds, and Omagen-owned
session resources described in the [architecture](docs/architecture/README.md).
It does not require `sudo`, install system packages, or configure privileged
services.

Clone the repository and install the current checkout locally:

```zsh
git clone https://github.com/prettyletto/omagen.git
cd omagen
./dev-install.sh
```

For tester or release-candidate validation, inspect an immutable full commit
before installing it. The bootstrap refuses a mutable branch head:

```zsh
git clone https://github.com/prettyletto/omagen.git /tmp/omagen-review
cd /tmp/omagen-review
git show --stat --oneline <full-40-character-commit-sha>
OMAGEN_TEST_BRANCH=nightly \
OMAGEN_TEST_COMMIT=<full-40-character-commit-sha> \
  ./scripts/install-branch.sh
```

Run the local repository gate from zsh:

```zsh
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
python3 scripts/marketplace-preflight.py \
  --commit "$(git rev-parse HEAD)" \
  --report /tmp/omagen-marketplace-report.json
```

The preflight is deterministic, read-only, and never executes plugin code or
downloaded content. It scans both manifests source-wide, checks the root
packaging contract, records capabilities and findings against the exact commit,
and returns `passed`, `review-required`, or `needs-fixes`.

## Developer documentation

- [Development guide](docs/development.md) — local setup, tests, packaging,
  QML validation, and the repository gate.
- [Release and promotion process](docs/development/release-process.md) —
  branch contracts, candidate states, exact-commit evidence, and marketplace
  submission.
- [Architecture](docs/architecture/README.md) — plugin boundaries, the
  QML/backend contract, generation, lifecycle, and recovery ownership.
- [Demo workspace](docs/demo.md) — implementation and ownership contracts for
  the temporary Demo paths.
- [Contributing](CONTRIBUTING.md) — pull requests, reviews, and validation
  expectations.
- [Security policy](SECURITY.md) — trust boundaries and vulnerability reports.

## Removal during development

From a local checkout, run:

```zsh
./uninstall.sh
```

The uninstaller recovers an active Omagen session and preserves permanent
themes, unrelated plugins, and resources without Omagen ownership markers.
For package-only removal, use the native plugin manager explicitly:

```zsh
omarchy plugin remove pretty.omagen --yes
omarchy plugin remove pretty.omagen.bar --yes
```

The stable `main` branch must retain the user-facing installation and removal
instructions in its own root README before the final release promotion.
