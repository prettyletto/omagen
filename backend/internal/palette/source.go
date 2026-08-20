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
	if err := harmony.ValidateSupported(); err != nil {
		return theme.Palette{}, err
	}
	base := sourceClosest(colors)
	if harmony == HarmonyAuto {
		return base, nil
	}
	result, err := ApplyHarmony(base, harmony)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("apply %s harmony: %w", harmony, err)
	}
	return result, nil
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
	result := theme.Palette{}
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
	applyANSI(&result, colors, accent)
	return result
}

func sourceLight(colors []imageanalysis.RepresentativeColor, surface, accent colorspace.OKLCH) theme.Palette {
	foregroundSource := chooseForegroundSource(colors, "light")
	backgroundL := clampValue(surface.L, 0.90, 0.97)
	backgroundC := clampValue(surface.C*0.45, 0, 0.030)
	accentL := clampValue(accent.L, 0.43, 0.60)
	accentC := clampValue(accent.C, 0, 0.20)
	foregroundC := clampValue(foregroundSource.C*0.20, 0, 0.025)
	result := theme.Palette{}
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
	applyANSI(&result, colors, accent)
	return result
}
