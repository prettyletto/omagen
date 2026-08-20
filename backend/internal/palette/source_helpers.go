package palette

import (
	"fmt"
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

const (
	chromaticThreshold = 0.025
	lightModeThreshold = 0.68
)

func validateRepresentatives(colors []imageanalysis.RepresentativeColor) error {
	if len(colors) == 0 {
		return fmt.Errorf("source palette requires representative colors")
	}
	totalCoverage := 0.0
	for _, color := range colors {
		if color.Coverage < 0 {
			return fmt.Errorf("representative has negative coverage")
		}
		totalCoverage += color.Coverage
	}
	if totalCoverage <= 0 {
		return fmt.Errorf("representatives have no coverage")
	}
	return nil
}

func weightedLightness(colors []imageanalysis.RepresentativeColor) float64 {
	total, weight := 0.0, 0.0
	for _, color := range colors {
		total += color.LCH.L * color.Coverage
		weight += color.Coverage
	}
	return total / weight
}

func chooseSurface(colors []imageanalysis.RepresentativeColor) colorspace.OKLCH {
	dominant := colors[0].LCH
	if dominant.C >= chromaticThreshold {
		return dominant
	}
	for _, candidate := range colors[1:] {
		if candidate.LCH.C < chromaticThreshold || candidate.Coverage < 0.10 {
			continue
		}
		return colorspace.OKLCH{L: dominant.L, C: math.Min(candidate.LCH.C*0.25, 0.035), H: candidate.LCH.H}
	}
	return colorspace.OKLCH{L: dominant.L, C: 0, H: 0}
}

func chooseAccent(colors []imageanalysis.RepresentativeColor) colorspace.OKLCH {
	var best colorspace.OKLCH
	bestScore := -1.0
	for _, candidate := range colors {
		lch := candidate.LCH
		if lch.C < chromaticThreshold {
			continue
		}
		coverageWeight := 0.30 + math.Sqrt(candidate.Coverage)
		lightnessDistance := math.Abs(lch.L - 0.62)
		lightnessFitness := 1.0 - math.Min(1, lightnessDistance/0.62)
		score := lch.C * coverageWeight * (0.65 + 0.35*lightnessFitness)
		if score > bestScore {
			best, bestScore = lch, score
		}
	}
	if bestScore >= 0 {
		return best
	}
	return colorspace.OKLCH{L: 0.62}
}

func chooseForegroundSource(colors []imageanalysis.RepresentativeColor, mode string) colorspace.OKLCH {
	best := colors[0].LCH
	for _, candidate := range colors {
		if (mode == "dark" && candidate.LCH.L > best.L) || (mode != "dark" && candidate.LCH.L < best.L) {
			best = candidate.LCH
		}
	}
	return best
}

func semanticColor(lightness, chroma, hue float64) string {
	return colorspace.HexFromOKLCH(colorspace.OKLCH{L: clampValue(lightness, 0, 1), C: math.Max(0, chroma), H: hue})
}

func clampValue(value, minimum, maximum float64) float64 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}
