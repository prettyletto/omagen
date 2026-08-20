package palette

import (
	"math"
	"sort"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

const (
	identityChromaThreshold       = 0.025
	identityFamilyMergeDegrees    = 28.0
	identityNarrowConcentration   = 0.90
	identityEffectiveFamilyWeight = 0.10
)

type sourceIdentity struct {
	anchor            colorspace.OKLCH
	families          []identityFamily
	concentration     float64
	narrow, chromatic bool
}

type identityFamily struct{ L, C, H, Weight float64 }
type weightedIdentityColor struct {
	color  colorspace.OKLCH
	weight float64
}

func analyzeSourceIdentity(colors []imageanalysis.RepresentativeColor, accent colorspace.OKLCH) sourceIdentity {
	entries := make([]weightedIdentityColor, 0, len(colors))
	for _, representative := range colors {
		lch := representative.LCH
		if lch.C < identityChromaThreshold {
			continue
		}
		weight := representative.Coverage * clampValue(lch.C/0.16, 0.35, 1.0)
		if weight > 0 {
			entries = append(entries, weightedIdentityColor{lch, weight})
		}
	}
	if len(entries) == 0 {
		return sourceIdentity{anchor: accent}
	}
	sort.SliceStable(entries, func(i, j int) bool { return entries[i].weight > entries[j].weight })
	anchor := entries[0].color
	if accent.C >= identityChromaThreshold {
		anchor = accent
	}
	families := clusterIdentityFamilies(entries)
	concentration := identityConcentration(entries)
	return sourceIdentity{anchor: anchor, families: families, concentration: concentration, narrow: countEffectiveIdentityFamilies(families) <= 1 || concentration >= identityNarrowConcentration, chromatic: true}
}

func clusterIdentityFamilies(entries []weightedIdentityColor) []identityFamily {
	families := make([]identityFamily, 0, len(entries))
	for _, entry := range entries {
		best, distance := -1, math.Inf(1)
		for i, family := range families {
			if d := hueDistance(entry.color.H, family.H); d < distance {
				best, distance = i, d
			}
		}
		if best < 0 || distance > identityFamilyMergeDegrees {
			families = append(families, identityFamily{L: entry.color.L, C: entry.color.C, H: normalizeHue(entry.color.H), Weight: entry.weight})
			continue
		}
		family := &families[best]
		old, total := family.Weight, family.Weight+entry.weight
		family.L = (family.L*old + entry.color.L*entry.weight) / total
		family.C = (family.C*old + entry.color.C*entry.weight) / total
		a, b := family.H*math.Pi/180, entry.color.H*math.Pi/180
		family.H = normalizeHue(math.Atan2(math.Sin(a)*old+math.Sin(b)*entry.weight, math.Cos(a)*old+math.Cos(b)*entry.weight) * 180 / math.Pi)
		family.Weight = total
	}
	sort.SliceStable(families, func(i, j int) bool { return families[i].Weight > families[j].Weight })
	return families
}

func identityConcentration(entries []weightedIdentityColor) float64 {
	var x, y, total float64
	for _, entry := range entries {
		radians := entry.color.H * math.Pi / 180
		x += math.Cos(radians) * entry.weight
		y += math.Sin(radians) * entry.weight
		total += entry.weight
	}
	if total <= 0 {
		return 0
	}
	return math.Hypot(x, y) / total
}

func countEffectiveIdentityFamilies(families []identityFamily) int {
	var total float64
	for _, family := range families {
		total += family.Weight
	}
	if total <= 0 {
		return 0
	}
	count := 0
	for _, family := range families {
		if family.Weight/total >= identityEffectiveFamilyWeight {
			count++
		}
	}
	if count == 0 {
		return 1
	}
	return count
}

func nearestIdentityFamily(families []identityFamily, targetHue float64, usage []int) int {
	best, score := 0, math.Inf(1)
	for i, family := range families {
		candidate := hueDistance(family.H, targetHue) + float64(usage[i])*18 - math.Sqrt(family.Weight)*8
		if candidate < score {
			best, score = i, candidate
		}
	}
	return best
}

func hueDistance(a, b float64) float64 {
	distance := math.Abs(a - b)
	if distance > 180 {
		distance = 360 - distance
	}
	return distance
}
