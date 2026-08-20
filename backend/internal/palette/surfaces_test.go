package palette

import "testing"

func TestNormalizeSurfaceHierarchyDark(t *testing.T) {
	base := calmTestPalette()
	base.Background = "#240309"
	base.DarkBackground = "#2e0f14"
	base.DarkerBackground = "#1f070c"
	base.LighterBackground = "#5c2e36"
	got, err := NormalizeSurfaceHierarchy(base)
	if err != nil {
		t.Fatal(err)
	}
	background := mustLCH(t, got.Background)
	dark := mustLCH(t, got.DarkBackground)
	darker := mustLCH(t, got.DarkerBackground)
	lighter := mustLCH(t, got.LighterBackground)
	if !(darker.L < dark.L && dark.L < background.L && background.L < lighter.L) {
		t.Fatalf("invalid dark hierarchy: darker=%.4f dark=%.4f background=%.4f lighter=%.4f", darker.L, dark.L, background.L, lighter.L)
	}
}

func TestNormalizeSurfaceHierarchyLight(t *testing.T) {
	base := calmTestPalette()
	base.Mode = "light"
	base.Background = "#ebe7df"
	base.DarkBackground = "#f5f1ea"
	base.DarkerBackground = "#d7d2ca"
	base.LighterBackground = "#e5e1d9"
	got, err := NormalizeSurfaceHierarchy(base)
	if err != nil {
		t.Fatal(err)
	}
	background := mustLCH(t, got.Background)
	dark := mustLCH(t, got.DarkBackground)
	darker := mustLCH(t, got.DarkerBackground)
	lighter := mustLCH(t, got.LighterBackground)
	if !(darker.L < dark.L && dark.L < background.L && background.L < lighter.L) {
		t.Fatalf("invalid light hierarchy: darker=%.4f dark=%.4f background=%.4f lighter=%.4f", darker.L, dark.L, background.L, lighter.L)
	}
}
