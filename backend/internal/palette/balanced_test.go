package palette

import "testing"

func TestBalancedPreservesMode(t *testing.T) {
	base := calmTestPalette()
	got, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mode != base.Mode {
		t.Fatalf("mode = %q, want %q", got.Mode, base.Mode)
	}
}

func TestBalancedRaisesLowChroma(t *testing.T) {
	transform := colorTransform{chromaScale: 1, chromaTarget: 0.12, chromaBlend: 0.40}
	before := 0.03
	if after := transformChroma(before, transform); after <= before {
		t.Fatalf("balanced transform did not raise low chroma: before=%.6f after=%.6f", before, after)
	}
}

func TestBalancedRestrainsHighChroma(t *testing.T) {
	transform := colorTransform{chromaScale: 1, chromaTarget: 0.12, chromaBlend: 0.40}
	before := 0.22
	if after := transformChroma(before, transform); after >= before {
		t.Fatalf("balanced transform did not restrain high chroma: before=%.6f after=%.6f", before, after)
	}
}

func TestBalancedPreservesAccentHue(t *testing.T) {
	base := calmTestPalette()
	got, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if distance := hueDistance(before.H, after.H); distance > 3 {
		t.Fatalf("accent hue moved too far: before=%.3f after=%.3f distance=%.3f", before.H, after.H, distance)
	}
}

func TestBalancedIsLessTonalThanDeep(t *testing.T) {
	base := calmTestPalette()
	deep, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	balanced, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	baseL, deepL, balancedL := mustLCH(t, base.Background).L, mustLCH(t, deep.Background).L, mustLCH(t, balanced.Background).L
	if abs(balancedL-baseL) >= abs(deepL-baseL) {
		t.Fatalf("balanced should alter tonal depth less than deep: balanced=%.6f deep=%.6f", abs(balancedL-baseL), abs(deepL-baseL))
	}
}

func TestBalancedMeaningfullyDiffersFromSource(t *testing.T) {
	base := calmTestPalette()
	got, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Background), mustLCH(t, got.Background)
	if abs(after.L-before.L) < 0.015 {
		t.Fatalf("balanced background is too close to source: before=%.6f after=%.6f", before.L, after.L)
	}
}

func TestBalancedIsLessChromaticThanVibrant(t *testing.T) {
	base := calmTestPalette()
	vibrant, err := Vibrant(base)
	if err != nil {
		t.Fatal(err)
	}
	balanced, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	if balancedC, vibrantC := mustLCH(t, balanced.Accent).C, mustLCH(t, vibrant.Accent).C; balancedC >= vibrantC {
		t.Fatalf("balanced accent should remain below vibrant: balanced=%.6f vibrant=%.6f", balancedC, vibrantC)
	}
}

func TestBalancedKeepsForegroundIdentity(t *testing.T) {
	base := calmTestPalette()
	got, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Foreground != base.Foreground || got.BrightForeground != base.BrightForeground {
		t.Fatal("balanced changed foreground identity")
	}
}

func TestBalancedProducesValidPalette(t *testing.T) {
	got, err := Balanced(calmTestPalette())
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Validate(); err != nil {
		t.Fatalf("balanced palette invalid: %v", err)
	}
}

func TestBalancedDeterministic(t *testing.T) {
	base := calmTestPalette()
	first, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Balanced(base)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("balanced transformation is not deterministic")
	}
}
