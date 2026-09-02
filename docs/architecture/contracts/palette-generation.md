# Palette and generation contract

Palette generation is a deterministic backend pipeline. Preview and permanent
generation use the same transformations, contrast rules, and theme writers;
QML and runtime adapters must not recreate these algorithms.

## Pipeline

1. `imageanalysis.DecodeFile` decodes supported images, rejects invalid or
   oversized input, and samples at most 65,536 visible pixels.
2. Samples are converted from sRGB to OKLab. Deterministic weighted clustering
   produces representative colors with coverage; close representatives are
   merged and the result is sorted deterministically.
3. `palette.Source` selects semantic roles for surface, foreground, accent,
   selection, muted text, and ANSI colors. Optional harmony changes hue
   relationships without changing the role model.
4. `generation` emits exactly six ordered directions:
   `source`, `calm`, `mute`, `deep`, `vibrant`, `balanced`. `source` is the
   source palette; the other five are transformations, with `deep` also
   normalizing surface hierarchy.
5. Derived directions pass through `contrast.Enforce`. ANSI colors then pass
   through `EnsureANSIDistinctAfterContrast`, which repairs exact collisions
   without weakening the contrast guarantee. Installed-theme edits preserve
   their authored `source` palette; derived directions still use the normal
   contract.
6. `theme` writes the requested artifacts: `colors.toml`, optional
   `shell.toml`, `hyprland.lua`, background, BarSpec/profile, and
   Look & Feel/runtime metadata.

## Invariants

- Identical input, settings, and style documents produce deterministic output.
- Direction names and order are wire-visible to palette cards, Preview, and
  Apply. Do not rename or reorder them casually.
- Color math uses OKLab/OKLCH internally and sRGB hex at file seams;
  `colorspace` owns conversion and gamut mapping.
- Contrast and role selection belong to `contrast` and `palette`, not QML.
- Generation commits its temporary workspace only after all requested variants
  and artifacts succeed; a failure leaves the previous session recoverable.

## Test surface

Tests beside `imageanalysis`, `colorspace`, `palette`, `contrast`, and
`generation` cover decoding, clustering, conversion, harmony, each
direction, contrast, ANSI distinctness, determinism, atomic generation
replacement, and installed-theme source preservation. When changing a
protected algorithm, update the nearest package tests and verify Preview and
Apply still consume the same generated artifacts.
