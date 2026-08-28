# Palette engine change

Read `docs/architecture/backend.md`, the generation pipeline section of
`docs/architecture/contracts/engine.md`, and the target package under
`backend/internal/imageanalysis`, `colorspace`, `palette`, or `contrast`.

Normally do not touch Bar, QML, session/recovery, or runtime code. Preserve
determinism, OKLab/colorspace behavior, semantic contrast guarantees, source
identity, and the Source/Calm/Mute/Deep/Vibrant/Balanced variants.

Run the focused package tests, then `go test ./...`, `go test -race ./...`, and
`go vet ./...`. Use fixture-based checks for visual/palette changes. Common
trap: a locally plausible color result can still break generated theme
contracts or light/dark mode preservation.
