package palette

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

func Source(colors []imageanalysis.RepresentativeColor, harmony Harmony) (theme.Palette, error) {
	if err := validateRepresentatives(colors); err != nil {
		return theme.Palette{}, err
	}
	switch harmony {
	case HarmonyAuto:
		return sourceClosest(colors), nil
	case HarmonyMonochromatic, HarmonyAnalogous, HarmonyComplementary, HarmonySplitComplementary, HarmonyTriadic:
		return theme.Palette{}, fmt.Errorf("color harmony %q is not implemented yet", harmony)
	default:
		return theme.Palette{}, fmt.Errorf("unsupported color harmony %q", harmony)
	}
}

func sourceClosest(colors []imageanalysis.RepresentativeColor) theme.Palette {
	averageLightness := weightedLightness(colors)
	surface := chooseSurface(colors)
	accent := chooseAccent(colors)
	if averageLightness >= lightModeThreshold {
		return sourceLight(colors, surface, accent)
	}
	return sourceDark(colors, surface, accent)
}

func sourceDark(colors []imageanalysis.RepresentativeColor, surface, accent colorspace.OKLCH) theme.Palette {
	foregroundSource := chooseForegroundSource(colors, "dark")
	backgroundL := clampValue(surface.L, 0.11, 0.24)
	backgroundC := clampValue(surface.C, 0, 0.055)
	accentL := clampValue(accent.L, 0.58, 0.75)
	accentC := clampValue(accent.C, 0, 0.22)
	foregroundC := clampValue(foregroundSource.C*0.20, 0, 0.025)
	result := temporaryANSI()
	result.Mode = "dark"
	result.Background = semanticColor(backgroundL, backgroundC, surface.H)
	result.DarkBackground = semanticColor(backgroundL-0.035, backgroundC*0.85, surface.H)
	result.DarkerBackground = semanticColor(backgroundL-0.065, backgroundC*0.70, surface.H)
	result.LighterBackground = semanticColor(backgroundL+0.070, backgroundC*1.10, surface.H)
	result.Foreground = semanticColor(0.88, foregroundC, foregroundSource.H)
	result.DarkForeground = semanticColor(0.58, foregroundC*1.15, foregroundSource.H)
	result.LightForeground = semanticColor(0.94, foregroundC*0.75, foregroundSource.H)
	result.BrightForeground = semanticColor(0.98, foregroundC*0.45, foregroundSource.H)
	result.Accent = semanticColor(accentL, accentC, accent.H)
	result.Selection = semanticColor(backgroundL+0.15, accentC*0.42, accent.H)
	result.Muted = semanticColor(backgroundL+0.22, clampValue(backgroundC*0.70, 0, 0.040), surface.H)
	return result
}

func sourceLight(colors []imageanalysis.RepresentativeColor, surface, accent colorspace.OKLCH) theme.Palette {
	foregroundSource := chooseForegroundSource(colors, "light")
	backgroundL := clampValue(surface.L, 0.90, 0.97)
	backgroundC := clampValue(surface.C*0.45, 0, 0.030)
	accentL := clampValue(accent.L, 0.43, 0.60)
	accentC := clampValue(accent.C, 0, 0.20)
	foregroundC := clampValue(foregroundSource.C*0.20, 0, 0.025)
	result := temporaryANSI()
	result.Mode = "light"
	result.Background = semanticColor(backgroundL, backgroundC, surface.H)
	result.DarkBackground = semanticColor(backgroundL-0.08, backgroundC*1.10, surface.H)
	result.DarkerBackground = semanticColor(backgroundL-0.13, backgroundC*1.15, surface.H)
	result.LighterBackground = semanticColor(backgroundL+0.025, backgroundC*0.70, surface.H)
	result.Foreground = semanticColor(0.22, foregroundC, foregroundSource.H)
	result.DarkForeground = semanticColor(0.36, foregroundC*1.10, foregroundSource.H)
	result.LightForeground = semanticColor(0.15, foregroundC*0.75, foregroundSource.H)
	result.BrightForeground = semanticColor(0.08, foregroundC*0.45, foregroundSource.H)
	result.Accent = semanticColor(accentL, accentC, accent.H)
	result.Selection = semanticColor(0.82, accentC*0.32, accent.H)
	result.Muted = semanticColor(0.58, clampValue(backgroundC*0.75, 0, 0.035), surface.H)
	return result
}

func temporaryANSI() theme.Palette {
	return theme.Palette{
		Red: "#f7768e", Yellow: "#e0af68", Orange: "#eb927b", Green: "#9ece6a", Cyan: "#449dab", Blue: "#7aa2f7", Magenta: "#ad8ee6", Brown: "#75493d",
		BrightRed: "#ff7a93", BrightYellow: "#ff9e64", BrightGreen: "#b9f27c", BrightCyan: "#0db9d7", BrightBlue: "#7da6ff", BrightMagenta: "#bb9af7",
	}
}
