package contrast

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

type backgroundRule struct {
	name   string
	color  *string
	target float64
}

func Enforce(
	palette theme.Palette,
	targets Targets,
) (theme.Palette, error) {
	if err := targets.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf(
			"validate contrast targets: %w",
			err,
		)
	}

	if err := palette.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf(
			"validate palette before contrast: %w",
			err,
		)
	}

	var textDirection direction
	var surfaceDirection direction

	switch palette.Mode {
	case "dark":
		textDirection = lighter
		surfaceDirection = darker

	case "light":
		textDirection = darker
		surfaceDirection = lighter

	default:
		return theme.Palette{}, fmt.Errorf(
			"unsupported palette mode %q",
			palette.Mode,
		)
	}

	rules := []backgroundRule{
		{name: "foreground", color: &palette.Foreground, target: targets.PrimaryText},
		{name: "light_foreground", color: &palette.LightForeground, target: targets.PrimaryText},
		{name: "bright_foreground", color: &palette.BrightForeground, target: targets.BrightText},
		{name: "dark_foreground", color: &palette.DarkForeground, target: targets.SecondaryText},
		{name: "muted", color: &palette.Muted, target: targets.SecondaryText},
		{name: "accent", color: &palette.Accent, target: targets.UIElement},
		{name: "red", color: &palette.Red, target: targets.ANSI},
		{name: "orange", color: &palette.Orange, target: targets.ANSI},
		{name: "yellow", color: &palette.Yellow, target: targets.ANSI},
		{name: "green", color: &palette.Green, target: targets.ANSI},
		{name: "cyan", color: &palette.Cyan, target: targets.ANSI},
		{name: "blue", color: &palette.Blue, target: targets.ANSI},
		{name: "magenta", color: &palette.Magenta, target: targets.ANSI},
		{name: "brown", color: &palette.Brown, target: targets.ANSI},
		{name: "bright_red", color: &palette.BrightRed, target: targets.BrightANSI},
		{name: "bright_yellow", color: &palette.BrightYellow, target: targets.BrightANSI},
		{name: "bright_green", color: &palette.BrightGreen, target: targets.BrightANSI},
		{name: "bright_cyan", color: &palette.BrightCyan, target: targets.BrightANSI},
		{name: "bright_blue", color: &palette.BrightBlue, target: targets.BrightANSI},
		{name: "bright_magenta", color: &palette.BrightMagenta, target: targets.BrightANSI},
	}

	for _, rule := range rules {
		adjusted, err := adjustLightness(
			*rule.color,
			palette.Background,
			rule.target,
			textDirection,
		)
		if err != nil {
			return theme.Palette{}, fmt.Errorf(
				"%s contrast: %w",
				rule.name,
				err,
			)
		}
		*rule.color = adjusted
	}

	// Quattro renders bright_foreground on top of selection.
	selection, err := adjustLightness(
		palette.Selection,
		palette.BrightForeground,
		targets.SelectionText,
		surfaceDirection,
	)
	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"selection contrast: %w",
			err,
		)
	}
	palette.Selection = selection

	if err := palette.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf(
			"validate palette after contrast: %w",
			err,
		)
	}

	return palette, nil
}
