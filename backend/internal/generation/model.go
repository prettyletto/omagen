package generation

import "github.com/prettyletto/omagen/backend/internal/settings"

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
