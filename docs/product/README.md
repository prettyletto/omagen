<!-- omagen-product-readme: canonical-source -->
# Omagen

<!-- omagen-product-source-only:start -->
> This is the canonical product README source. On `nightly` and `dev`, the
> repository root README intentionally remains developer-facing. The release
> workflow projects this document to the repository root for `main`.
<!-- omagen-product-source-only:end -->

Omagen is an Omarchy Quattro plugin for generating and safely applying themes
from images. It includes two separately owned packages:

- `pretty.omagen` — the image generator overlay and launcher/status widget.
- `pretty.omagen.bar` — the optional full-bar plugin.

## Product overview

<!-- TODO: Write the user-facing overview, value proposition, and release
     highlights here. Keep implementation details in docs/development/. -->

## Demos and examples

<!-- TODO: Add the product screenshots, demo recording, and curated examples.
     Keep their source assets under docs/product/assets/. -->

- [Product assets and asset checklist](assets/README.md)
- [Demo materials](demos/README.md)
- [Examples](examples/README.md)

## Installation

<!-- TODO: Document the stable Omarchy plugin-manager installation command and
     the exact stable release/version being installed. Do not add a mutable
     nightly or dev install path here. -->

## Usage

<!-- TODO: Document the first-run workflow, image selection, generation,
     Preview, Demo, Apply, Cancel, and Quit in product language. -->

## Upgrade, recovery, and removal

<!-- TODO: Document the supported upgrade from the current stable release,
     ownership-aware recovery, rollback, and removal of both packages. -->

## Trust boundary and capabilities

Omagen is unsandboxed user-level plugin code. The final product documentation
must explain which user files, themes, settings, shell resources, and session
paths it can modify, why bundled executables and an installer exist, and how
recovery and uninstall preserve resources that Omagen does not own. Omagen does
not require `sudo`, install system packages, or configure privileged services.

The marketplace preflight is a release gate and exact-commit evidence; it is
not a security certification, endorsement, or guarantee. See the developer
[security policy](../../SECURITY.md) and [release process](../development/release-process.md)
for the maintainer-level details.

## License

Omagen is released under the [MIT License](../../LICENSE).
