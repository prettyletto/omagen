# Product asset provenance

This ledger records what is known about the product-facing assets included in
the repository. It is deliberately conservative: “pending confirmation” is a
release blocker for redistribution, not evidence that an asset is unsafe to
use locally.

## Release rule

Before the `dev → main` promotion, a maintainer must confirm that every asset
copied into the stable repository may be redistributed under the repository's
license or under the asset's documented license. Record the source, creator,
license, and permission evidence in this file or in an adjacent notice. Do not
present marketplace verification as a license review or security certification.

## Current ledger

| Asset group | Repository path | Source or creator | Status for stable release |
| --- | --- | --- | --- |
| Omagen icon | `docs/product/assets/branding/omagen-icon.png` | Project-provided branding asset | Maintainer permission confirmed 2026-09-02 |
| Omagen wordmark | `docs/product/assets/branding/omagen-wordmark.png` | Project-provided branding asset | Maintainer permission confirmed 2026-09-02 |
| Social preview | `docs/product/assets/social/omagen-social-preview-v2.png` | Project artwork assembled for Omagen | Maintainer permission confirmed 2026-09-02 |
| Walkthrough thumbnail | `docs/product/assets/social/omagen-walkthrough-thumbnail-v2.png` | Project capture/artwork | Maintainer permission confirmed 2026-09-02 |
| Marketplace preview (root copy) | `preview.png` | Byte-for-byte copy of the walkthrough thumbnail | Maintainer permission confirmed 2026-09-02 |
| Hero workflow GIF | `docs/product/assets/demos/omagen-demo-v2.gif` | Project screen recording | Maintainer permission confirmed 2026-09-02 |
| Setup screenshots | `docs/product/assets/screenshots/setup-v2/` | Project captures from the Omagen workflow | Maintainer permission confirmed 2026-09-02 |
| Bar gallery | `docs/product/assets/screenshots/bar-examples/` | Project captures from Omagen bar presets | Maintainer permission confirmed 2026-09-02 |

## v2 example pairs

The five v2 examples were selected from the local `*-example` themes and pair
each theme's own background with its generated preview. The current source
mapping is:

| Example | Source theme / recipe | Background | Generated preview | Rights status |
| --- | --- | --- | --- | --- |
| Elastic Example | `elastic-example` / `elastic-orbit` | `assets/examples/v2/elastic-example-background.webp` | `assets/examples/v2/elastic-example-preview.webp` | Maintainer permission confirmed 2026-09-02 |
| Gothic Example | `gothic-example` / `gothic-cathedral` | `assets/examples/v2/gothic-example-background.webp` | `assets/examples/v2/gothic-example-preview.webp` | Maintainer permission confirmed 2026-09-02 |
| Japan Example | `japan-example` / `oriental` | `assets/examples/v2/japan-example-background.webp` | `assets/examples/v2/japan-example-preview.webp` | Maintainer permission confirmed 2026-09-02 |
| Nature Example | `nature-example` / `nature` | `assets/examples/v2/nature-example-background.webp` | `assets/examples/v2/nature-example-preview.webp` | Maintainer permission confirmed 2026-09-02 |
| Retro Example | `retro-example` / `retro` | `assets/examples/v2/retro-example-background.webp` | `assets/examples/v2/retro-example-preview.webp` | Maintainer permission confirmed 2026-09-02 |

The historical gallery remains labeled “made with Omagen v1”. It should be
reviewed by the same process before being treated as a redistributable release
asset.

## Maintainer completion record

This is the maintainer's release declaration for the project-provided assets
in this snapshot. Marketplace verification remains a separate exact-commit
baseline check and is not a license review.

- Reviewer: Project maintainer
- Review date: `2026-09-02`
- Asset sources and licenses recorded: Project-provided branding, captures, artwork, and generated example pairs are cleared for repository redistribution by maintainer confirmation.
- Permission evidence linked: Maintainer release record; Omagen does not claim an external asset license for embedded source imagery.
- Unlicensed or uncertain assets removed from the stable package: The mismatched Spectral v2 example pair was removed before promotion.

## Stable snapshot verification

- Stable commit: The exact final `main` SHA is recorded by the commit-bound CI artifact after promotion; never reuse an earlier report.
- Release tag: `v2.0.0` (only after the final `main` commit is immutable)
- Marketplace preflight: Must be `passed` or accompanied by exact maintainer approval of `review-required` findings.
- Preflight artifact: `marketplace-preflight-<final-main-sha>`
- CI run: The exact-main workflow run associated with the final SHA.
