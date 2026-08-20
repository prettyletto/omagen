package generation

import "github.com/prettyletto/omagen/backend/internal/theme"

func fixturePalette(
	variant Variant,
) theme.Palette {
	palette := theme.Palette{
		Mode: "dark",

		Accent:    "#7aa2f7",
		Selection: "#292e42",
		Muted:     "#414868",

		Background:        "#1a1b26",
		DarkBackground:    "#13141c",
		DarkerBackground:  "#0e0e14",
		LighterBackground: "#24283b",

		Foreground:       "#a9b1d6",
		DarkForeground:   "#565f89",
		LightForeground:  "#b4bee6",
		BrightForeground: "#c0caf5",

		Red:     "#f7768e",
		Yellow:  "#e0af68",
		Orange:  "#eb927b",
		Green:   "#9ece6a",
		Cyan:    "#449dab",
		Blue:    "#7aa2f7",
		Magenta: "#ad8ee6",
		Brown:   "#75493d",

		BrightRed:     "#ff7a93",
		BrightYellow:  "#ff9e64",
		BrightGreen:   "#b9f27c",
		BrightCyan:    "#0db9d7",
		BrightBlue:    "#7da6ff",
		BrightMagenta: "#bb9af7",
	}

	switch variant {
	case Source:
		// Base fixture.

	case Calm:
		palette.Accent = "#86a8c7"
		palette.Selection = "#30384a"
		palette.Muted = "#50596f"

	case Mute:
		palette.Accent = "#9298a8"
		palette.Selection = "#343741"
		palette.Muted = "#5b6070"

	case Deep:
		palette.Background = "#0b0c12"
		palette.DarkBackground = "#08090e"
		palette.DarkerBackground = "#05060a"
		palette.LighterBackground = "#151824"

	case Vibrant:
		palette.Accent = "#8ab4ff"
		palette.Red = "#ff6685"
		palette.Green = "#adeb75"
		palette.Cyan = "#38d7e8"
		palette.Blue = "#82aaff"
		palette.Magenta = "#c099ff"

	case Balanced:
		palette.Background = "#151722"
		palette.DarkBackground = "#101119"
		palette.DarkerBackground = "#0b0c11"
		palette.LighterBackground = "#222638"
		palette.Selection = "#30364d"
	}

	return palette
}
