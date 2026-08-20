package palette

import (
	"fmt"

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
	mode := "dark"
	if averageLightness >= lightModeThreshold {
		mode = "light"
	}
	roles := selectSourceRoles(colors, mode)
	if mode == "light" {
		return sourceLight(colors, roles)
	}
	return sourceDark(colors, roles)
}

func sourceDark(colors []imageanalysis.RepresentativeColor, roles sourceRoles) theme.Palette {
	surface, foreground, accent, selection, muted := roles.Surface, roles.Foreground, roles.Accent, roles.Selection, roles.Muted
	backgroundL := clampValue(surface.L, 0.11, 0.24)
	backgroundC := clampValue(surface.C, 0, 0.055)
	accentL := clampValue(accent.L, 0.58, 0.75)
	accentC := clampValue(accent.C, 0, 0.22)
	foregroundC := clampValue(foreground.C*0.45, 0, 0.075)
	selectionC := clampValue(selection.C*0.55, 0.025, 0.11)
	mutedC := clampValue(muted.C*0.35, 0, 0.050)
	result := theme.Palette{}
	result.Mode = "dark"
	result.Background = semanticColor(backgroundL, backgroundC, surface.H)
	result.DarkBackground = semanticColor(backgroundL-0.035, backgroundC*0.85, surface.H)
	result.DarkerBackground = semanticColor(backgroundL-0.065, backgroundC*0.70, surface.H)
	result.LighterBackground = semanticColor(backgroundL+0.070, backgroundC*1.10, surface.H)
	result.Foreground = semanticColor(0.88, foregroundC, foreground.H)
	result.DarkForeground = semanticColor(0.58, foregroundC*0.85, foreground.H)
	result.LightForeground = semanticColor(0.94, foregroundC*0.70, foreground.H)
	result.BrightForeground = semanticColor(0.98, foregroundC*0.45, foreground.H)
	result.Accent = semanticColor(accentL, accentC, accent.H)
	result.Selection = semanticColor(backgroundL+0.16, selectionC, selection.H)
	result.Muted = semanticColor(backgroundL+0.22, mutedC, muted.H)
	applyANSI(&result, colors, accent)
	return result
}

func sourceLight(colors []imageanalysis.RepresentativeColor, roles sourceRoles) theme.Palette {
	surface, foreground, accent, selection, muted := roles.Surface, roles.Foreground, roles.Accent, roles.Selection, roles.Muted
	backgroundL := clampValue(surface.L, 0.90, 0.97)
	backgroundC := clampValue(surface.C*0.45, 0, 0.030)
	accentL := clampValue(accent.L, 0.43, 0.60)
	accentC := clampValue(accent.C, 0, 0.20)
	foregroundC := clampValue(foreground.C*0.40, 0, 0.065)
	selectionC := clampValue(selection.C*0.50, 0.020, 0.095)
	mutedC := clampValue(muted.C*0.30, 0, 0.045)
	result := theme.Palette{}
	result.Mode = "light"
	result.Background = semanticColor(backgroundL, backgroundC, surface.H)
	result.DarkBackground = semanticColor(backgroundL-0.08, backgroundC*1.10, surface.H)
	result.DarkerBackground = semanticColor(backgroundL-0.13, backgroundC*1.15, surface.H)
	result.LighterBackground = semanticColor(backgroundL+0.025, backgroundC*0.70, surface.H)
	result.Foreground = semanticColor(0.22, foregroundC, foreground.H)
	result.DarkForeground = semanticColor(0.36, foregroundC*0.85, foreground.H)
	result.LightForeground = semanticColor(0.15, foregroundC*0.70, foreground.H)
	result.BrightForeground = semanticColor(0.08, foregroundC*0.45, foreground.H)
	result.Accent = semanticColor(accentL, accentC, accent.H)
	result.Selection = semanticColor(0.82, selectionC, selection.H)
	result.Muted = semanticColor(0.58, mutedC, muted.H)
	applyANSI(&result, colors, accent)
	return result
}
