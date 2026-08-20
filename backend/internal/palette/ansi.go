package palette

import (
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

const (
	ansiSourceChromaThreshold = 0.035
	ansiMaximumHueDistance    = 35.0
)

type ansiFamily struct{ targetHue float64 }

var ansiFamilies = struct {
	Red, Orange, Yellow, Green, Cyan, Blue, Magenta, Brown ansiFamily
}{
	Red: ansiFamily{25}, Orange: ansiFamily{55}, Yellow: ansiFamily{95}, Green: ansiFamily{145},
	Cyan: ansiFamily{195}, Blue: ansiFamily{255}, Magenta: ansiFamily{320}, Brown: ansiFamily{55},
}

func applyANSI(result *theme.Palette, colors []imageanalysis.RepresentativeColor, accent colorspace.OKLCH) {
	red := resolveANSIFamily(colors, ansiFamilies.Red, accent, result.Mode)
	orange := resolveANSIFamily(colors, ansiFamilies.Orange, accent, result.Mode)
	yellow := resolveANSIFamily(colors, ansiFamilies.Yellow, accent, result.Mode)
	green := resolveANSIFamily(colors, ansiFamilies.Green, accent, result.Mode)
	cyan := resolveANSIFamily(colors, ansiFamilies.Cyan, accent, result.Mode)
	blue := resolveANSIFamily(colors, ansiFamilies.Blue, accent, result.Mode)
	magenta := resolveANSIFamily(colors, ansiFamilies.Magenta, accent, result.Mode)
	brown := resolveBrown(colors, accent, result.Mode)

	result.Red = semanticColor(red.L, red.C, red.H)
	result.Orange = semanticColor(orange.L, orange.C, orange.H)
	result.Yellow = semanticColor(yellow.L, yellow.C, yellow.H)
	result.Green = semanticColor(green.L, green.C, green.H)
	result.Cyan = semanticColor(cyan.L, cyan.C, cyan.H)
	result.Blue = semanticColor(blue.L, blue.C, blue.H)
	result.Magenta = semanticColor(magenta.L, magenta.C, magenta.H)
	result.Brown = semanticColor(brown.L, brown.C, brown.H)

	brightRed := brightenANSI(red, result.Mode)
	brightYellow := brightenANSI(yellow, result.Mode)
	brightGreen := brightenANSI(green, result.Mode)
	brightCyan := brightenANSI(cyan, result.Mode)
	brightBlue := brightenANSI(blue, result.Mode)
	brightMagenta := brightenANSI(magenta, result.Mode)

	result.BrightRed = semanticColor(brightRed.L, brightRed.C, brightRed.H)
	result.BrightYellow = semanticColor(brightYellow.L, brightYellow.C, brightYellow.H)
	result.BrightGreen = semanticColor(brightGreen.L, brightGreen.C, brightGreen.H)
	result.BrightCyan = semanticColor(brightCyan.L, brightCyan.C, brightCyan.H)
	result.BrightBlue = semanticColor(brightBlue.L, brightBlue.C, brightBlue.H)
	result.BrightMagenta = semanticColor(brightMagenta.L, brightMagenta.C, brightMagenta.H)
}

func resolveANSIFamily(colors []imageanalysis.RepresentativeColor, family ansiFamily, accent colorspace.OKLCH, mode string) colorspace.OKLCH {
	if candidate, ok := findSourceHue(colors, family.targetHue); ok {
		return normalizeANSI(candidate, mode)
	}
	return synthesizeANSI(family.targetHue, accent, mode)
}

func findSourceHue(colors []imageanalysis.RepresentativeColor, targetHue float64) (colorspace.OKLCH, bool) {
	bestScore := math.Inf(1)
	var best colorspace.OKLCH
	found := false
	for _, candidate := range colors {
		lch := candidate.LCH
		if lch.C < ansiSourceChromaThreshold {
			continue
		}
		distance := hueDistance(lch.H, targetHue)
		if distance > ansiMaximumHueDistance {
			continue
		}
		score := distance - math.Sqrt(candidate.Coverage)*5.0
		if score < bestScore {
			bestScore, best, found = score, lch, true
		}
	}
	return best, found
}

func normalizeANSI(color colorspace.OKLCH, mode string) colorspace.OKLCH {
	if mode == "light" {
		color.L = clampValue(color.L, 0.42, 0.62)
	} else {
		color.L = clampValue(color.L, 0.56, 0.76)
	}
	color.C = clampValue(color.C, 0.07, 0.20)
	return color
}

func synthesizeANSI(targetHue float64, accent colorspace.OKLCH, mode string) colorspace.OKLCH {
	lightness := 0.67
	if mode == "light" {
		lightness = 0.52
	}
	return colorspace.OKLCH{L: lightness, C: clampValue(accent.C*0.90, 0.10, 0.16), H: targetHue}
}

func resolveBrown(colors []imageanalysis.RepresentativeColor, accent colorspace.OKLCH, mode string) colorspace.OKLCH {
	if candidate, ok := findSourceHue(colors, ansiFamilies.Brown.targetHue); ok {
		candidate.C *= 0.55
		if mode == "light" {
			candidate.L = clampValue(candidate.L, 0.35, 0.50)
		} else {
			candidate.L = clampValue(candidate.L, 0.40, 0.55)
		}
		return candidate
	}
	lightness := 0.48
	if mode == "light" {
		lightness = 0.42
	}
	return colorspace.OKLCH{L: lightness, C: clampValue(accent.C*0.45, 0.055, 0.10), H: ansiFamilies.Brown.targetHue}
}

func brightenANSI(color colorspace.OKLCH, mode string) colorspace.OKLCH {
	if mode == "light" {
		color.L = clampValue(color.L+0.07, 0.50, 0.68)
	} else {
		color.L = clampValue(color.L+0.09, 0.65, 0.84)
	}
	color.C = clampValue(color.C*1.08, 0.08, 0.22)
	return color
}

func hueDistance(a, b float64) float64 {
	distance := math.Abs(a - b)
	if distance > 180 {
		distance = 360 - distance
	}
	return distance
}
