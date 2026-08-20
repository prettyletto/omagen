package generation

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/palette"
)

type ColorTheoryOptions struct {
	Harmony palette.Harmony `json:"harmony"`
}

type Options struct {
	ColorTheory ColorTheoryOptions `json:"color_theory"`
}

func DefaultOptions() Options {
	return Options{
		ColorTheory: ColorTheoryOptions{
			Harmony: palette.HarmonyAuto,
		},
	}
}

func (o Options) Normalize() Options {
	if o.ColorTheory.Harmony == "" {
		o.ColorTheory.Harmony = palette.HarmonyAuto
	}
	return o
}

func (o Options) Validate() error {
	if err := o.ColorTheory.Harmony.Validate(); err != nil {
		return fmt.Errorf("color theory: %w", err)
	}
	return nil
}
