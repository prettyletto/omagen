package settings

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/palette"
)

func TestValidateAcceptsAllKnownHarmonies(t *testing.T) {
	for _, harmony := range []palette.Harmony{palette.HarmonyAuto, palette.HarmonyMonochromatic, palette.HarmonyAnalogous, palette.HarmonyComplementary, palette.HarmonySplitComplementary, palette.HarmonyTriadic} {
		t.Run(string(harmony), func(t *testing.T) {
			current := Defaults()
			current.ColorTheory.Harmony = harmony
			if err := current.Validate(); err != nil {
				t.Fatalf("harmony %q should be supported: %v", harmony, err)
			}
		})
	}
}
