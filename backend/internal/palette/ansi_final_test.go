package palette

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/contrast"
)

func TestEnsureANSIDistinctAfterContrastRepairsNormalCollision(t *testing.T) {
	input := calmTestPalette()
	input.Green = input.Blue
	got, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	if got.Green == got.Blue {
		t.Fatalf("normal collision was not repaired: %s", got.Green)
	}
	if got.Green != input.Green {
		t.Fatalf("first occurrence changed: before=%s after=%s", input.Green, got.Green)
	}
}

func TestEnsureANSIDistinctAfterContrastRepairsBrightCollision(t *testing.T) {
	input := calmTestPalette()
	input.BrightBlue = input.BrightCyan
	got, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	if got.BrightBlue == got.BrightCyan {
		t.Fatalf("bright collision was not repaired: %s", got.BrightBlue)
	}
}

func TestEnsureANSIDistinctAfterContrastLeavesUniquePaletteAlone(t *testing.T) {
	input := calmTestPalette()
	got, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	if got != input {
		t.Fatal("already unique palette changed")
	}
}

func TestEnsureANSIDistinctAfterContrastPreservesContrast(t *testing.T) {
	input := calmTestPalette()
	input.BrightBlue = input.BrightCyan
	got, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{got.BrightRed, got.BrightYellow, got.BrightGreen, got.BrightCyan, got.BrightBlue, got.BrightMagenta} {
		ratio, err := contrast.Ratio(value, got.Background)
		if err != nil {
			t.Fatal(err)
		}
		if ratio+1e-9 < 4.5 {
			t.Fatalf("%s contrast %.6f is below 4.5", value, ratio)
		}
	}
}

func TestEnsureANSIDistinctAfterContrastIsDeterministic(t *testing.T) {
	input := calmTestPalette()
	input.Green = input.Blue
	input.BrightBlue = input.BrightCyan
	first, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	second, err := EnsureANSIDistinctAfterContrast(input, 3, 4.5)
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatal("finalization is not deterministic")
	}
}
