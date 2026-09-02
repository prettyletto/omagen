# Product assets

Store product-facing screenshots, demo recordings, and release artwork here.
Use stable, descriptive filenames and keep source captures or editing files
outside the plugin package when they are not needed by the documentation.

## Branding

The current Omagen icon and wordmark are stored in `branding/`. They are the
project-provided source assets for the README and future marketplace artwork.
Before the stable release, confirm the project has permission to redistribute
them and add a transparent/light-background variant if the current dark icon
background is not suitable for every listing surface.

## Social preview

The current v2 social-preview candidate is
`social/omagen-social-preview-v2.png`. It is a 16:9 GitHub/Open Graph cover
with a restrained image-to-palette visual, the supplied Omagen identity, and
minimal copy that remains legible at thumbnail size.

Keep this product-source candidate under review while the main promotion is
prepared. The stable promotion may copy the approved exact asset to the
repository-root `preview.png` used by marketplace tooling; do not change the
image after the stable commit is submitted for verification.

The v2 YouTube walkthrough thumbnail is
`social/omagen-walkthrough-thumbnail-v2.png`. It is a 1920×1080 product
thumbnail linked from the canonical product README to the complete walkthrough
video. Keep the thumbnail and video URL together when the product README is
promoted to `main`.

## Hero demo

The current v2 hero workflow recording is
`demos/omagen-demo-v2.gif`. It preserves the full 51.9-second capture at
30 fps and 960×540, with audio removed for silent README playback. Keep the
original MP4 as the source of truth and do not speed up the workflow merely to
make the GIF shorter.

Because this full-fidelity GIF is approximately 19 MB, it is intentionally
kept as a product asset for now. After the stable release, a GitHub Release
asset can become the canonical hosted copy if the repository would benefit
from a smaller clone and checkout footprint.

The [asset generation checklist](../ASSET-CHECKLIST.md) defines the filenames,
capture goals, dimensions, and provenance required before the stable release.

Before promotion, every referenced asset must be present in the exact commit,
have a reviewable license/provenance, and stay within the marketplace preview
limits when used as a listing preview.

## Setup walkthrough screenshots

The curated v2 setup walkthrough is in
[`screenshots/setup-v2/`](screenshots/setup-v2/). It was captured on workspace
5 from a reversible live session using one source image, then restored to the
original desktop before the capture was accepted. The sequence covers image
selection, workflow choice, palette generation, Balanced selection, Look &
Feel, Glass Blur, Advanced, Demo, final review, and restoration.

The public copies are resized to 1600×1000 for documentation and redact the
local home-directory path visible in the file chooser. The original captures
remain outside the product asset tree under the ignored UI-test workspace.
These screenshots document the product flow; they are not evidence of a
stable release or a marketplace security certification.

## Bar examples

The [`bar-examples/`](screenshots/bar-examples/) gallery shows several product
layouts for the optional full-bar experience: compact and wide variants,
centered and left placements, and a minimal state. The full bar remains an
explicit opt-in package; these images are examples of its visual range, not a
replacement for the native Omarchy bar in the default installation path.
