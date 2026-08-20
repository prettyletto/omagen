package palette

import "testing"

func assertHarmonyHueNear(t *testing.T, value string, expected, tolerance float64) {
	t.Helper()
	hue := mustLCH(t, value).H
	if hueDistance(hue, expected) > tolerance {
		t.Fatalf("hue %.3f is not near %.3f", hue, expected)
	}
}

func TestMonochromaticSemanticRolesShareAnchor(t *testing.T) {
	got, err := ApplyHarmony(calmTestPalette(), HarmonyMonochromatic)
	if err != nil {
		t.Fatal(err)
	}
	anchor := mustLCH(t, got.Accent).H
	assertHarmonyHueNear(t, got.Selection, anchor, 5)
	assertHarmonyHueNear(t, got.Muted, anchor, 5)
}

func TestAnalogousSemanticRolesUseNeighboringHues(t *testing.T) {
	got, err := ApplyHarmony(calmTestPalette(), HarmonyAnalogous)
	if err != nil {
		t.Fatal(err)
	}
	anchor := mustLCH(t, got.Accent).H
	assertHarmonyHueNear(t, got.Selection, normalizeHue(anchor+30), 5)
	assertHarmonyHueNear(t, got.Muted, normalizeHue(anchor-30), 5)
}

func TestComplementarySemanticRolesUseOppositeHue(t *testing.T) {
	got, err := ApplyHarmony(calmTestPalette(), HarmonyComplementary)
	if err != nil {
		t.Fatal(err)
	}
	anchor := mustLCH(t, got.Accent).H
	assertHarmonyHueNear(t, got.Selection, normalizeHue(anchor+180), 5)
	assertHarmonyHueNear(t, got.Muted, normalizeHue(anchor+180), 5)
}

func TestSplitComplementarySemanticRolesUseSplitHues(t *testing.T) {
	got, err := ApplyHarmony(calmTestPalette(), HarmonySplitComplementary)
	if err != nil {
		t.Fatal(err)
	}
	anchor := mustLCH(t, got.Accent).H
	assertHarmonyHueNear(t, got.Selection, normalizeHue(anchor+150), 5)
	assertHarmonyHueNear(t, got.Muted, normalizeHue(anchor+210), 5)
}

func TestTriadicSemanticRolesUseEvenHues(t *testing.T) {
	got, err := ApplyHarmony(calmTestPalette(), HarmonyTriadic)
	if err != nil {
		t.Fatal(err)
	}
	anchor := mustLCH(t, got.Accent).H
	assertHarmonyHueNear(t, got.Selection, normalizeHue(anchor+120), 5)
	assertHarmonyHueNear(t, got.Muted, normalizeHue(anchor+240), 5)
}

func TestHarmonyANSIColorsRemainDistinct(t *testing.T) {
	for _, harmony := range []Harmony{HarmonyMonochromatic, HarmonyAnalogous, HarmonyComplementary, HarmonySplitComplementary, HarmonyTriadic} {
		t.Run(string(harmony), func(t *testing.T) {
			got, err := ApplyHarmony(calmTestPalette(), harmony)
			if err != nil {
				t.Fatal(err)
			}
			values := []string{got.Red, got.Orange, got.Yellow, got.Green, got.Cyan, got.Blue, got.Magenta, got.Brown}
			seen := map[string]struct{}{}
			for _, value := range values {
				if _, exists := seen[value]; exists {
					t.Fatalf("ANSI colors collapsed to identical color %s", value)
				}
				seen[value] = struct{}{}
			}
		})
	}
}
