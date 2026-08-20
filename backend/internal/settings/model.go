package settings

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/contrast"
	"github.com/prettyletto/omagen/backend/internal/palette"
)

const CurrentSchemaVersion = 1

type ColorTheorySettings struct {
	Harmony palette.Harmony `json:"harmony"`
}

type Settings struct {
	SchemaVersion int `json:"schema_version"`

	ColorTheory ColorTheorySettings `json:"color_theory"`
	Contrast    contrast.Targets    `json:"contrast"`
}

func (s Settings) Validate() error {
	if s.SchemaVersion != CurrentSchemaVersion {
		return fmt.Errorf(
			"unsupported settings schema version %d",
			s.SchemaVersion,
		)
	}

	if err := s.ColorTheory.Harmony.ValidateSupported(); err != nil {
		return fmt.Errorf("color theory: %w", err)
	}

	if err := s.Contrast.Validate(); err != nil {
		return fmt.Errorf("contrast: %w", err)
	}

	return nil
}
