package contrast

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

func testTargets() Targets {
	return Targets{
		PrimaryText:   4.5,
		BrightText:    7.0,
		SecondaryText: 3.0,
		UIElement:     3.0,
		SelectionText: 4.5,
		ANSI:          3.0,
		BrightANSI:    4.5,
	}
}

func TestEnforceDarkPalette(t *testing.T) {
	input := theme.Palette{
		Mode:       "dark",
		Background: "#202020", DarkBackground: "#181818", DarkerBackground: "#101010", LighterBackground: "#303030",
		Foreground: "#555555", DarkForeground: "#444444", LightForeground: "#666666", BrightForeground: "#777777",
		Accent: "#555555", Selection: "#555555", Muted: "#454545",
		Red: "#553838", Orange: "#554238", Yellow: "#555138", Green: "#38553d", Cyan: "#385555", Blue: "#384255", Magenta: "#513855", Brown: "#4d4038",
		BrightRed: "#654545", BrightYellow: "#656045", BrightGreen: "#45654a", BrightCyan: "#456565", BrightBlue: "#455065", BrightMagenta: "#604565",
	}
	targets := testTargets()
	result, err := Enforce(input, targets)
	if err != nil {
		t.Fatal(err)
	}

	assertMinimumRatio(t, result.Foreground, result.Background, targets.PrimaryText)
	assertMinimumRatio(t, result.LightForeground, result.Background, targets.PrimaryText)
	assertMinimumRatio(t, result.BrightForeground, result.Background, targets.BrightText)
	assertMinimumRatio(t, result.DarkForeground, result.Background, targets.SecondaryText)
	assertMinimumRatio(t, result.Muted, result.Background, targets.SecondaryText)
	assertMinimumRatio(t, result.Accent, result.Background, targets.UIElement)
	assertMinimumRatio(t, result.BrightForeground, result.Selection, targets.SelectionText)

	for _, color := range []string{result.Red, result.Orange, result.Yellow, result.Green, result.Cyan, result.Blue, result.Magenta, result.Brown} {
		assertMinimumRatio(t, color, result.Background, targets.ANSI)
	}
	for _, color := range []string{result.BrightRed, result.BrightYellow, result.BrightGreen, result.BrightCyan, result.BrightBlue, result.BrightMagenta} {
		assertMinimumRatio(t, color, result.Background, targets.BrightANSI)
	}
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
