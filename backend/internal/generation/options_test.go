package generation

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/palette"
)

func TestDefaultOptions(t *testing.T) {
	options := DefaultOptions()
	if options.ColorTheory.Harmony != palette.HarmonyAuto {
		t.Fatalf("got harmony %q, want auto", options.ColorTheory.Harmony)
	}
	if err := options.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestOptionsNormalize(t *testing.T) {
	options := (Options{}).Normalize()
	if options.ColorTheory.Harmony != palette.HarmonyAuto {
		t.Fatalf("got harmony %q, want auto", options.ColorTheory.Harmony)
	}
}

func TestOptionsRejectInvalidHarmony(t *testing.T) {
	options := Options{
		ColorTheory: ColorTheoryOptions{Harmony: "random"},
	}
	if err := options.Validate(); err == nil {
		t.Fatal("expected invalid harmony to fail")
	}
}
