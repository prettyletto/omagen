package palette

import (
	"fmt"
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

const harmonyAnchorChromaThreshold = 0.018
const defaultHarmonyHue = 250.0

type harmonyDefinition struct {
	offsets                                    []float64
	accentOffset, selectionOffset, mutedOffset float64
}

type ansiIdentity struct {
	chromaScale    float64
	lightnessShift float64
}

var ansiIdentities = map[string]ansiIdentity{
	"red": {1.10, 0.000}, "orange": {0.96, 0.018}, "yellow": {0.82, 0.036}, "green": {0.94, 0.012},
	"cyan": {0.88, 0.028}, "blue": {1.04, 0.006}, "magenta": {1.14, 0.020}, "brown": {0.68, 0.000},
}

func harmonyDefinitionFor(h Harmony) (harmonyDefinition, error) {
	switch h {
	case HarmonyMonochromatic:
		return harmonyDefinition{offsets: []float64{0}}, nil
	case HarmonyAnalogous:
		return harmonyDefinition{offsets: []float64{-30, 0, 30}, selectionOffset: 30, mutedOffset: -30}, nil
	case HarmonyComplementary:
		return harmonyDefinition{offsets: []float64{0, 180}, selectionOffset: 180, mutedOffset: 180}, nil
	case HarmonySplitComplementary:
		return harmonyDefinition{offsets: []float64{0, 150, 210}, selectionOffset: 150, mutedOffset: 210}, nil
	case HarmonyTriadic:
		return harmonyDefinition{offsets: []float64{0, 120, 240}, selectionOffset: 120, mutedOffset: 240}, nil
	default:
		return harmonyDefinition{}, fmt.Errorf("no harmony definition for %q", h)
	}
}

func ApplyHarmony(base theme.Palette, harmony Harmony) (theme.Palette, error) {
	if err := harmony.ValidateSupported(); err != nil {
		return theme.Palette{}, err
	}
	if harmony == HarmonyAuto {
		return base, nil
	}
	if err := base.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf("validate harmony base palette: %w", err)
	}
	definition, err := harmonyDefinitionFor(harmony)
	if err != nil {
		return theme.Palette{}, err
	}
	anchor, err := harmonyAnchorHue(base)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("resolve harmony anchor: %w", err)
	}
	result := base
	fixed := []struct {
		source string
		target *string
		floor  float64
	}{
		{base.Background, &result.Background, 0}, {base.DarkBackground, &result.DarkBackground, 0}, {base.DarkerBackground, &result.DarkerBackground, 0}, {base.LighterBackground, &result.LighterBackground, 0},
		{base.Accent, &result.Accent, harmonyAccentFloor(base.Mode)}, {base.Selection, &result.Selection, harmonySelectionFloor(base.Mode)}, {base.Muted, &result.Muted, harmonyMutedFloor(base.Mode)},
	}
	semanticOffsets := []float64{definition.accentOffset, definition.selectionOffset, definition.mutedOffset}
	for index, item := range fixed {
		hue := anchor
		if index >= 4 {
			hue += semanticOffsets[index-4]
		}
		value, err := harmonizeFixedHue(item.source, hue, item.floor)
		if err != nil {
			return theme.Palette{}, err
		}
		*item.target = value
	}
	normal := []struct {
		name, source string
		target       *string
		identity     ansiIdentity
	}{
		{"red", base.Red, &result.Red, ansiIdentities["red"]}, {"orange", base.Orange, &result.Orange, ansiIdentities["orange"]}, {"yellow", base.Yellow, &result.Yellow, ansiIdentities["yellow"]}, {"green", base.Green, &result.Green, ansiIdentities["green"]}, {"cyan", base.Cyan, &result.Cyan, ansiIdentities["cyan"]}, {"blue", base.Blue, &result.Blue, ansiIdentities["blue"]}, {"magenta", base.Magenta, &result.Magenta, ansiIdentities["magenta"]}, {"brown", base.Brown, &result.Brown, ansiIdentities["brown"]},
	}
	for _, item := range normal {
		value, err := harmonizeToNearestSlot(item.source, anchor, definition, harmonyANSIFloor(base.Mode), base.Mode, item.identity, false)
		if err != nil {
			return theme.Palette{}, fmt.Errorf("harmonize %s: %w", item.name, err)
		}
		*item.target = value
	}
	bright := []struct {
		name, source string
		target       *string
		identity     ansiIdentity
	}{
		{"bright_red", base.BrightRed, &result.BrightRed, ansiIdentities["red"]}, {"bright_yellow", base.BrightYellow, &result.BrightYellow, ansiIdentities["yellow"]}, {"bright_green", base.BrightGreen, &result.BrightGreen, ansiIdentities["green"]}, {"bright_cyan", base.BrightCyan, &result.BrightCyan, ansiIdentities["cyan"]}, {"bright_blue", base.BrightBlue, &result.BrightBlue, ansiIdentities["blue"]}, {"bright_magenta", base.BrightMagenta, &result.BrightMagenta, ansiIdentities["magenta"]},
	}
	for _, item := range bright {
		value, err := harmonizeToNearestSlot(item.source, anchor, definition, harmonyBrightANSIFloor(base.Mode), base.Mode, item.identity, true)
		if err != nil {
			return theme.Palette{}, fmt.Errorf("harmonize %s: %w", item.name, err)
		}
		*item.target = value
	}
	if err := result.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf("validate harmonized palette: %w", err)
	}
	return result, nil
}

func harmonyAnchorHue(p theme.Palette) (float64, error) {
	accent, err := colorspace.OKLCHFromHex(p.Accent)
	if err != nil {
		return 0, err
	}
	if accent.C >= harmonyAnchorChromaThreshold {
		return normalizeHue(accent.H), nil
	}
	background, err := colorspace.OKLCHFromHex(p.Background)
	if err != nil {
		return 0, err
	}
	if background.C >= surfaceHueThreshold {
		return normalizeHue(background.H), nil
	}
	return defaultHarmonyHue, nil
}

func harmonizeFixedHue(value string, hue, floor float64) (string, error) {
	lch, err := colorspace.OKLCHFromHex(value)
	if err != nil {
		return "", err
	}
	lch.H = normalizeHue(hue)
	if lch.C < floor {
		lch.C = floor
	}
	return colorspace.HexFromOKLCH(lch), nil
}

func harmonizeToNearestSlot(value string, anchor float64, definition harmonyDefinition, floor float64, mode string, identity ansiIdentity, bright bool) (string, error) {
	lch, err := colorspace.OKLCHFromHex(value)
	if err != nil {
		return "", err
	}
	lch.H = nearestHarmonyHue(lch.H, anchor, definition.offsets)
	if lch.C < floor {
		lch.C = floor
	}
	lch.C *= identity.chromaScale
	shift := identity.lightnessShift
	if bright {
		shift *= 0.5
	}
	if mode == "dark" {
		lch.L += shift
	} else {
		lch.L -= shift
	}
	lch.L = clampValue(lch.L, 0, 1)
	return colorspace.HexFromOKLCH(lch), nil
}

func nearestHarmonyHue(original, anchor float64, offsets []float64) float64 {
	best := normalizeHue(anchor + offsets[0])
	distance := hueDistance(original, best)
	for _, offset := range offsets[1:] {
		candidate := normalizeHue(anchor + offset)
		if d := hueDistance(original, candidate); d < distance {
			best, distance = candidate, d
		}
	}
	return best
}

func normalizeHue(h float64) float64 {
	h = math.Mod(h, 360)
	if h < 0 {
		h += 360
	}
	return h
}
func harmonyAccentFloor(mode string) float64 {
	if mode == "light" {
		return 0.095
	}
	return 0.11
}
func harmonySelectionFloor(mode string) float64 {
	if mode == "light" {
		return 0.045
	}
	return 0.055
}

func harmonyMutedFloor(mode string) float64 {
	if mode == "light" {
		return 0.022
	}
	return 0.028
}
func harmonyANSIFloor(mode string) float64 {
	if mode == "light" {
		return 0.090
	}
	return 0.105
}
func harmonyBrightANSIFloor(mode string) float64 {
	if mode == "light" {
		return 0.10
	}
	return 0.115
}
