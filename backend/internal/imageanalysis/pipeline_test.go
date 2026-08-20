package imageanalysis

import (
	"image"
	"image/color"
	"testing"
)

func TestImageToRepresentativesPipeline(t *testing.T) {
	img := image.NewNRGBA(image.Rect(0, 0, 100, 100))
	colors := []color.NRGBA{
		{R: 26, G: 27, B: 38, A: 255},
		{R: 122, G: 162, B: 247, A: 255},
		{R: 187, G: 154, B: 247, A: 255},
		{R: 247, G: 118, B: 142, A: 255},
	}

	for y := 0; y < 100; y++ {
		colorIndex := 0
		switch {
		case y >= 55 && y < 80:
			colorIndex = 1
		case y >= 80 && y < 95:
			colorIndex = 2
		case y >= 95:
			colorIndex = 3
		}

		for x := 0; x < 100; x++ {
			img.SetNRGBA(x, y, colors[colorIndex])
		}
	}

	samples, err := samplePixels(img)
	if err != nil {
		t.Fatalf("sample image: %v", err)
	}
	if len(samples) != 10_000 {
		t.Fatalf("samples = %d, want 10000", len(samples))
	}

	representatives, err := extractRepresentativeColors(samples)
	if err != nil {
		t.Fatalf("extract representatives: %v", err)
	}
	if len(representatives) != 4 {
		t.Fatalf("representatives = %d, want 4", len(representatives))
	}

	wantCoverage := []float64{0.55, 0.25, 0.15, 0.05}
	for index, representative := range representatives {
		assertFloatClose(t, representative.Coverage, wantCoverage[index])
		if representative.LCH != representative.Lab.ToOKLCH() {
			t.Fatalf("representative %d has inconsistent OKLCH", index)
		}
	}

	t.Logf("image=100x100 samples=%d representatives=%d", len(samples), len(representatives))
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
}
