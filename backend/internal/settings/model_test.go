package settings

import (
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/palette"
)

func TestValidateRejectsKnownButUnsupportedHarmony(t *testing.T) {
	settings := Defaults()
	settings.ColorTheory.Harmony = palette.HarmonyTriadic

	err := settings.Validate()
	if err == nil || !strings.Contains(err.Error(), "unsupported color harmony") {
		t.Fatalf("got error %v, want unsupported harmony error", err)
	}
}
