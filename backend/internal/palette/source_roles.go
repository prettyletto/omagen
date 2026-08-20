package palette

import (
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

const (
	sourceRoleMinCoverage         = 0.005
	sourceRoleRelativeCoverage    = 0.03
	sourceRoleDistinctHueDistance = 18.0
)

type sourceRoles struct{ Surface, Foreground, Accent, Selection, Muted colorspace.OKLCH }

func selectSourceRoles(colors []imageanalysis.RepresentativeColor, mode string) sourceRoles {
	candidates := meaningfulSourceColors(colors)
	surface := chooseSurfaceRole(candidates, mode)
	foreground := chooseForegroundRole(candidates, surface, mode)
	accent := chooseAccentRole(candidates, surface, mode)
	selection := chooseSecondaryRole(candidates, []colorspace.OKLCH{accent})
	muted := chooseSupportingRole(candidates, []colorspace.OKLCH{accent, selection})
	return sourceRoles{surface, foreground, accent, selection, muted}
}

func meaningfulSourceColors(colors []imageanalysis.RepresentativeColor) []imageanalysis.RepresentativeColor {
	maximum := maxSourceCoverage(colors)
	minimum := math.Max(sourceRoleMinCoverage, maximum*sourceRoleRelativeCoverage)
	result := make([]imageanalysis.RepresentativeColor, 0, len(colors))
	for _, color := range colors {
		if color.Coverage >= minimum {
			result = append(result, color)
		}
	}
	if len(result) == 0 {
		return colors
	}
	return result
}

func chooseSurfaceRole(colors []imageanalysis.RepresentativeColor, mode string) colorspace.OKLCH {
	best, bestScore := colors[0], surfaceRoleScore(colors[0], maxSourceCoverage(colors), mode)
	for _, candidate := range colors[1:] {
		if score := surfaceRoleScore(candidate, maxSourceCoverage(colors), mode); score < bestScore {
			best, bestScore = candidate, score
		}
	}
	return best.LCH
}

func surfaceRoleScore(color imageanalysis.RepresentativeColor, maximum float64, mode string) float64 {
	penalty := .03 * (1 - math.Sqrt(color.Coverage/maximum))
	if mode == "light" {
		return 1 - color.LCH.L + penalty
	}
	return color.LCH.L + penalty
}

func chooseForegroundRole(colors []imageanalysis.RepresentativeColor, surface colorspace.OKLCH, mode string) colorspace.OKLCH {
	maximum := maxSourceCoverage(colors)
	best, bestScore := colors[0], -1.0
	for _, candidate := range colors {
		lch := candidate.LCH
		directional := lch.L
		if mode == "light" {
			directional = 1 - lch.L
		}
		score := directional + lch.C*.20 + hueSeparation(lch, surface)*.05 + math.Sqrt(candidate.Coverage/maximum)*.04
		if score > bestScore {
			best, bestScore = candidate, score
		}
	}
	return best.LCH
}

func chooseAccentRole(colors []imageanalysis.RepresentativeColor, surface colorspace.OKLCH, mode string) colorspace.OKLCH {
	maximum := maxSourceCoverage(colors)
	best, bestScore := colors[0], -1.0
	for _, candidate := range colors {
		lch := candidate.LCH
		if lch.C < chromaticThreshold {
			continue
		}
		highlight := lch.L
		if mode == "light" {
			highlight = 1 - lch.L
		}
		score := lch.C + hueSeparation(lch, surface)*.18 + highlight*.10 + math.Sqrt(candidate.Coverage/maximum)*.08
		if score > bestScore {
			best, bestScore = candidate, score
		}
	}
	if bestScore >= 0 {
		return best.LCH
	}
	return surface
}

func chooseSecondaryRole(colors []imageanalysis.RepresentativeColor, excluded []colorspace.OKLCH) colorspace.OKLCH {
	maximum := maxSourceCoverage(colors)
	best, bestScore := colors[0], -1.0
	for _, candidate := range colors {
		lch := candidate.LCH
		if lch.C < chromaticThreshold {
			continue
		}
		score := lch.C + distinctnessFrom(lch, excluded)*.16 + math.Sqrt(candidate.Coverage/maximum)*.06 + (1-math.Abs(lch.L-.60))*.04
		if score > bestScore {
			best, bestScore = candidate, score
		}
	}
	if bestScore >= 0 {
		return best.LCH
	}
	return colors[0].LCH
}

func chooseSupportingRole(colors []imageanalysis.RepresentativeColor, excluded []colorspace.OKLCH) colorspace.OKLCH {
	maximum := maxSourceCoverage(colors)
	best, bestScore := colors[0], -1.0
	for _, candidate := range colors {
		lch := candidate.LCH
		coverage := candidate.Coverage / maximum
		mid := 1 - math.Min(1, math.Abs(lch.L-.50)*2)
		score := coverage*.55 + lch.C*.20 + distinctnessFrom(lch, excluded)*.15 + mid*.10
		if score > bestScore {
			best, bestScore = candidate, score
		}
	}
	return best.LCH
}

func distinctnessFrom(color colorspace.OKLCH, others []colorspace.OKLCH) float64 {
	if color.C < chromaticThreshold || len(others) == 0 {
		return 0
	}
	minimum := 180.0
	for _, other := range others {
		if other.C >= chromaticThreshold {
			minimum = math.Min(minimum, hueDistance(color.H, other.H))
		}
	}
	return clampValue(minimum/180, 0, 1)
}

func hueSeparation(a, b colorspace.OKLCH) float64 {
	if a.C < chromaticThreshold || b.C < surfaceHueThreshold {
		return 0
	}
	return clampValue(hueDistance(a.H, b.H)/180, 0, 1)
}

func maxSourceCoverage(colors []imageanalysis.RepresentativeColor) float64 {
	maximum := 0.0
	for _, color := range colors {
		maximum = math.Max(maximum, color.Coverage)
	}
	if maximum <= 0 {
		return 1
	}
	return maximum
}
