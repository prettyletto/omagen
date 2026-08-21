package palette

import (
	"fmt"
	"strings"
)

type Harmony string

const (
	HarmonyAuto               Harmony = "auto"
	HarmonyMonochromatic      Harmony = "monochromatic"
	HarmonyAnalogous          Harmony = "analogous"
	HarmonyComplementary      Harmony = "complementary"
	HarmonySplitComplementary Harmony = "split_complementary"
	HarmonyTriadic            Harmony = "triadic"
)

func ParseHarmony(value string) (Harmony, error) {
	harmony := Harmony(strings.ToLower(strings.TrimSpace(value)))
	if err := harmony.Validate(); err != nil {
		return "", err
	}
	return harmony, nil
}

func (h Harmony) Validate() error {
	switch h {
	case HarmonyAuto,
		HarmonyMonochromatic,
		HarmonyAnalogous,
		HarmonyComplementary,
		HarmonySplitComplementary,
		HarmonyTriadic:
		return nil
	default:
		return fmt.Errorf("invalid color harmony %q", h)
	}
}

func (h Harmony) ValidateSupported() error {
	return h.Validate()
}
