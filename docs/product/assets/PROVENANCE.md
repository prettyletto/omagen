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
| Omagen icon | `docs/product/assets/branding/omagen-icon.png` | Project-provided branding asset | Maintainer confirmation required |
| Omagen wordmark | `docs/product/assets/branding/omagen-wordmark.png` | Project-provided branding asset | Maintainer confirmation required |
| Social preview | `docs/product/assets/social/omagen-social-preview-v2.png` | Project artwork assembled for Omagen | Confirm project ownership and any embedded source imagery |
| Walkthrough thumbnail | `docs/product/assets/social/omagen-walkthrough-thumbnail-v2.png` | Project capture/artwork | Confirm project ownership and permissions |
| Marketplace preview (root copy) | `preview.png` | Byte-for-byte copy of the walkthrough thumbnail | Confirm project ownership and permissions |
| Hero workflow GIF | `docs/product/assets/demos/omagen-demo-v2.gif` | Project screen recording | Confirm all visible desktop artwork and UI may be published |
| Setup screenshots | `docs/product/assets/screenshots/setup-v2/` | Project captures from the Omagen workflow | Confirm visible backgrounds and UI may be published |
| Bar gallery | `docs/product/assets/screenshots/bar-examples/` | Project captures from Omagen bar presets | Confirm visible backgrounds and UI may be published |

## v2 example pairs

The six v2 examples were selected from the local `*-example` themes and pair
each theme's own background with its generated preview. The current source
mapping is:

| Example | Source theme / recipe | Background | Generated preview | Rights status |
| --- | --- | --- | --- | --- |
| Elastic Example | `elastic-example` / `elastic-orbit` | `assets/examples/v2/elastic-example-background.webp` | `assets/examples/v2/elastic-example-preview.webp` | Maintainer confirmation required |
| Gothic Example | `gothic-example` / `gothic-cathedral` | `assets/examples/v2/gothic-example-background.webp` | `assets/examples/v2/gothic-example-preview.webp` | Maintainer confirmation required |
| Japan Example | `japan-example` / `oriental` | `assets/examples/v2/japan-example-background.webp` | `assets/examples/v2/japan-example-preview.webp` | Maintainer confirmation required |
| Nature Example | `nature-example` / `nature` | `assets/examples/v2/nature-example-background.webp` | `assets/examples/v2/nature-example-preview.webp` | Maintainer confirmation required |
| Retro Example | `retro-example` / `retro` | `assets/examples/v2/retro-example-background.webp` | `assets/examples/v2/retro-example-preview.webp` | Maintainer confirmation required |
| Spectral Example | `spectral-example` / `spectral-shift` | `assets/examples/v2/spectral-example-background.webp` | `assets/examples/v2/spectral-example-preview.webp` | Maintainer confirmation required |

The historical gallery remains labeled “made with Omagen v1”. It should be
reviewed by the same process before being treated as a redistributable release
asset.

## Maintainer completion record

Fill this section before stable release; do not replace these fields with
guesses.

- Reviewer: `TBD`
- Review date: `TBD`
- Asset sources and licenses recorded: `TBD`
- Permission evidence linked: `TBD`
- Unlicensed or uncertain assets removed from the stable package: `TBD`
