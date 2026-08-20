package generation

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/settings"
)

type Variant string

const (
	Source   Variant = "source"
	Calm     Variant = "calm"
	Mute     Variant = "mute"
	Deep     Variant = "deep"
	Vibrant  Variant = "vibrant"
	Balanced Variant = "balanced"
)

var orderedVariants = [...]Variant{
	Source,
	Calm,
	Mute,
	Deep,
	Vibrant,
	Balanced,
}

func ParseVariant(value string) (Variant, error) {
	variant := Variant(value)
	switch variant {
	case Source, Calm, Mute, Deep, Vibrant, Balanced:
		return variant, nil
	default:
		return "", fmt.Errorf("unknown variant %q", value)
	}
}

type Request struct {
	SessionID   string
	SourceImage string
	Overrides   settings.Overrides
}

type VariantResult struct {
	Variant Variant `json:"variant"`
	Path    string  `json:"path"`
}

type Result struct {
	GenerationID string            `json:"generation_id"`
	Settings     settings.Settings `json:"settings"`
	Variants     []VariantResult   `json:"variants"`
}
