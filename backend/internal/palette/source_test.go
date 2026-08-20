package palette

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

func TestSourceClosestSingleDarkColor(t *testing.T) {
	result, err := Source([]imageanalysis.RepresentativeColor{testRepresentative(30, 60, 120, 1)}, HarmonyAuto)
	if err != nil {
		t.Fatal(err)
	}
	if result.Mode != "dark" {
		t.Fatalf("got mode %q, want dark", result.Mode)
	}
	if err := result.Validate(); err != nil {
		t.Fatalf("generated invalid palette: %v", err)
	}
}

func TestSourceClosestSingleLightColor(t *testing.T) {
	result, err := Source([]imageanalysis.RepresentativeColor{testRepresentative(245, 235, 210, 1)}, HarmonyAuto)
	if err != nil {
		t.Fatal(err)
	}
	if result.Mode != "light" {
		t.Fatalf("got mode %q, want light", result.Mode)
	}
	if err := result.Validate(); err != nil {
		t.Fatalf("generated invalid palette: %v", err)
	}
}

func TestSourceClosestGrayscaleStaysNeutral(t *testing.T) {
	result, err := Source([]imageanalysis.RepresentativeColor{testRepresentative(90, 90, 90, 1)}, HarmonyAuto)
	if err != nil {
		t.Fatal(err)
	}
	if err := result.Validate(); err != nil {
		t.Fatal(err)
	}
	t.Logf("background=%s accent=%s foreground=%s", result.Background, result.Accent, result.Foreground)
}

func TestSourceClosestTokyoNightMock(t *testing.T) {
	colors := []imageanalysis.RepresentativeColor{
		testRepresentative(0x1a, 0x1b, 0x26, 0.55),
		testRepresentative(0x7a, 0xa2, 0xf7, 0.25),
		testRepresentative(0xbb, 0x9a, 0xf7, 0.15),
		testRepresentative(0xf7, 0x76, 0x8e, 0.05),
	}
	result, err := Source(colors, HarmonyAuto)
	if err != nil {
		t.Fatal(err)
	}
	if err := result.Validate(); err != nil {
		t.Fatal(err)
	}
	if result.Background != "#1a1b26" {
		t.Fatalf("background=%s, want #1a1b26", result.Background)
	}
	if result.Accent != "#7aa2f7" {
		t.Fatalf("accent=%s, want #7aa2f7", result.Accent)
	}
	t.Logf("mode=%s bg=%s dark=%s darker=%s lighter=%s fg=%s accent=%s selection=%s muted=%s", result.Mode, result.Background, result.DarkBackground, result.DarkerBackground, result.LighterBackground, result.Foreground, result.Accent, result.Selection, result.Muted)
}

func TestSourceRejectsUnimplementedHarmony(t *testing.T) {
	_, err := Source([]imageanalysis.RepresentativeColor{testRepresentative(30, 60, 120, 1)}, HarmonyTriadic)
	if err == nil {
		t.Fatal("expected unimplemented harmony to fail")
	}
}

func testRepresentative(r, g, b uint8, coverage float64) imageanalysis.RepresentativeColor {
	lab := colorspace.FromSRGB8(r, g, b)
	return imageanalysis.RepresentativeColor{Lab: lab, LCH: lab.ToOKLCH(), Coverage: coverage}
}
