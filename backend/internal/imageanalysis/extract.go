package imageanalysis

import (
	"fmt"
	"math"
	"sort"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

const (
	maxRepresentativeColors = 16
	maxKMeansIterations     = 24

	centroidEpsilonSquared = 1e-10

	// Two final representatives closer than this are merged.
	mergeDistance = 0.02

	// Do not create another cluster unless its candidate represents
	// a genuinely distinct perceptual region.
	minimumSeedDistance = 0.03
)

const (
	mergeDistanceSquared       = mergeDistance * mergeDistance
	minimumSeedDistanceSquared = minimumSeedDistance * minimumSeedDistance
)

type weightedPoint struct {
	Lab    colorspace.OKLab
	Weight float64
}

func extractRepresentativeColors(samples []Sample) ([]RepresentativeColor, error) {
	points := aggregateSamples(samples)
	if len(points) == 0 {
		return nil, fmt.Errorf("no weighted colors available")
	}

	clusterCount := maxRepresentativeColors
	if len(points) < clusterCount {
		clusterCount = len(points)
	}

	centroids := seedCentroids(points, clusterCount)
	if len(centroids) == 0 {
		return nil, fmt.Errorf("could not initialize color clusters")
	}

	centroids = refineCentroids(points, centroids)
	representatives := buildRepresentatives(points, centroids)
	representatives = mergeRepresentatives(representatives)
	sortRepresentatives(representatives)

	if len(representatives) == 0 {
		return nil, fmt.Errorf("color extraction produced no representatives")
	}

	return representatives, nil
}

func aggregateSamples(samples []Sample) []weightedPoint {
	type entry struct {
		Lab    colorspace.OKLab
		Weight float64
	}

	colors := make(map[uint32]entry, len(samples))
	for _, sample := range samples {
		weight := float64(sample.A) / 255.0
		if weight <= 0 {
			continue
		}

		key := uint32(sample.R)<<16 |
			uint32(sample.G)<<8 |
			uint32(sample.B)

		current := colors[key]
		if current.Weight == 0 {
			current.Lab = sample.Lab
		}
		current.Weight += weight
		colors[key] = current
	}

	points := make([]weightedPoint, 0, len(colors))
	for _, color := range colors {
		points = append(points, weightedPoint{
			Lab: color.Lab, Weight: color.Weight,
		})
	}

	sort.Slice(points, func(i, j int) bool {
		if points[i].Weight != points[j].Weight {
			return points[i].Weight > points[j].Weight
		}
		return labLess(points[i].Lab, points[j].Lab)
	})

	return points
}

func seedCentroids(points []weightedPoint, count int) []colorspace.OKLab {
	if len(points) == 0 || count <= 0 {
		return nil
	}

	totalWeight := 0.0
	for _, point := range points {
		totalWeight += point.Weight
	}

	centroids := []colorspace.OKLab{points[0].Lab}
	for len(centroids) < count {
		bestIndex := -1
		bestScore := -1.0
		bestDistance := 0.0

		for i, point := range points {
			minDistance := minimumDistanceToCentroids(
				point.Lab,
				centroids,
			)

			if minDistance < minimumSeedDistanceSquared {
				continue
			}

			population := point.Weight / totalWeight
			score := minDistance * math.Sqrt(population)
			if score > bestScore {
				bestScore = score
				bestIndex = i
				bestDistance = minDistance
			}
		}

		if bestIndex < 0 {
			break
		}
		if bestDistance < minimumSeedDistanceSquared {
			break
		}

		centroids = append(centroids, points[bestIndex].Lab)
	}

	return centroids
}

func minimumDistanceToCentroids(
	point colorspace.OKLab,
	centroids []colorspace.OKLab,
) float64 {
	minDistance := math.Inf(1)

	for _, centroid := range centroids {
		distance := labDistanceSquared(point, centroid)
		if distance < minDistance {
			minDistance = distance
		}
	}

	return minDistance
}

func refineCentroids(points []weightedPoint, centroids []colorspace.OKLab) []colorspace.OKLab {
	for iteration := 0; iteration < maxKMeansIterations; iteration++ {
		sumL := make([]float64, len(centroids))
		sumA := make([]float64, len(centroids))
		sumB := make([]float64, len(centroids))
		sumWeight := make([]float64, len(centroids))

		for _, point := range points {
			index := nearestCentroid(point.Lab, centroids)
			sumL[index] += point.Lab.L * point.Weight
			sumA[index] += point.Lab.A * point.Weight
			sumB[index] += point.Lab.B * point.Weight
			sumWeight[index] += point.Weight
		}

		maxShift := 0.0
		for i := range centroids {
			if sumWeight[i] == 0 {
				continue
			}

			next := colorspace.OKLab{
				L: sumL[i] / sumWeight[i],
				A: sumA[i] / sumWeight[i],
				B: sumB[i] / sumWeight[i],
			}
			shift := labDistanceSquared(centroids[i], next)
			if shift > maxShift {
				maxShift = shift
			}
			centroids[i] = next
		}

		if maxShift <= centroidEpsilonSquared {
			break
		}
	}

	return centroids
}

func buildRepresentatives(points []weightedPoint, centroids []colorspace.OKLab) []RepresentativeColor {
	clusterWeights := make([]float64, len(centroids))
	totalWeight := 0.0

	for _, point := range points {
		index := nearestCentroid(point.Lab, centroids)
		clusterWeights[index] += point.Weight
		totalWeight += point.Weight
	}

	result := make([]RepresentativeColor, 0, len(centroids))
	for i, centroid := range centroids {
		if clusterWeights[i] <= 0 {
			continue
		}
		result = append(result, RepresentativeColor{
			Lab: centroid, LCH: centroid.ToOKLCH(),
			Coverage: clusterWeights[i] / totalWeight,
		})
	}
	return result
}

func mergeRepresentatives(colors []RepresentativeColor) []RepresentativeColor {
	sortRepresentatives(colors)
	merged := make([]RepresentativeColor, 0, len(colors))

	for _, candidate := range colors {
		match := -1
		for i := range merged {
			if labDistanceSquared(candidate.Lab, merged[i].Lab) <= mergeDistanceSquared {
				match = i
				break
			}
		}
		if match < 0 {
			merged = append(merged, candidate)
			continue
		}

		existing := merged[match]
		totalCoverage := existing.Coverage + candidate.Coverage
		if totalCoverage <= 0 {
			continue
		}

		lab := colorspace.OKLab{
			L: (existing.Lab.L*existing.Coverage + candidate.Lab.L*candidate.Coverage) / totalCoverage,
			A: (existing.Lab.A*existing.Coverage + candidate.Lab.A*candidate.Coverage) / totalCoverage,
			B: (existing.Lab.B*existing.Coverage + candidate.Lab.B*candidate.Coverage) / totalCoverage,
		}
		merged[match] = RepresentativeColor{
			Lab: lab, LCH: lab.ToOKLCH(), Coverage: totalCoverage,
		}
	}

	return merged
}

func nearestCentroid(point colorspace.OKLab, centroids []colorspace.OKLab) int {
	bestIndex := 0
	bestDistance := labDistanceSquared(point, centroids[0])
	for i := 1; i < len(centroids); i++ {
		distance := labDistanceSquared(point, centroids[i])
		if distance < bestDistance {
			bestDistance = distance
			bestIndex = i
		}
	}
	return bestIndex
}

func labDistanceSquared(a, b colorspace.OKLab) float64 {
	dL := a.L - b.L
	dA := a.A - b.A
	dB := a.B - b.B
	return dL*dL + dA*dA + dB*dB
}

func sortRepresentatives(colors []RepresentativeColor) {
	sort.SliceStable(colors, func(i, j int) bool {
		if colors[i].Coverage != colors[j].Coverage {
			return colors[i].Coverage > colors[j].Coverage
		}
		return labLess(colors[i].Lab, colors[j].Lab)
	})
}

func labLess(a, b colorspace.OKLab) bool {
	if a.L != b.L {
		return a.L < b.L
	}
	if a.A != b.A {
		return a.A < b.A
	}
	return a.B < b.B
}
