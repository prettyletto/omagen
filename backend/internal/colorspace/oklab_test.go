package colorspace

import (
	"math"
	"testing"
)

func TestFromSRGB8(t *testing.T) {
	tests := []struct {
		name string
		r    uint8
		g    uint8
		b    uint8
		want OKLab
	}{
		{name: "black", want: OKLab{}},
		{
			name: "white",
			r:    255,
			g:    255,
			b:    255,
			want: OKLab{L: 1, A: 0, B: 0},
		},
		{
			name: "red",
			r:    255,
			want: OKLab{L: 0.627955, A: 0.224863, B: 0.125846},
		},
		{
			name: "green",
			g:    255,
			want: OKLab{L: 0.866440, A: -0.233888, B: 0.179498},
		},
		{
			name: "blue",
			b:    255,
			want: OKLab{L: 0.452014, A: -0.032457, B: -0.311528},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := FromSRGB8(test.r, test.g, test.b)
			assertClose(t, "L", got.L, test.want.L)
			assertClose(t, "A", got.A, test.want.A)
			assertClose(t, "B", got.B, test.want.B)
		})
	}
}

func TestOKLabToOKLCH(t *testing.T) {
	lch := FromSRGB8(255, 0, 0).ToOKLCH()

	if lch.L <= 0 {
		t.Fatalf("expected positive lightness, got %f", lch.L)
	}
	if lch.C <= 0 {
		t.Fatalf("expected positive chroma, got %f", lch.C)
	}
	if lch.H < 0 || lch.H >= 360 {
		t.Fatalf("hue outside [0,360): %f", lch.H)
	}
}

func assertClose(t *testing.T, name string, got, want float64) {
	t.Helper()

	const tolerance = 0.000001
	if math.Abs(got-want) > tolerance {
		t.Fatalf("%s: got %.9f, want %.9f", name, got, want)
	}
}
