package palette

import "testing"

func TestParseHarmony(t *testing.T) {
	tests := []struct {
		input string
		want  Harmony
	}{
		{input: "auto", want: HarmonyAuto},
		{input: "MONOCHROMATIC", want: HarmonyMonochromatic},
		{input: " analogous ", want: HarmonyAnalogous},
		{input: "complementary", want: HarmonyComplementary},
		{input: "split_complementary", want: HarmonySplitComplementary},
		{input: "triadic", want: HarmonyTriadic},
	}

	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			got, err := ParseHarmony(test.input)
			if err != nil {
				t.Fatal(err)
			}
			if got != test.want {
				t.Fatalf("got %q, want %q", got, test.want)
			}
		})
	}
}

func TestParseHarmonyRejectsUnknown(t *testing.T) {
	if _, err := ParseHarmony("whatever"); err == nil {
		t.Fatal("expected invalid harmony to fail")
	}
}
