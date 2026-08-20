package contrast

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

type direction int

const (
	lighter direction = iota
	darker
)

func adjustLightness(
	color string,
	against string,
	target float64,
	toward direction,
) (string, error) {
	currentRatio, err :=
		Ratio(color, against)

	if err != nil {
		return "", err
	}

	if currentRatio >= target {
		return color, nil
	}

	lch, err :=
		colorspace.OKLCHFromHex(color)

	if err != nil {
		return "", err
	}

	switch toward {
	case lighter:
		return searchLighter(
			lch,
			against,
			target,
		)

	case darker:
		return searchDarker(
			lch,
			against,
			target,
		)

	default:
		return "", fmt.Errorf(
			"unknown contrast adjustment direction",
		)
	}
}

func searchLighter(
	lch colorspace.OKLCH,
	against string,
	target float64,
) (string, error) {
	start := lch.L

	boundary := lch
	boundary.L = 1

	boundaryHex :=
		colorspace.HexFromOKLCH(
			boundary,
		)

	ratio, err :=
		Ratio(
			boundaryHex,
			against,
		)

	if err != nil {
		return "", err
	}

	if ratio < target {
		return "", fmt.Errorf(
			"cannot reach contrast %.2f by increasing lightness",
			target,
		)
	}

	low := start
	high := 1.0

	for i := 0; i < 28; i++ {
		mid := (low + high) / 2

		candidate := lch
		candidate.L = mid

		candidateHex :=
			colorspace.HexFromOKLCH(
				candidate,
			)

		ratio, err :=
			Ratio(
				candidateHex,
				against,
			)

		if err != nil {
			return "", err
		}

		if ratio >= target {
			high = mid
		} else {
			low = mid
		}
	}

	lch.L = high

	return colorspace.HexFromOKLCH(
		lch,
	), nil
}

func searchDarker(
	lch colorspace.OKLCH,
	against string,
	target float64,
) (string, error) {
	start := lch.L

	boundary := lch
	boundary.L = 0

	boundaryHex :=
		colorspace.HexFromOKLCH(
			boundary,
		)

	ratio, err :=
		Ratio(
			boundaryHex,
			against,
		)

	if err != nil {
		return "", err
	}

	if ratio < target {
		return "", fmt.Errorf(
			"cannot reach contrast %.2f by decreasing lightness",
			target,
		)
	}

	low := 0.0
	high := start

	for i := 0; i < 28; i++ {
		mid := (low + high) / 2

		candidate := lch
		candidate.L = mid

		candidateHex :=
			colorspace.HexFromOKLCH(
				candidate,
			)

		ratio, err :=
			Ratio(
				candidateHex,
				against,
			)

		if err != nil {
			return "", err
		}

		if ratio >= target {
			low = mid
		} else {
			high = mid
		}
	}

	lch.L = low

	return colorspace.HexFromOKLCH(
		lch,
	), nil
}
