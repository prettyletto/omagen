# Release and promotion process

Omagen uses one controlled promotion path:

```text
nightly → dev → release candidate → main → marketplace verification
```

## Branch contracts

- `nightly` is experimental development. It may be incomplete and does not
  require hosted CI on every push.
- `dev` is the protected integration branch. Pull requests targeting it run
  the full automated gate, including the marketplace preflight, and may create
  release candidates.
- `main` is the stable product branch. It contains the user-facing product
  README, demos, installation, usage, recovery, and release notes.

The root README is intentionally different by branch. `nightly` and `dev` keep
their developer README. Product-facing material is authored canonically under
[`docs/product/`](../product/README.md), then projected to the root during a
controlled release promotion. This keeps developer navigation stable while
making the stable branch present one coherent product.

Never promote `nightly` directly to `main`. A promotion pull request is the
audit boundary between each branch.

## Release states

The `v2.0.0` release uses these immutable states:

1. A reviewed `nightly` snapshot is promoted to `dev`.
2. The validated `dev` head receives a candidate tag such as `v2.0.0-rc.1`.
3. Candidate testing is repeated with a new tag whenever the source commit
   changes.
4. The release workflow creates a `release/*` branch from that exact `dev`
   head, projects the canonical product README to the repository root, and
   opens one reviewed pull request into `main`.
5. The complete generated release branch, including all product code and
   product documentation, is merged into `main`.
6. The exact stable `main` commit receives the `v2.0.0` tag.
7. Only that exact full SHA is submitted to or updated in the Omarchy plugin
   marketplace.

Both `manifest.json` and `bar-manifest.json` are one source-wide plugin set.
Their IDs, entry points, ownership, and synchronized versions must remain
unchanged during candidate approval unless the release is restarted.

## Product documentation promotion

Product documentation is prepared in `docs/product/` on `nightly`, reviewed
and validated on `dev`, and is not copied into the developer README. When the
validated `dev` head is ready, run the **Product documentation promotion**
workflow from the repository's Actions page with:

- the exact full SHA of the current `dev` head;
- the release version, such as `v2.0.0`; and
- a new `release/<version>` branch name.

The workflow refuses a moved or mutable `dev` source, validates product links,
projects the canonical README to the repository root, records
`.github/release-provenance.json`, and opens a pull request into `main`. It does
not write directly to or merge the protected stable branch. The resulting
release pull request is the single review boundary for the complete product
code and the stable product presentation.

## Required gates

From the repository root, run the local gate in a zsh environment:

```zsh
GOCACHE=/tmp/omagen-gocache ./scripts/v1-check.sh
python3 scripts/marketplace-preflight.py --report /tmp/omagen-marketplace-report.json
```

The marketplace preflight is deterministic and read-only. It binds its report
to the full Git SHA, plugin IDs, entry points, policy version, findings,
capabilities, and scan limits. It never executes plugin code or downloaded
content.

The outcomes are:

- `passed` — no findings or review capabilities.
- `review-required` — capabilities such as installers or bundled executables
  need explicit maintainer review.
- `needs-fixes` — a blocking finding, malformed repository, incomplete scan,
  or exceeded limit prevents promotion.

The preflight is not a security audit, certification, endorsement, or safety
guarantee. Omagen remains unsandboxed plugin code; release documentation must
describe what it can modify and how users can recover or uninstall it.

On a pull request targeting `dev`, the manifest comparison baseline is the
pull request's previous `dev` head. On a generated release pull request
targeting `main`, the baseline is the exact `sourceSha` recorded in
`.github/release-provenance.json`, not the older stable branch. This preserves
the intentional v2 addition of `pretty.omagen.bar` while still proving that
the stable projection did not alter the reviewed source-wide manifest set.

## Marketplace submission

After the stable `main` commit is immutable:

1. Confirm the repository root contains the manifest, README, license, and
   dependency documentation.
2. Run the preflight against the exact full 40-character `main` SHA.
3. Submit or update the marketplace listing using that SHA and the complete
   source-wide plugin ID set.
4. Preserve the marketplace submission form's required headings and checked
   ownership, installation, license, and safety acknowledgements.
5. Wait for compatibility validation and the automated security baseline.
6. Resolve `needs-fixes` findings in a new commit and restart validation.
7. For `review-required`, provide maintainer notes for the installer and
   bundled executables and request review only after the current report exists.
8. Never reuse a report after the repository changes.

Marketplace verification describes an exact snapshot. It does not certify the
plugin, and mutable upstream installation can differ from the reviewed commit.
Users must still inspect the source and decide whether to trust the plugin.

## Promotion checklist

- [ ] Current working-tree changes are reviewed and committed.
- [ ] The `main` security hardening for bounded file reads is preserved.
- [ ] Backend tests, race tests, vet, QML checks, and package checks pass.
- [ ] Demo cleanup proves session-owned path boundaries.
- [ ] Preview, Apply, Cancel, Quit, and Recovery paths are tested.
- [ ] Both supported Omarchy versions are tested on a real desktop.
- [ ] Fresh install, upgrade, uninstall, and rollback are tested.
- [ ] Both manifests and bundled binaries report the same release version.
- [ ] The checked-in GLSL/QSB pairs pass `scripts/verify-shader-provenance.py`.
- [ ] Fresh-package validation passes from a clean Git-backed package fixture.
- [ ] Marketplace preflight is `passed` or has exact maintainer-approved
  `review-required` evidence.
- [ ] The canonical `docs/product/` source is complete and reviewed.
- [ ] The generated release branch records the exact `dev` SHA in
  `.github/release-provenance.json`.
- [ ] The developer README remains on `nightly` and `dev`; the projected stable
  product README is present at the root of `main`, with demos, screenshots,
  installation, upgrade, recovery, and release notes visible.
- [ ] Release notes describe capabilities, trust boundaries, limitations, and
  recovery.

## Branch protection

Configure GitHub repository rules so that:

- `dev` and `main` require pull requests and passing required checks.
- `dev` and `main` reject force-pushes and branch deletion.
- `main` promotion pull requests must use a generated `release/*` branch whose
  provenance points to the current exact `dev` head.
- Stable release tags can only be created from protected `main` heads.
- Required checks are dismissed when new commits are pushed.
- At least one maintainer approval is required for promotion.

These settings are repository-host configuration and cannot be enforced by a
committed workflow alone; the workflows include source-branch guards as a
second line of defense.
