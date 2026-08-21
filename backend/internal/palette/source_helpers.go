package palette

import (
	"fmt"
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

const (
	chromaticThreshold  = 0.025
	surfaceHueThreshold = 0.008
	lightModeThreshold  = 0.68
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
