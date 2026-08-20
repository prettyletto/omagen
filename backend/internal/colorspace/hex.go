package colorspace

import (
	"encoding/hex"
	"fmt"
)

func ParseHex(
	value string,
) (uint8, uint8, uint8, error) {
	if len(value) != 7 || value[0] != '#' {
		return 0, 0, 0, fmt.Errorf(
			"invalid hex color %q",
			value,
		)
	}

	decoded, err := hex.DecodeString(
		value[1:],
	)
	if err != nil {
		return 0, 0, 0, fmt.Errorf(
			"invalid hex color %q: %w",
			value,
			err,
		)
	}

	return decoded[0],
		decoded[1],
		decoded[2],
		nil
}

func OKLCHFromHex(
	value string,
) (OKLCH, error) {
	r, g, b, err := ParseHex(value)
	if err != nil {
		return OKLCH{}, err
	}

	return FromSRGB8(
		r,
		g,
		b,
	).ToOKLCH(), nil
}
