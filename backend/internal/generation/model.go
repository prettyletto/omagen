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

type PaletteView struct {
	Mode              string `json:"mode"`
	Accent            string `json:"accent"`
	Selection         string `json:"selection"`
	Muted             string `json:"muted"`
	Background        string `json:"background"`
	DarkBackground    string `json:"dark_background"`
	DarkerBackground  string `json:"darker_background"`
	LighterBackground string `json:"lighter_background"`
	Foreground        string `json:"foreground"`
	DarkForeground    string `json:"dark_foreground"`
	LightForeground   string `json:"light_foreground"`
	BrightForeground  string `json:"bright_foreground"`
	Red               string `json:"red"`
	Yellow            string `json:"yellow"`
	Orange            string `json:"orange"`
	Green             string `json:"green"`
	Cyan              string `json:"cyan"`
	Blue              string `json:"blue"`
	Magenta           string `json:"magenta"`
	Brown             string `json:"brown"`
	BrightRed         string `json:"bright_red"`
	BrightYellow      string `json:"bright_yellow"`
	BrightGreen       string `json:"bright_green"`
	BrightCyan        string `json:"bright_cyan"`
	BrightBlue        string `json:"bright_blue"`
	BrightMagenta     string `json:"bright_magenta"`
}

type DescribedVariant struct {
	Variant Variant     `json:"variant"`
	Path    string      `json:"path"`
	Palette PaletteView `json:"palette"`
}
type DescribeResult struct {
	GenerationID string             `json:"generation_id"`
	Variants     []DescribedVariant `json:"variants"`
}
