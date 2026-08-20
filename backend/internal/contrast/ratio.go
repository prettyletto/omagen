package contrast

import (
	"fmt"
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

func Ratio(
	first string,
	second string,
) (float64, error) {
	firstLuminance, err :=
		relativeLuminance(first)

	if err != nil {
		return 0, fmt.Errorf(
			"first color: %w",
			err,
		)
	}

	secondLuminance, err :=
		relativeLuminance(second)

	if err != nil {
		return 0, fmt.Errorf(
			"second color: %w",
			err,
		)
	}

	lighter := math.Max(
		firstLuminance,
		secondLuminance,
	)

	darker := math.Min(
		firstLuminance,
		secondLuminance,
	)

	return (lighter + 0.05) /
		(darker + 0.05), nil
}

func relativeLuminance(
	value string,
) (float64, error) {
	r, g, b, err :=
		colorspace.ParseHex(value)

	if err != nil {
		return 0, err
	}

	linearR :=
		luminanceChannel(
			float64(r) / 255,
		)

	linearG :=
		luminanceChannel(
			float64(g) / 255,
		)

	linearB :=
		luminanceChannel(
			float64(b) / 255,
		)

	return 0.2126*linearR +
		0.7152*linearG +
		0.0722*linearB, nil
}

func luminanceChannel(
	value float64,
) float64 {
	if value <= 0.04045 {
		return value / 12.92
	}

	return math.Pow(
		(value+0.055)/1.055,
		2.4,
	)
}
