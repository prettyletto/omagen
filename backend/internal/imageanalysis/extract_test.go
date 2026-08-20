package imageanalysis

import (
	"math"
	"reflect"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

func TestExtractRepresentativeColorsTwoColors(t *testing.T) {
	samples := make([]Sample, 0, 100)
	for i := 0; i < 80; i++ {
		samples = append(samples, makeSample(255, 0, 0, 255))
	}
	for i := 0; i < 20; i++ {
		samples = append(samples, makeSample(0, 0, 255, 255))
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) != 2 {
		t.Fatalf("expected 2 colors, got %d", len(colors))
	}
	assertFloatClose(t, colors[0].Coverage, 0.8)
	assertFloatClose(t, colors[1].Coverage, 0.2)
}

func TestExtractionIsDeterministic(t *testing.T) {
	samples := []Sample{
		makeSample(10, 20, 30, 255),
		makeSample(10, 20, 30, 255),
		makeSample(200, 80, 20, 255),
		makeSample(30, 220, 120, 255),
		makeSample(100, 40, 210, 255),
		makeSample(240, 230, 100, 255),
	}

	first, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	second, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatalf("extraction is not deterministic:\n%v\n%v", first, second)
	}
}

func TestExtractRepresentativeColorsEmpty(t *testing.T) {
	if _, err := extractRepresentativeColors(nil); err == nil {
		t.Fatal("expected empty samples error")
	}
	if _, err := extractRepresentativeColors([]Sample{{A: 0}}); err == nil {
		t.Fatal("expected zero-alpha samples error")
	}
}

func TestExtractMockCurrentBackgroundTheme(t *testing.T) {
	// Mock the broad color structure of the current Tokyo Night theme:
	// a dominant #1a1b26 surface, blue and purple accents, and a small
	// red accent population.
	samples := mockTokyoNightSamples()

	representatives, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(representatives) != 4 {
		t.Fatalf("expected 4 representative colors, got %d", len(representatives))
	}

	assertFloatClose(t, representatives[0].Coverage, 0.55)
	assertFloatClose(t, representatives[1].Coverage, 0.25)
	assertFloatClose(t, representatives[2].Coverage, 0.15)
	assertFloatClose(t, representatives[3].Coverage, 0.05)

	coverage := 0.0
	for i, representative := range representatives {
		if representative.Coverage <= 0 {
			t.Fatalf("representative %d has non-positive coverage", i)
		}
		if representative.LCH != representative.Lab.ToOKLCH() {
			t.Fatalf("representative %d has stale OKLCH values", i)
		}
		coverage += representative.Coverage
	}
	assertFloatClose(t, coverage, 1)
}

func TestExtractSolidColorProducesOneRepresentative(t *testing.T) {
	samples := make([]Sample, 0, 1000)
	for i := 0; i < 1000; i++ {
		samples = append(samples, makeSample(30, 60, 120, 255))
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) != 1 {
		t.Fatalf("expected 1 representative, got %d", len(colors))
	}
	assertFloatClose(t, colors[0].Coverage, 1.0)
}

func TestExtractNearlyMonochromaticNoiseDoesNotOvercluster(t *testing.T) {
	samples := []Sample{
		makeSample(30, 60, 120, 255),
		makeSample(31, 60, 121, 255),
		makeSample(29, 61, 119, 255),
		makeSample(30, 59, 120, 255),
		makeSample(31, 61, 120, 255),
		makeSample(29, 60, 121, 255),
	}
	base := append([]Sample(nil), samples...)
	for i := 0; i < 200; i++ {
		samples = append(samples, base...)
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) != 1 {
		t.Fatalf("expected effectively monochromatic image to produce 1 representative, got %d", len(colors))
	}
}

func TestExtractTwoDistinctColorsProducesTwoRepresentatives(t *testing.T) {
	samples := make([]Sample, 0, 1000)
	for i := 0; i < 700; i++ {
		samples = append(samples, makeSample(20, 35, 75, 255))
	}
	for i := 0; i < 300; i++ {
		samples = append(samples, makeSample(235, 220, 180, 255))
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) != 2 {
		t.Fatalf("expected 2 representatives, got %d", len(colors))
	}
	assertFloatClose(t, colors[0].Coverage, 0.7)
	assertFloatClose(t, colors[1].Coverage, 0.3)
}

func TestExtractThreeDistinctColorsProducesThreeRepresentatives(t *testing.T) {
	samples := make([]Sample, 0, 1000)
	for i := 0; i < 600; i++ {
		samples = append(samples, makeSample(15, 30, 65, 255))
	}
	for i := 0; i < 250; i++ {
		samples = append(samples, makeSample(30, 190, 210, 255))
	}
	for i := 0; i < 150; i++ {
		samples = append(samples, makeSample(230, 110, 45, 255))
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}
	if len(colors) != 3 {
		t.Fatalf("expected 3 representatives, got %d", len(colors))
	}
}

func TestRepresentativeCoverageSumsToOne(t *testing.T) {
	samples := []Sample{
		makeSample(10, 20, 30, 255),
		makeSample(10, 20, 30, 255),
		makeSample(200, 40, 20, 255),
		makeSample(20, 180, 100, 255),
		makeSample(80, 60, 220, 255),
		makeSample(240, 220, 100, 255),
	}

	colors, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatal(err)
	}

	total := 0.0
	for _, color := range colors {
		total += color.Coverage
	}
	assertFloatClose(t, total, 1.0)
}

func TestExtractionReport(t *testing.T) {
	tests := []struct {
		name    string
		samples []Sample
	}{
		{
			name:    "Tokyo Night mock",
			samples: mockTokyoNightSamples(),
		},
		{
			name: "solid color",
			samples: []Sample{
				makeSample(30, 60, 120, 255),
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			representatives, err := extractRepresentativeColors(test.samples)
			if err != nil {
				t.Fatal(err)
			}

			t.Logf("samples=%d representatives=%d", len(test.samples), len(representatives))
			for index, representative := range representatives {
				t.Logf(
					"%02d coverage=%.6f L=%.6f C=%.6f H=%.6f",
					index,
					representative.Coverage,
					representative.LCH.L,
					representative.LCH.C,
					representative.LCH.H,
				)
			}
		})
	}
}

func mockTokyoNightSamples() []Sample {
	samples := make([]Sample, 0, 1000)
	appendSamples := func(count int, r, g, b uint8) {
		for i := 0; i < count; i++ {
			samples = append(samples, makeSample(r, g, b, 255))
		}
	}

	appendSamples(550, 26, 27, 38)
	appendSamples(250, 122, 162, 247)
	appendSamples(150, 187, 154, 247)
	appendSamples(50, 247, 118, 142)

	return samples
}

func makeSample(r, g, b, a uint8) Sample {
	return Sample{
		R: r, G: g, B: b, A: a,
		Lab: colorspace.FromSRGB8(r, g, b),
	}
}

func assertFloatClose(t *testing.T, got, want float64) {
	t.Helper()
	if math.Abs(got-want) > 0.000001 {
		t.Fatalf("got %.8f, want %.8f", got, want)
	}
}
