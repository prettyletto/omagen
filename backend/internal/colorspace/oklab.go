package colorspace

import "math"

type OKLab struct {
	L float64
	A float64
	B float64
}

type OKLCH struct {
	L float64
	C float64
	H float64
}

func FromSRGB8(
	r uint8,
	g uint8,
	b uint8,
) OKLab {
	linearR := srgbToLinear(float64(r) / 255.0)
	linearG := srgbToLinear(float64(g) / 255.0)
	linearB := srgbToLinear(float64(b) / 255.0)

	l := 0.4122214708*linearR +
		0.5363325363*linearG +
		0.0514459929*linearB

	m := 0.2119034982*linearR +
		0.6806995451*linearG +
		0.1073969566*linearB

	s := 0.0883024619*linearR +
		0.2817188376*linearG +
		0.6299787005*linearB

	lRoot := math.Cbrt(l)
	mRoot := math.Cbrt(m)
	sRoot := math.Cbrt(s)

	return OKLab{
		L: 0.2104542553*lRoot +
			0.7936177850*mRoot -
			0.0040720468*sRoot,

		A: 1.9779984951*lRoot -
			2.4285922050*mRoot +
			0.4505937099*sRoot,

		B: 0.0259040371*lRoot +
			0.7827717662*mRoot -
			0.8086757660*sRoot,
	}
}

func (lab OKLab) ToOKLCH() OKLCH {
	chroma := math.Hypot(
		lab.A,
		lab.B,
	)

	hue := math.Atan2(
		lab.B,
		lab.A,
	) * 180.0 / math.Pi

	if hue < 0 {
		hue += 360
	}

	return OKLCH{
		L: lab.L,
		C: chroma,
		H: hue,
	}
}

func srgbToLinear(value float64) float64 {
	if value <= 0.04045 {
		return value / 12.92
	}

	return math.Pow(
		(value+0.055)/1.055,
		2.4,
	)
}
