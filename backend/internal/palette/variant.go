package palette

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type colorTransform struct {
	chromaScale     float64
	chromaTarget    float64
	chromaBlend     float64
	lightnessSpread float64
}

type variantProfile struct {
	dark  modeProfile
	light modeProfile
}

type modeProfile struct {
	backgroundTargetL float64
	backgroundBlend   float64
	surface           colorTransform
	accent            colorTransform
	selection         colorTransform
	muted             colorTransform
	ansi              colorTransform
	brightANSI        colorTransform
}

func applyVariantProfile(base theme.Palette, profile variantProfile) (theme.Palette, error) {
	if err := base.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf("validate base palette: %w", err)
	}
	activeProfile, err := profileForMode(profile, base.Mode)
	if err != nil {
		return theme.Palette{}, err
	}
	sourceBackground, err := colorspace.OKLCHFromHex(base.Background)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("parse background: %w", err)
	}
	targetBackgroundL := targetBackgroundLightness(
		sourceBackground.L,
		activeProfile,
	)

	result := base
	mainBackground := sourceBackground
	mainBackground.C = transformChroma(mainBackground.C, activeProfile.surface)
	mainBackground.L = targetBackgroundL
	result.Background = colorspace.HexFromOKLCH(mainBackground)

	type transformation struct {
		name      string
		target    *string
		transform colorTransform
	}
	transformations := []transformation{
		{name: "dark_background", target: &result.DarkBackground, transform: activeProfile.surface},
		{name: "darker_background", target: &result.DarkerBackground, transform: activeProfile.surface},
		{name: "lighter_background", target: &result.LighterBackground, transform: activeProfile.surface},
		{name: "accent", target: &result.Accent, transform: activeProfile.accent},
		{name: "selection", target: &result.Selection, transform: activeProfile.selection},
		{name: "muted", target: &result.Muted, transform: activeProfile.muted},
		{name: "red", target: &result.Red, transform: activeProfile.ansi},
		{name: "orange", target: &result.Orange, transform: activeProfile.ansi},
		{name: "yellow", target: &result.Yellow, transform: activeProfile.ansi},
		{name: "green", target: &result.Green, transform: activeProfile.ansi},
		{name: "cyan", target: &result.Cyan, transform: activeProfile.ansi},
		{name: "blue", target: &result.Blue, transform: activeProfile.ansi},
		{name: "magenta", target: &result.Magenta, transform: activeProfile.ansi},
		{name: "brown", target: &result.Brown, transform: activeProfile.ansi},
		{name: "bright_red", target: &result.BrightRed, transform: activeProfile.brightANSI},
		{name: "bright_yellow", target: &result.BrightYellow, transform: activeProfile.brightANSI},
		{name: "bright_green", target: &result.BrightGreen, transform: activeProfile.brightANSI},
		{name: "bright_cyan", target: &result.BrightCyan, transform: activeProfile.brightANSI},
		{name: "bright_blue", target: &result.BrightBlue, transform: activeProfile.brightANSI},
		{name: "bright_magenta", target: &result.BrightMagenta, transform: activeProfile.brightANSI},
	}

	for _, item := range transformations {
		transformed, err := transformSemanticColor(*item.target, sourceBackground.L, targetBackgroundL, item.transform)
		if err != nil {
			return theme.Palette{}, fmt.Errorf("transform %s: %w", item.name, err)
		}
		*item.target = transformed
	}
	if err := result.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf("validate transformed palette: %w", err)
	}
	return result, nil
}

func transformSemanticColor(value string, sourceBackgroundL, targetBackgroundL float64, transform colorTransform) (string, error) {
	if transform.chromaScale < 0 {
		return "", fmt.Errorf("chroma scale must be >= 0")
	}
	if transform.lightnessSpread < 0 {
		return "", fmt.Errorf("lightness spread must be >= 0")
	}
	lch, err := colorspace.OKLCHFromHex(value)
	if err != nil {
		return "", err
	}
	lch.C = transformChroma(lch.C, transform)
	lch.L = clampValue(targetBackgroundL+(lch.L-sourceBackgroundL)*transform.lightnessSpread, 0, 1)
	lch.C = max(0, lch.C)
	return colorspace.HexFromOKLCH(lch), nil
}

func transformChroma(current float64, transform colorTransform) float64 {
	result := current * transform.chromaScale
	blend := clampValue(transform.chromaBlend, 0, 1)
	if blend > 0 {
		result += (transform.chromaTarget - result) * blend
	}
	return max(0, result)
}

func profileForMode(profile variantProfile, mode string) (modeProfile, error) {
	switch mode {
	case "dark":
		return profile.dark, nil
	case "light":
		return profile.light, nil
	default:
		return modeProfile{}, fmt.Errorf("unsupported palette mode %q", mode)
	}
}

func targetBackgroundLightness(current float64, profile modeProfile) float64 {
	strength := clampValue(profile.backgroundBlend, 0, 1)
	return clampValue(current+(profile.backgroundTargetL-current)*strength, 0, 1)
}
