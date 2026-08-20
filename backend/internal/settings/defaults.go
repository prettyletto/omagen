package settings

import (
	"github.com/prettyletto/omagen/backend/internal/contrast"
	"github.com/prettyletto/omagen/backend/internal/palette"
)

func Defaults() Settings {
	return Settings{
		SchemaVersion: CurrentSchemaVersion,
		ColorTheory: ColorTheorySettings{
			Harmony: palette.HarmonyAuto,
		},
		Contrast: contrast.Targets{
			PrimaryText:   4.5,
			BrightText:    7.0,
			SecondaryText: 3.0,
			UIElement:     3.0,
			SelectionText: 4.5,
		},
	}
}
