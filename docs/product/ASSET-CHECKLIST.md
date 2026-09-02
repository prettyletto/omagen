# Product asset and content checklist

This is the handoff list for the v2 product presentation. Existing media is
kept as a useful baseline; replace or supplement it deliberately after each
new capture is reviewed. Do not delete the current gallery until replacement
assets have been selected and all links have been updated.

## Required before the stable `main` promotion

| Item | Suggested location | What to produce | Status |
| --- | --- | --- | --- |
| Hero workflow animation | `assets/omagen-demo.gif` or a new v2 filename | A short image → directions → Preview/Demo → Apply sequence | Existing baseline; recapture for v2 |
| Walkthrough thumbnail | `docs/product/assets/` | A clean 16:9 thumbnail for the YouTube walkthrough | Needs v2 capture |
| Setup screenshots | `assets/screenshots/` or `docs/product/assets/` | Choose image, first launch, and settings | Existing baseline; review for v2 |
| Palette screenshots | Same | Gallery with all six directions and one selected direction | Existing baseline; review for v2 |
| Live Canvas screenshots | Same | Fast path, In-depth path, and Preview/Test live | Needs v2 capture |
| Demo screenshots | Same | Full Demo plus at least one focused Window/Shell/Bar Demo | Needs v2 capture |
| Recovery screenshot | Same | Interrupted-session recovery with Restore & close/Resume | Needs v2 capture |
| Full-bar screenshot | Same | Optional `pretty.omagen.bar` enabled, with native fallback explained | Existing baseline; review for v2 |
| Example pairs | `assets/examples/` | Six to eight source wallpaper/generated-result pairs with captions | Existing baseline; curate v2 set |
| Product icon/wordmark | `docs/product/assets/branding/` | Recognizable header mark and wordmark for README and listings | Provided; confirm redistribution rights and export variants |
| Marketplace preview | Root `preview.png` | Final listing image within marketplace limits | Existing asset; review for v2 |

## Recommended captures

1. A five-minute complete walkthrough for the product README and YouTube.
2. A short fast-path clip for users who only want image-to-theme generation.
3. An In-depth clip showing Look & Feel, Window, Shell, Bar, and reduced motion.
4. A Demo clip showing fallback capability behavior without exposing personal
   files or names.
5. An interrupted Apply/recovery clip or still sequence.
6. A before/after desktop pair using the same source wallpaper.

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
