# Nightly → dev promotion handoff

This handoff records the promotion boundary for the current `nightly` work.
It is intentionally commit-independent until the working tree is reviewed and
committed. Fill in the exact full SHA after committing; do not promote a dirty
working tree or reuse evidence from another commit.

## Change scope

- Branch: `nightly` → `dev`
- Release target: `v2.0.0`
- Packages: `pretty.omagen`, `pretty.omagen.bar`
- Candidate tag: create only after the promotion PR passes the `dev` gate.
- Promotion commit: `TBD — fill after review and commit`

The product changes include Demo reader and workspace lifecycle behavior,
Preview stale-work protection, QML controller sequencing, full-bar integration,
packaging, and the developer/release security foundation.

## Required review slices

- [ ] Lifecycle and recovery ownership.
- [ ] Generation and theme editing.
- [ ] Runtime adapters and user-level hooks.
- [ ] Demo workspace creation, path ownership, stale cleanup, and recovery.
- [ ] QML controllers, gateways, and behavioral tests.
- [ ] Full-bar plugin and native Quattro boundaries.
- [ ] Installer, uninstaller, manifests, binaries, shaders, and package files.
- [ ] Developer documentation, OSS governance, support, and release process.

## Security-hardening evidence

Commit `48261e8` is not a direct ancestor of the current nightly head, but its
security behavior is present in the later refactored source. The current code
and tests preserve:

- Regular-file checks before user-controlled reads.
- Bounded state-file reads.
- Bounded source-image reads and image caching.
- Image dimension limits.
- Tests for oversized files, non-regular files, and oversized cached inputs.

The promotion reviewer must inspect the current implementations and test
results rather than relying only on commit ancestry.

## Automated evidence

- [x] Go formatting, tests, race tests, and vet.
- [x] Reproducible bundled backend and Studio binaries.
- [x] CLI smoke and ownership tests.
- [x] Manifest/version/package checks.
- [x] QML syntax validation.
- [x] Marketplace preflight with no blocking findings.
- [x] Shader source/QSB provenance.
- [x] Fresh-package validation.
- [x] Documentation relative-link validation.
- [ ] CI run on the actual `nightly → dev` pull request.

The local preflight outcome is `review-required` with no findings because the
package intentionally contains a bundled executable and installer/runtime
capabilities. The `dev` PR must upload the report bound to its exact head SHA.

## Compatibility evidence

The maintainer has confirmed operation on:

- Omarchy `4.0.2-1`.
- Omarchy `4.0.1-1`.

Record the exact test date, checkout SHA, Quickshell version, Hyprland version,
and any upgrade/recovery notes when available. The live GUI flow is not being
run as part of this handoff unless explicitly requested.

## Promotion decision

Promote to `dev` only after:

1. All current changes, including new files, are reviewed and committed.
2. The `nightly → dev` pull request passes every required `dev` check.
3. Any `review-required` capability is acknowledged by a maintainer.
4. No `needs-fixes` or incomplete marketplace result remains.
5. The exact PR head SHA is recorded in this handoff and its CI artifact.
