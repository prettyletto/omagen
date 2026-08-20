package settings

import "github.com/prettyletto/omagen/backend/internal/palette"

type ColorTheoryOverrides struct {
	Harmony *palette.Harmony `json:"harmony,omitempty"`
}

type Overrides struct {
	ColorTheory ColorTheoryOverrides `json:"color_theory,omitempty"`
}

func ApplyOverrides(base Settings, overrides Overrides) (Settings, error) {
	result := base
	if overrides.ColorTheory.Harmony != nil {
		result.ColorTheory.Harmony = *overrides.ColorTheory.Harmony
	}
	if err := result.Validate(); err != nil {
		return Settings{}, err
	}
	return result, nil
}
