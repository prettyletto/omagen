package colorspace

import (
	"fmt"
	"math"
)

const gamutEpsilon = 1e-7

func (lch OKLCH) ToOKLab() OKLab {
	hue := normalizeHue(lch.H)
	radians := hue * math.Pi / 180.0
	return OKLab{L: lch.L, A: lch.C * math.Cos(radians), B: lch.C * math.Sin(radians)}
}

func HexFromOKLCH(lch OKLCH) string {
	lch.L = clampFloat(lch.L, 0, 1)
	lch.C = math.Max(0, lch.C)
	lch.H = normalizeHue(lch.H)
	lch = gamutMap(lch)

	r, g, b := oklabToLinearSRGB(lch.ToOKLab())
	return fmt.Sprintf("#%02x%02x%02x", toByte(linearToSRGB(r)), toByte(linearToSRGB(g)), toByte(linearToSRGB(b)))
}

func gamutMap(lch OKLCH) OKLCH {
	if inSRGBGamut(lch) {
		return lch
	}

	low, high := 0.0, lch.C
	for i := 0; i < 24; i++ {
		mid := (low + high) / 2
		candidate := lch
		candidate.C = mid
		if inSRGBGamut(candidate) {
			low = mid
		} else {
			high = mid
		}
	}
	lch.C = low
	return lch
}

func inSRGBGamut(lch OKLCH) bool {
	r, g, b := oklabToLinearSRGB(lch.ToOKLab())
	return inUnitRange(r) && inUnitRange(g) && inUnitRange(b)
}

func inUnitRange(value float64) bool {
	return value >= -gamutEpsilon && value <= 1+gamutEpsilon
}

func oklabToLinearSRGB(lab OKLab) (float64, float64, float64) {
	lRoot := lab.L + 0.3963377774*lab.A + 0.2158037573*lab.B
	mRoot := lab.L - 0.1055613458*lab.A - 0.0638541728*lab.B
	sRoot := lab.L - 0.0894841775*lab.A - 1.2914855480*lab.B

	l := lRoot * lRoot * lRoot
	m := mRoot * mRoot * mRoot
	s := sRoot * sRoot * sRoot

	r := 4.0767416621*l - 3.3077115913*m + 0.2309699292*s
	g := -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
	b := -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
	return r, g, b
}

func linearToSRGB(value float64) float64 {
	value = clampFloat(value, 0, 1)
	if value <= 0.0031308 {
		return value * 12.92
	}
	return 1.055*math.Pow(value, 1.0/2.4) - 0.055
}

func toByte(value float64) uint8 {
	return uint8(math.Round(clampFloat(value, 0, 1) * 255))
}

func normalizeHue(value float64) float64 {
	value = math.Mod(value, 360)
	if value < 0 {
		value += 360
	}
	return value
}

func clampFloat(value, minimum, maximum float64) float64 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}
