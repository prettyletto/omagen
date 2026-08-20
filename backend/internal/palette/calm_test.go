package palette

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

func TestCalmPreservesMode(t *testing.T) {
	base := calmTestPalette()
	got, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mode != base.Mode {
		t.Fatalf("mode = %q, want %q", got.Mode, base.Mode)
	}
}

func TestCalmReducesAccentChroma(t *testing.T) {
	base := calmTestPalette()
	got, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	if after, before := mustLCH(t, got.Accent), mustLCH(t, base.Accent); after.C >= before.C {
		t.Fatalf("accent chroma did not decrease: before=%.6f after=%.6f", before.C, after.C)
	}
}

func TestCalmPreservesAccentHue(t *testing.T) {
	base := calmTestPalette()
	got, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if distance := hueDistance(before.H, after.H); distance > 2.0 {
		t.Fatalf("accent hue moved too far: before=%.3f after=%.3f distance=%.3f", before.H, after.H, distance)
	}
}

func TestCalmCompressesSurfaceLightness(t *testing.T) {
	base := calmTestPalette()
	got, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	baseBackground, baseLighter := mustLCH(t, base.Background), mustLCH(t, base.LighterBackground)
	calmBackground, calmLighter := mustLCH(t, got.Background), mustLCH(t, got.LighterBackground)
	if after, before := abs(calmLighter.L-calmBackground.L), abs(baseLighter.L-baseBackground.L); after >= before {
		t.Fatalf("surface spread was not compressed: before=%.6f after=%.6f", before, after)
	}
}

func TestCalmReducesANSIChroma(t *testing.T) {
	base := calmTestPalette()
	got, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	if after, before := mustLCH(t, got.Red), mustLCH(t, base.Red); after.C >= before.C {
		t.Fatalf("ANSI chroma did not decrease: before=%.6f after=%.6f", before.C, after.C)
	}
}

func TestCalmProducesValidPalette(t *testing.T) {
	got, err := Calm(calmTestPalette())
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Validate(); err != nil {
		t.Fatalf("calm palette invalid: %v", err)
	}
}

func TestCalmDeterministic(t *testing.T) {
	base := calmTestPalette()
	first, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("calm transformation is not deterministic")
	}
}

func calmTestPalette() theme.Palette {
	return theme.Palette{
		Mode: "dark", Background: "#1a1b26", DarkBackground: "#12131c", DarkerBackground: "#0c0d14", LighterBackground: "#2a2c39",
		Foreground: "#d9d4e6", DarkForeground: "#7f7a8a", LightForeground: "#ebe6f4", BrightForeground: "#f7f3fa",
		Accent: "#7aa2f7", Selection: "#32415f", Muted: "#6c6f7f",
		Red: "#f7768e", Orange: "#e0af68", Yellow: "#e0c46c", Green: "#9ece6a", Cyan: "#7dcfff", Blue: "#7aa2f7", Magenta: "#bb9af7", Brown: "#a37c5b",
		BrightRed: "#ff899d", BrightYellow: "#f2d580", BrightGreen: "#b1dc7d", BrightCyan: "#91dcff", BrightBlue: "#8fb4ff", BrightMagenta: "#cfadff",
	}
}

func mustLCH(t *testing.T, value string) colorspace.OKLCH {
	t.Helper()
	lch, err := colorspace.OKLCHFromHex(value)
	if err != nil {
		t.Fatal(err)
	}
	return lch
}

func abs(value float64) float64 {
	if value < 0 {
		return -value
	}
	return value
}
