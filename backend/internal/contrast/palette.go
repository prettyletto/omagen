package contrast

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

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

	var err error

	palette.Foreground, err =
		adjustLightness(
			palette.Foreground,
			palette.Background,
			targets.PrimaryText,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"foreground contrast: %w",
			err,
		)
	}

	palette.LightForeground, err =
		adjustLightness(
			palette.LightForeground,
			palette.Background,
			targets.PrimaryText,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"light_foreground contrast: %w",
			err,
		)
	}

	palette.BrightForeground, err =
		adjustLightness(
			palette.BrightForeground,
			palette.Background,
			targets.BrightText,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"bright_foreground contrast: %w",
			err,
		)
	}

	palette.DarkForeground, err =
		adjustLightness(
			palette.DarkForeground,
			palette.Background,
			targets.SecondaryText,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"dark_foreground contrast: %w",
			err,
		)
	}

	palette.Muted, err =
		adjustLightness(
			palette.Muted,
			palette.Background,
			targets.SecondaryText,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"muted contrast: %w",
			err,
		)
	}

	palette.Accent, err =
		adjustLightness(
			palette.Accent,
			palette.Background,
			targets.UIElement,
			textDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"accent contrast: %w",
			err,
		)
	}

	// Selection behaves like another surface.
	//
	// In dark mode it should remain on the dark side of the
	// foreground. In light mode it should remain on the
	// light side.
	palette.Selection, err =
		adjustLightness(
			palette.Selection,
			palette.Foreground,
			targets.SelectionText,
			surfaceDirection,
		)

	if err != nil {
		return theme.Palette{}, fmt.Errorf(
			"selection contrast: %w",
			err,
		)
	}

	if err := palette.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf(
			"validate palette after contrast: %w",
			err,
		)
	}

	return palette, nil
}
