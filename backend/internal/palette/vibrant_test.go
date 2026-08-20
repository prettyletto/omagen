package palette

import "testing"

func TestVibrantPreservesMode(t *testing.T) {
	base := calmTestPalette()
	got, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mode != base.Mode {
		t.Fatalf("mode = %q, want %q", got.Mode, base.Mode)
	}
}

func TestVibrantIncreasesLowChromaAccent(t *testing.T) {
	base := calmTestPalette()
	base.Accent = "#9d737b"
	before := mustLCH(t, base.Accent)
	got, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	after := mustLCH(t, got.Accent)
	if after.C <= before.C {
		t.Fatalf("vibrant accent did not gain chroma: before=%.6f after=%.6f", before.C, after.C)
	}
}

func TestVibrantBoostsLowChromaMoreThanHighChroma(t *testing.T) {
	transform := colorTransform{chromaScale: 1.10, chromaTarget: 0.18, chromaBlend: 0.72}
	lowGain := transformChroma(0.04, transform) - 0.04
	highGain := transformChroma(0.18, transform) - 0.18
	if lowGain <= highGain {
		t.Fatalf("adaptive vibrant transform should boost low chroma more: low gain=%.6f high gain=%.6f", lowGain, highGain)
	}
}

func TestVibrantPreservesAccentHue(t *testing.T) {
	base := calmTestPalette()
	got, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if distance := hueDistance(before.H, after.H); distance > 3.0 {
		t.Fatalf("accent hue moved too far: before=%.3f after=%.3f distance=%.3f", before.H, after.H, distance)
	}
}

func TestVibrantDoesNotBehaveLikeDeep(t *testing.T) {
	base := calmTestPalette()
	deep, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	vibrant, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	baseL, deepL, vibrantL := mustLCH(t, base.Background).L, mustLCH(t, deep.Background).L, mustLCH(t, vibrant.Background).L
	if abs(vibrantL-baseL) >= abs(deepL-baseL) {
		t.Fatalf("vibrant changed tonal depth as much as deep: vibrant=%.6f deep=%.6f", abs(vibrantL-baseL), abs(deepL-baseL))
	}
}

func TestVibrantProducesValidPalette(t *testing.T) {
	got, err := Vibrant(calmTestPalette())
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Validate(); err != nil {
		t.Fatalf("vibrant palette invalid: %v", err)
	}
}

func TestVibrantDeterministic(t *testing.T) {
	base := calmTestPalette()
	first, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("vibrant transformation is not deterministic")
	}
}
