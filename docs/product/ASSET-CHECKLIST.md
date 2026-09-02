# Product asset and content checklist

This is the handoff list for the v2 product presentation. Existing media is
kept as a useful baseline; replace or supplement it deliberately after each
new capture is reviewed. Do not delete the current gallery until replacement
assets have been selected and all links have been updated.

## Stable snapshot status

| Item | Suggested location | What to produce | Status |
| --- | --- | --- | --- |
| Hero workflow animation | `docs/product/assets/demos/omagen-demo-v2.gif` | Full image → directions → Preview/Demo → Apply sequence at readable quality | Captured at 30 fps and 960×540; keep local until release hosting is available |
| Walkthrough thumbnail | `docs/product/assets/` | A clean 16:9 thumbnail for the YouTube walkthrough | Supplied at `assets/social/omagen-walkthrough-thumbnail-v2.png` |
| Setup screenshots | `assets/screenshots/` or `docs/product/assets/` | Choose image, first launch, and settings | v2 sequence captured in `assets/screenshots/setup-v2/` |
| Palette screenshots | Same | Gallery with all six directions and one selected direction | v2 generated gallery and Balanced selection captured |
| Live Canvas screenshots | Same | Fast path, In-depth path, and Preview/Test live | Maintainer-confirmed sufficient for v2; attach exact capture record to the release evidence |
| Demo screenshots | Same | Full Demo plus at least one focused Window/Shell/Bar Demo | Maintainer-confirmed sufficient for v2; attach exact capture record to the release evidence |
| Recovery screenshot | Same | Interrupted-session recovery with Restore & close/Resume | Maintainer-confirmed sufficient for v2; attach exact capture record to the release evidence |
| Full-bar screenshot | Same | Optional `pretty.omagen.bar` enabled, with native fallback explained | Seven v2 bar examples captured; maintainer-confirmed sufficient; release record still needed |
| Example pairs | `assets/examples/` | Five to eight source wallpaper/generated-result pairs with captions | Five v2 pairs retained after removing the mismatched Spectral pair; v1 gallery retained and labeled; provenance ledger added |
| Product icon/wordmark | `docs/product/assets/branding/` | Recognizable header mark and wordmark for README and listings | Provided; provenance ledger added; confirm redistribution rights and export variants |
| Marketplace preview | `docs/product/assets/social/omagen-walkthrough-thumbnail-v2.png` → root `preview.png` on `main` | Final listing image within marketplace limits | Selected v2 thumbnail copied to the candidate root preview; promote unchanged for the stable commit |

## Recommended captures

1. A five-minute complete walkthrough for the product README and YouTube.
2. A short fast-path clip for users who only want image-to-theme generation.
3. An In-depth clip showing Look & Feel, Window, Shell, Bar, and reduced motion.
4. A Demo clip showing fallback capability behavior without exposing personal
   files or names.
5. An interrupted Apply/recovery clip or still sequence.
6. A before/after desktop pair using the same source wallpaper.

## Remaining evidence before marketplace submission

The stable v2 product snapshot is now in `main` at
`92ff73ac17211755dd6790a89519371717eaeacf`, tagged `v2.0.0`. The maintainer
considers the current live-desktop evidence sufficient for the v2 product
presentation. The following records still need to be attached before
marketplace submission:

- At least five independent installations, two upgrades, and one interrupted
  session recovery run across the supported Omarchy versions.
- Asset-license and redistribution confirmation recorded in
  [`assets/PROVENANCE.md`](assets/PROVENANCE.md).
- Final marketplace preview and the `review-required`, zero-finding preflight
  report bound to the immutable stable `main` SHA. The report is uploaded as
  the `marketplace-preflight-92ff73ac17211755dd6790a89519371717eaeacf` artifact
  on the [exact-main CI run](https://github.com/prettyletto/omagen/actions/runs/33668731439).

## Capture rules

- Use a clean, disposable user profile with no personal files or credentials.
- Capture the same supported Omarchy version recorded in the release evidence.
- Keep source wallpapers and generated results in matched pairs.
- Record the exact Omagen commit and any third-party asset license.
- Prefer WebP screenshots for repository size and PNG only where lossless
  output is materially useful.
- Keep the hero animation short, readable, and usable without audio.
- Never present a developer branch, mutable URL, or unfinished feature as the
  stable installation path.
