package palette

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
)

func TestSourceIdentityRecognizesNarrowHueFamily(t *testing.T) {
	colors := []testRepresentativeColor{
		{h: 232, c: 0.12, l: 0.30, coverage: 0.45},
		{h: 213, c: 0.17, l: 0.40, coverage: 0.30},
		{h: 220, c: 0.15, l: 0.45, coverage: 0.15},
		{h: 200, c: 0.10, l: 0.50, coverage: 0.10},
	}
	identity := analyzeSourceIdentity(representativesForTest(colors), colorspace.OKLCH{H: 220, C: .17, L: .40})
	if !identity.chromatic || !identity.narrow {
		t.Fatalf("identity = %#v", identity)
	}
}

type testRepresentativeColor struct{ h, c, l, coverage float64 }

func representativesForTest(values []testRepresentativeColor) []imageanalysis.RepresentativeColor {
	result := make([]imageanalysis.RepresentativeColor, len(values))
	for i, value := range values {
		result[i] = imageanalysis.RepresentativeColor{LCH: colorspace.OKLCH{L: value.l, C: value.c, H: value.h}, Coverage: value.coverage}
	}
	return result
}
