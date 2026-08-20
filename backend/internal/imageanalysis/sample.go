package imageanalysis

import (
	"fmt"
	"image"
	"image/color"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

const maxSamples = 65_536

func samplePixels(
	img image.Image,
) ([]Sample, error) {
	if img == nil {
		return nil, fmt.Errorf("image is nil")
	}

	bounds := img.Bounds()

	width := bounds.Dx()
	height := bounds.Dy()

	if width <= 0 || height <= 0 {
		return nil, fmt.Errorf(
			"invalid image dimensions %dx%d",
			width,
			height,
		)
	}

	totalPixels := int64(width) * int64(height)

	sampleCount := int64(maxSamples)

	if totalPixels < sampleCount {
		sampleCount = totalPixels
	}

	samples := make(
		[]Sample,
		0,
		sampleCount,
	)

	for i := int64(0); i < sampleCount; i++ {
		// Pick the midpoint of each equal-sized interval across the
		// flattened image.
		index := ((2*i + 1) * totalPixels) /
			(2 * sampleCount)

		x := int(index % int64(width))
		y := int(index / int64(width))

		x += bounds.Min.X
		y += bounds.Min.Y

		nrgba := color.NRGBAModel.Convert(
			img.At(x, y),
		).(color.NRGBA)

		// Fully transparent pixels contain no useful visible color.
		if nrgba.A == 0 {
			continue
		}

		lab := colorspace.FromSRGB8(
			nrgba.R,
			nrgba.G,
			nrgba.B,
		)

		samples = append(
			samples,
			Sample{
				R:   nrgba.R,
				G:   nrgba.G,
				B:   nrgba.B,
				A:   nrgba.A,
				Lab: lab,
			},
		)
	}

	if len(samples) == 0 {
		return nil, fmt.Errorf(
			"image contains no visible pixels",
		)
	}

	return samples, nil
}
