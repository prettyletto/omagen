package palette

import "testing"

func TestMutePreservesMode(t *testing.T) {
	base := calmTestPalette()
	got, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Mode != base.Mode {
		t.Fatalf("mode = %q, want %q", got.Mode, base.Mode)
	}
}

func TestMuteReducesAccentChromaMoreThanCalm(t *testing.T) {
	base := calmTestPalette()
	calm, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	muted, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	calmAccent, muteAccent := mustLCH(t, calm.Accent), mustLCH(t, muted.Accent)
	if muteAccent.C >= calmAccent.C {
		t.Fatalf("mute accent is not less chromatic than calm: calm=%.6f mute=%.6f", calmAccent.C, muteAccent.C)
	}
}

func TestMutePreservesAccentHue(t *testing.T) {
	base := calmTestPalette()
	got, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	before, after := mustLCH(t, base.Accent), mustLCH(t, got.Accent)
	if distance := hueDistance(before.H, after.H); distance > 3.0 {
		t.Fatalf("accent hue moved too far: before=%.3f after=%.3f distance=%.3f", before.H, after.H, distance)
	}
}

func TestMuteCompressesSurfacesMoreThanCalm(t *testing.T) {
	base := calmTestPalette()
	calm, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	muted, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	calmBackground, calmLighter := mustLCH(t, calm.Background), mustLCH(t, calm.LighterBackground)
	muteBackground, muteLighter := mustLCH(t, muted.Background), mustLCH(t, muted.LighterBackground)
	calmDistance := abs(calmLighter.L - calmBackground.L)
	muteDistance := abs(muteLighter.L - muteBackground.L)
	if muteDistance >= calmDistance {
		t.Fatalf("mute surface spread should be tighter than calm: calm=%.6f mute=%.6f", calmDistance, muteDistance)
	}
}

func TestMuteReducesANSIChromaMoreThanCalm(t *testing.T) {
	base := calmTestPalette()
	calm, err := Calm(base)
	if err != nil {
		t.Fatal(err)
	}
	muted, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	calmRed, muteRed := mustLCH(t, calm.Red), mustLCH(t, muted.Red)
	if muteRed.C >= calmRed.C {
		t.Fatalf("mute ANSI chroma should be below calm: calm=%.6f mute=%.6f", calmRed.C, muteRed.C)
	}
}

func TestMuteKeepsForegroundIdentity(t *testing.T) {
	base := calmTestPalette()
	got, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	if got.Foreground != base.Foreground {
		t.Fatalf("foreground changed: got %s want %s", got.Foreground, base.Foreground)
	}
	if got.BrightForeground != base.BrightForeground {
		t.Fatalf("bright foreground changed: got %s want %s", got.BrightForeground, base.BrightForeground)
	}
}

func TestMuteProducesValidPalette(t *testing.T) {
	got, err := Mute(calmTestPalette())
	if err != nil {
		t.Fatal(err)
	}
	if err := got.Validate(); err != nil {
		t.Fatalf("mute palette invalid: %v", err)
	}
}

func TestMuteDeterministic(t *testing.T) {
	base := calmTestPalette()
	first, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Mute(base)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("mute transformation is not deterministic")
	}
}
