package palette

import "testing"

func TestDeepPreservesMode(t *testing.T) {
	base := calmTestPalette()
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mode != base.Mode {
		t.Fatalf("mode = %q, want %q", got.Mode, base.Mode)
	}
}

func TestDeepIncreasesAccentChroma(t *testing.T) {
	base := calmTestPalette()
	// Use an in-gamut accent so the assertion measures the Deep
	// profile rather than sRGB gamut mapping at the boundary.
	base.Accent = "#c06a88"
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if after.C <= before.C {
		t.Fatalf("deep accent chroma did not increase: before=%.6f after=%.6f", before.C, after.C)
	}
}

func TestDeepPreservesAccentHue(t *testing.T) {
	base := calmTestPalette()
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if distance := hueDistance(before.H, after.H); distance > 3.0 {
		t.Fatalf("accent hue moved too far: before=%.3f after=%.3f distance=%.3f", before.H, after.H, distance)
	}
}

func TestDeepExpandsSurfaceHierarchy(t *testing.T) {
	base := calmTestPalette()
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	baseBackground, baseLighter := mustLCH(t, base.Background), mustLCH(t, base.LighterBackground)
	deepBackground, deepLighter := mustLCH(t, got.Background), mustLCH(t, got.LighterBackground)
	before := abs(baseLighter.L - baseBackground.L)
	after := abs(deepLighter.L - deepBackground.L)
	if after <= before {
		t.Fatalf("deep surface spread did not increase: before=%.6f after=%.6f", before, after)
	}
}

func TestDeepMovesBackgroundTowardModeExtreme(t *testing.T) {
	base := calmTestPalette()
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Background), mustLCH(t, got.Background)
	switch base.Mode {
	case "dark":
		if after.L >= before.L {
			t.Fatalf("deep dark background did not become deeper: before=%.6f after=%.6f", before.L, after.L)
		}
	case "light":
		if after.L <= before.L {
			t.Fatalf("deep light background did not become deeper into light mode: before=%.6f after=%.6f", before.L, after.L)
		}
	}
}

func TestDeepLightPalettePreservesLightMode(t *testing.T) {
	base := calmTestPalette()
	base.Mode = "light"
	base.Background = "#ebe7df"
	base.DarkBackground = "#d7d2ca"
	base.DarkerBackground = "#c7c2ba"
	base.LighterBackground = "#f5f1ea"
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Background), mustLCH(t, got.Background)
	if after.L >= before.L {
		t.Fatalf("deep light background should move toward its tonal target: before=%.6f after=%.6f", before.L, after.L)
	}
	if abs(after.L-0.82) >= abs(before.L-0.82) {
		t.Fatalf("deep light background did not move toward target: target=0.82 before=%.6f after=%.6f", before.L, after.L)
	}
}

func TestDeepIncreasesANSIChroma(t *testing.T) {
	base := calmTestPalette()
	// Keep the sample below the sRGB gamut boundary so this
	// assertion measures the profile rather than gamut mapping.
	base.Red = "#c06a6a"
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Red), mustLCH(t, got.Red)
	if after.C <= before.C {
		t.Fatalf("deep ANSI chroma did not increase: before=%.6f after=%.6f", before.C, after.C)
	}
}

func TestDeepKeepsForegroundIdentity(t *testing.T) {
	base := calmTestPalette()
	got, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Foreground != base.Foreground || got.BrightForeground != base.BrightForeground {
		t.Fatalf("deep changed foreground identity")
	}
}

func TestDeepProducesValidPalette(t *testing.T) {
	got, err := Deep(calmTestPalette())
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Validate(); err != nil {
		t.Fatalf("deep palette invalid: %v", err)
	}
}

func TestDeepDeterministic(t *testing.T) {
	base := calmTestPalette()
	first, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Deep(base)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("deep transformation is not deterministic")
	}
}
