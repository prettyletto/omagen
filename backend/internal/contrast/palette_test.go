package contrast

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

func TestEnforceDarkPalette(t *testing.T) {
	input := theme.Palette{
		Mode: "dark",

		Background:        "#202020",
		DarkBackground:    "#181818",
		DarkerBackground:  "#101010",
		LighterBackground: "#303030",

		Foreground:       "#555555",
		DarkForeground:   "#444444",
		LightForeground:  "#666666",
		BrightForeground: "#777777",

		Accent:    "#555555",
		Selection: "#555555",
		Muted:     "#454545",

		Red:     "#ff5555",
		Orange:  "#ff9955",
		Yellow:  "#ffff55",
		Green:   "#55ff55",
		Cyan:    "#55ffff",
		Blue:    "#5599ff",
		Magenta: "#ff55ff",
		Brown:   "#996644",

		BrightRed:     "#ff7777",
		BrightYellow:  "#ffff77",
		BrightGreen:   "#77ff77",
		BrightCyan:    "#77ffff",
		BrightBlue:    "#77aaff",
		BrightMagenta: "#ff77ff",
	}

	targets := Targets{
		PrimaryText:   4.5,
		BrightText:    7,
		SecondaryText: 3,
		UIElement:     3,
		SelectionText: 4.5,
	}
	result, err := Enforce(input, targets)
	if err != nil {
		t.Fatal(err)
	}

	assertMinimumRatio(t, result.Foreground, result.Background, targets.PrimaryText)
	assertMinimumRatio(t, result.BrightForeground, result.Background, targets.BrightText)
	assertMinimumRatio(t, result.DarkForeground, result.Background, targets.SecondaryText)
	assertMinimumRatio(t, result.Muted, result.Background, targets.SecondaryText)
	assertMinimumRatio(t, result.Accent, result.Background, targets.UIElement)
	assertMinimumRatio(t, result.Foreground, result.Selection, targets.SelectionText)
}

func assertMinimumRatio(t *testing.T, first, second string, minimum float64) {
	t.Helper()
	ratio, err := Ratio(first, second)
	if err != nil {
		t.Fatal(err)
	}
	if ratio+0.001 < minimum {
		t.Fatalf("%s against %s: ratio %.4f, want >= %.2f", first, second, ratio, minimum)
	}
}
